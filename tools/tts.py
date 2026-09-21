#!/usr/bin/env python3
"""用 edge-tts 逐句合成后，合并为整篇 article.mp3，并写出句级时间轴 cues。

用法:
    pip install edge-tts mutagen
    python tools/tts.py                      # 只补缺失或文本变过的句子再合并
    python tools/tts.py --force              # 全部重新合成
    python tools/tts.py --only W01-hajimemashite
    python tools/tts.py --voice ja-JP-KeitaNeural
    python tools/tts.py --list-voices

产物（入库）:
    audio/<id>/article.mp3
    audio/<id>/index.json   # 指纹 + cues[{id,startMs,endMs}]
    audio/words/<text_key>.mp3   # 精讲笔记词表（见 lesson_tts.py）

片段缓存（不入库）:
    audio/<id>/.segments/<lineId>.mp3

对话类课文按说话人轮换音色。合并优先用 ffmpeg；不可用时回退为
    lame 生成静音 + MP3 字节拼接（edge-tts 输出同源编码，播放器可播）。
"""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import edge_tts
except ImportError:
    print("缺少依赖，请先执行：pip install edge-tts", file=sys.stderr)
    raise SystemExit(1)

ROOT = Path(__file__).resolve().parent.parent
ARTICLES_DIR = ROOT / "content" / "articles"
AUDIO_DIR = ROOT / "audio"

DEFAULT_VOICE = "ja-JP-NanamiNeural"
DIALOGUE_VOICES = [
    "ja-JP-NanamiNeural",
    "ja-JP-KeitaNeural",
]
DEFAULT_RATE = "-10%"
GAP_MS = 350
ARTICLE_NAME = "article.mp3"
INDEX_NAME = "index.json"
SEGMENTS_DIR = ".segments"


def text_key(text: str, voice: str, rate: str) -> str:
    raw = f"{text}\u0000{voice}\u0000{rate}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()[:16]


def assign_voices(article: dict, default_voice: str) -> dict[str, str]:
    if article.get("type") != "dialogue":
        return {}
    speakers: list[str] = []
    for line in article["lines"]:
        speaker = line.get("speaker")
        if speaker and speaker not in speakers:
            speakers.append(speaker)
    palette = [default_voice] + [v for v in DIALOGUE_VOICES if v != default_voice]
    return {name: palette[i % len(palette)] for i, name in enumerate(speakers)}


async def synth(text: str, voice: str, rate: str) -> bytes:
    comm = edge_tts.Communicate(text, voice, rate=rate)
    buf = bytearray()
    async for chunk in comm.stream():
        if chunk["type"] == "audio":
            buf.extend(chunk["data"])
    if not buf:
        raise RuntimeError("合成返回空音频")
    return bytes(buf)


def require_ffmpeg() -> str:
    """合并必须用 ffmpeg；字节拼接会导致 cues 越往后越漂。"""
    path = shutil.which("ffmpeg")
    if not path:
        raise RuntimeError(
            "找不到 ffmpeg。请安装：brew install ffmpeg\n"
            "不要用 MP3 字节拼接替代，句级时间轴会对不齐。"
        )
    try:
        subprocess.run(
            [path, "-hide_banner", "-version"],
            check=True,
            capture_output=True,
        )
    except (subprocess.CalledProcessError, OSError) as e:
        raise RuntimeError(
            "ffmpeg 无法运行（常见原因：Homebrew 依赖断链，如 libvpx）。\n"
            "处理：brew reinstall libvpx ffmpeg\n"
            f"原始错误：{e}"
        ) from e
    return path


def mp3_duration_ms(path: Path) -> int:
    """优先 mutagen；否则扫 MPEG 帧估算。"""
    try:
        from mutagen.mp3 import MP3  # type: ignore

        info = MP3(path)
        if info.info is None or not info.info.length:
            raise ValueError("empty")
        return max(1, int(round(info.info.length * 1000)))
    except Exception:
        return _mp3_duration_ms_raw(path)


def _mp3_duration_ms_raw(path: Path) -> int:
    data = path.read_bytes()
    i = 0
    if data[:3] == b"ID3" and len(data) >= 10:
        size = (
            ((data[6] & 0x7F) << 21)
            | ((data[7] & 0x7F) << 14)
            | ((data[8] & 0x7F) << 7)
            | (data[9] & 0x7F)
        )
        i = 10 + size
    # MPEG1 Layer III bitrate / sample rate tables
    bitrates = {
        1: [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0],
        2: [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0],
    }
    sample_rates = {
        3: [44100, 48000, 32000, 0],  # MPEG1
        2: [22050, 24000, 16000, 0],  # MPEG2
        0: [11025, 12000, 8000, 0],   # MPEG2.5
    }
    total_ms = 0.0
    n = len(data)
    while i + 4 <= n:
        if data[i] != 0xFF or (data[i + 1] & 0xE0) != 0xE0:
            i += 1
            continue
        version_id = (data[i + 1] >> 3) & 0x03
        layer = (data[i + 1] >> 1) & 0x03
        if layer != 1:  # Layer III
            i += 1
            continue
        br_idx = (data[i + 2] >> 4) & 0x0F
        sr_idx = (data[i + 2] >> 2) & 0x03
        padding = (data[i + 2] >> 1) & 0x01
        mpeg = {3: 1, 2: 2, 0: 2}.get(version_id)
        if mpeg is None or sr_idx > 2 or br_idx == 0 or br_idx == 15:
            i += 1
            continue
        sr = sample_rates[version_id][sr_idx]
        br = bitrates[mpeg][br_idx] * 1000
        if sr == 0 or br == 0:
            i += 1
            continue
        samples = 1152 if version_id == 3 else 576
        frame_len = (samples // 8 * br // sr) + padding
        if frame_len < 1:
            i += 1
            continue
        total_ms += samples * 1000.0 / sr
        i += frame_len
    if total_ms <= 0:
        raise RuntimeError(f"无法解析时长：{path}")
    return max(1, int(round(total_ms)))


def strip_id3v2(data: bytes) -> bytes:
    if data[:3] != b"ID3" or len(data) < 10:
        return data
    size = (
        ((data[6] & 0x7F) << 21)
        | ((data[7] & 0x7F) << 14)
        | ((data[8] & 0x7F) << 7)
        | (data[9] & 0x7F)
    )
    return data[10 + size :]


def make_silence_mp3(dest: Path, duration_ms: int) -> None:
    """用 lame 从静音 PCM 编码一段静音（不依赖 ffmpeg）。"""
    lame = shutil.which("lame")
    if not lame:
        raise RuntimeError("找不到 lame，也无法生成句间静音。请安装 lame 或修好 ffmpeg。")
    rate = 24000
    samples = max(1, int(rate * duration_ms / 1000))
    raw = b"\x00\x00" * samples
    with tempfile.TemporaryDirectory() as tmp:
        raw_path = Path(tmp) / "silence.raw"
        raw_path.write_bytes(raw)
        out = Path(tmp) / "silence.mp3"
        subprocess.run(
            [
                lame,
                "-r",
                "-s",
                str(rate / 1000),
                "-m",
                "m",
                "--quiet",
                str(raw_path),
                str(out),
            ],
            check=True,
            capture_output=True,
        )
        dest.write_bytes(out.read_bytes())


def merge_with_ffmpeg(
    ffmpeg: str,
    segments: list[Path],
    silence: Path,
    out: Path,
) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        list_path = Path(tmp) / "concat.txt"
        lines: list[str] = []
        for i, seg in enumerate(segments):
            lines.append(f"file '{seg.resolve()}'")
            if i < len(segments) - 1:
                lines.append(f"file '{silence.resolve()}'")
        list_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        subprocess.run(
            [
                ffmpeg,
                "-hide_banner",
                "-y",
                "-f",
                "concat",
                "-safe",
                "0",
                "-i",
                str(list_path),
                "-c",
                "copy",
                str(out),
            ],
            check=True,
            capture_output=True,
        )


def merge_binary(segments: list[Path], silence: Path, out: Path) -> None:
    chunks: list[bytes] = []
    for i, seg in enumerate(segments):
        data = seg.read_bytes()
        chunks.append(data if i == 0 else strip_id3v2(data))
        if i < len(segments) - 1:
            chunks.append(strip_id3v2(silence.read_bytes()))
    out.write_bytes(b"".join(chunks))


def merge_article(segments: list[Path], out: Path, gap_ms: int) -> list[dict]:
    """合并片段，返回与成品 article.mp3 对齐的 cues。

    注意：请求的 gap_ms 和静音文件/拼接后的真实时长常有偏差；
    必须用实测时长写 cues，并在合并后再按成品总长校准，
    否则越往后的句子 startMs 会越漂。
    """
    if not segments:
        raise RuntimeError("没有可合并的片段")

    silence = out.parent / ".silence.mp3"
    make_silence_mp3(silence, gap_ms)
    try:
        silence_ms = mp3_duration_ms(silence)
        if silence_ms != gap_ms:
            print(
                f"  · 句间静音请求 {gap_ms}ms，文件实测 {silence_ms}ms（按实测写 cues）",
                flush=True,
            )

        cues: list[dict] = []
        t = 0
        for i, seg in enumerate(segments):
            dur = mp3_duration_ms(seg)
            cues.append({
                "id": seg.stem,
                "startMs": t,
                "endMs": t + dur,
            })
            t += dur
            if i < len(segments) - 1:
                t += silence_ms

        ffmpeg = require_ffmpeg()
        merge_with_ffmpeg(ffmpeg, segments, silence, out)

        # 拼接可能在帧边界丢掉一点时间，按成品总长等比校准
        actual = mp3_duration_ms(out)
        expected = cues[-1]["endMs"]
        if expected > 0 and abs(actual - expected) > 40:
            scale = actual / expected
            print(
                f"  · 合并后时长校准 {expected}ms → {actual}ms（scale={scale:.5f}）",
                flush=True,
            )
            for cue in cues:
                cue["startMs"] = int(round(cue["startMs"] * scale))
                cue["endMs"] = int(round(cue["endMs"] * scale))
            cues[-1]["endMs"] = actual

        return cues
    finally:
        if silence.exists():
            silence.unlink()


async def process_article(
    path: Path,
    default_voice: str,
    rate: str,
    force: bool,
) -> tuple[int, int, int]:
    article = json.loads(path.read_text(encoding="utf-8"))
    article_id = article["id"]
    out_dir = AUDIO_DIR / article_id
    seg_dir = out_dir / SEGMENTS_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    seg_dir.mkdir(parents=True, exist_ok=True)

    # 迁移旧逐句产物到 .segments/
    for legacy in out_dir.glob("l*.mp3"):
        dest = seg_dir / legacy.name
        if not dest.exists():
            legacy.rename(dest)
            print(f"  · 迁移 {legacy.name} → .segments/")
        else:
            legacy.unlink()

    index_path = out_dir / INDEX_NAME
    old_index: dict = {}
    if index_path.exists() and not force:
        try:
            old_index = json.loads(index_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            old_index = {}
    old_lines: dict[str, str] = old_index.get("lines") or {}

    voices = assign_voices(article, default_voice)
    new_lines: dict[str, str] = {}
    made = skipped = failed = 0
    ordered_segments: list[Path] = []

    for line in article["lines"]:
        line_id = line["id"]
        text = line["jp"]
        voice = voices.get(line.get("speaker") or "", default_voice)
        key = text_key(text, voice, rate)
        mp3 = seg_dir / f"{line_id}.mp3"
        ordered_segments.append(mp3)

        if not force and old_lines.get(line_id) == key and mp3.exists():
            new_lines[line_id] = key
            skipped += 1
            continue

        try:
            mp3.write_bytes(await synth(text, voice, rate))
            new_lines[line_id] = key
            made += 1
            print(f"  + segment {article_id}/{line_id}.mp3  [{voice}]")
        except Exception as e:
            failed += 1
            print(f"  ! {article_id}/{line_id} 合成失败: {e}", file=sys.stderr)

    # 清掉源里已删除的行的片段
    keep = {p.name for p in ordered_segments}
    for stale in seg_dir.glob("*.mp3"):
        if stale.name not in keep:
            stale.unlink()
            print(f"  - 删除孤儿片段 {article_id}/{stale.name}")

    # 清掉旧逐句产物
    for stale in out_dir.glob("l*.mp3"):
        stale.unlink()
        print(f"  - 删除旧逐句音频 {article_id}/{stale.name}")

    if failed:
        return made, skipped, failed

    missing = [p for p in ordered_segments if not p.exists()]
    if missing:
        print(f"  ! 缺少片段，跳过合并：{[p.name for p in missing]}", file=sys.stderr)
        return made, skipped, failed + len(missing)

    article_mp3 = out_dir / ARTICLE_NAME
    need_merge = (
        force
        or not article_mp3.exists()
        or old_lines != new_lines
        or made > 0
    )
    if need_merge:
        cues = merge_article(ordered_segments, article_mp3, GAP_MS)
        print(f"  ✓ 合并 {article_id}/{ARTICLE_NAME}  ({len(cues)} 句)")
    else:
        cues = old_index.get("cues") or []
        if not cues:
            cues = merge_article(ordered_segments, article_mp3, GAP_MS)
            print(f"  ✓ 补写 cues 并合并 {article_id}/{ARTICLE_NAME}")

    index_path.write_text(
        json.dumps(
            {
                "articleId": article_id,
                "rate": rate,
                "gapMs": GAP_MS,
                "voices": voices,
                "lines": new_lines,
                "cues": cues,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    return made, skipped, failed


async def list_voices() -> int:
    voices = await edge_tts.list_voices()
    for v in sorted(voices, key=lambda x: x["ShortName"]):
        if v["Locale"].startswith("ja"):
            print(f'{v["ShortName"]:28} {v["Gender"]:6} {v.get("FriendlyName", "")}')
    return 0


async def main() -> int:
    parser = argparse.ArgumentParser(description="合成并合并整篇日语音频")
    parser.add_argument("--force", action="store_true", help="忽略缓存全部重合成")
    parser.add_argument("--only", help="只处理指定的课文 id")
    parser.add_argument("--voice", default=DEFAULT_VOICE, help=f"默认音色，缺省 {DEFAULT_VOICE}")
    parser.add_argument("--rate", default=DEFAULT_RATE, help="语速，缺省 -10%%")
    parser.add_argument("--list-voices", action="store_true", help="列出可用的日语音色")
    args = parser.parse_args()

    if args.list_voices:
        return await list_voices()

    paths = sorted(ARTICLES_DIR.glob("*.json"))
    if args.only:
        paths = [p for p in paths if p.stem == args.only]
        if not paths:
            print(f"找不到课文 {args.only}", file=sys.stderr)
            return 1

    total_made = total_skipped = total_failed = 0
    for path in paths:
        print(f"{path.stem}:")
        made, skipped, failed = await process_article(
            path, args.voice, args.rate, args.force
        )
        total_made += made
        total_skipped += skipped
        total_failed += failed

    print(
        f"\n课文：新合成 {total_made} 句，跳过 {total_skipped} 句（未变化），失败 {total_failed} 句"
    )

    # 精讲笔记词表（与 --only 无关，增量合成很便宜）
    from lesson_tts import process_words

    print("\n精讲笔记词表:")
    w_made, w_skipped, w_failed = await process_words(
        args.voice, args.rate, args.force
    )
    print(
        f"词表：新合成 {w_made}，跳过 {w_skipped}（未变化），失败 {w_failed}"
    )
    return 1 if (total_failed or w_failed) else 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
