#!/usr/bin/env python3
"""用 edge-tts 为课文逐句合成日语音频。

用法:
    pip install edge-tts
    python tools/tts.py                      # 只补缺失或文本变过的句子
    python tools/tts.py --force              # 全部重新合成
    python tools/tts.py --only W01-hajimemashite
    python tools/tts.py --voice ja-JP-KeitaNeural
    python tools/tts.py --list-voices

音频产物提交进仓库的 audio/ 目录，CI 只负责搬运，不在 Actions 里跑合成——
edge-tts 是非官方接口，放进 CI 会让发布随时可能挂掉。

对话类课文按说话人轮换音色：第一个出场的人用女声，第二个用男声，以此类推。
"""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import sys
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

# edge-tts 的日语只有这两个音色（Azure 付费版才有更多），
# 对话按说话人出场顺序轮换，保证同一个人全篇音色一致；超过两人会循环复用。
DIALOGUE_VOICES = [
    "ja-JP-NanamiNeural",
    "ja-JP-KeitaNeural",
]

# 学习场景稍慢一点，但别慢到破坏语流
DEFAULT_RATE = "-10%"

INDEX_NAME = "index.json"


def text_key(text: str, voice: str, rate: str) -> str:
    """音频指纹。文本、音色、语速任一变了都要重合成。"""
    raw = f"{text}\u0000{voice}\u0000{rate}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()[:16]


def assign_voices(article: dict, default_voice: str) -> dict[str, str]:
    """给每个说话人定一个音色；短文全部用默认音色。"""
    if article.get("type") != "dialogue":
        return {}
    speakers: list[str] = []
    for line in article["lines"]:
        speaker = line.get("speaker")
        if speaker and speaker not in speakers:
            speakers.append(speaker)
    # 默认音色排在轮换表最前，这样单人对话也能听到用户指定的音色
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


async def process_article(path: Path, default_voice: str, rate: str,
                          force: bool) -> tuple[int, int, int]:
    article = json.loads(path.read_text(encoding="utf-8"))
    article_id = article["id"]
    out_dir = AUDIO_DIR / article_id
    out_dir.mkdir(parents=True, exist_ok=True)

    index_path = out_dir / INDEX_NAME
    old_index: dict[str, str] = {}
    if index_path.exists() and not force:
        try:
            old_index = json.loads(index_path.read_text(encoding="utf-8")).get("lines", {})
        except json.JSONDecodeError:
            old_index = {}

    voices = assign_voices(article, default_voice)
    new_index: dict[str, str] = {}
    made = skipped = failed = 0

    for line in article["lines"]:
        line_id = line["id"]
        text = line["jp"]
        voice = voices.get(line.get("speaker") or "", default_voice)
        key = text_key(text, voice, rate)
        mp3 = out_dir / f"{line_id}.mp3"

        if not force and old_index.get(line_id) == key and mp3.exists():
            new_index[line_id] = key
            skipped += 1
            continue

        try:
            mp3.write_bytes(await synth(text, voice, rate))
            new_index[line_id] = key
            made += 1
            print(f"  + {article_id}/{line_id}.mp3  [{voice}]")
        except Exception as e:
            failed += 1
            print(f"  ! {article_id}/{line_id} 合成失败: {e}", file=sys.stderr)

    # 清掉源文件里已经删掉的行留下的孤儿音频
    for stale in out_dir.glob("*.mp3"):
        if stale.stem not in new_index:
            stale.unlink()
            print(f"  - 删除孤儿音频 {article_id}/{stale.name}")

    index_path.write_text(
        json.dumps(
            {"articleId": article_id, "rate": rate, "voices": voices, "lines": new_index},
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
    parser = argparse.ArgumentParser(description="为课文逐句合成日语音频")
    parser.add_argument("--force", action="store_true", help="忽略缓存全部重合成")
    parser.add_argument("--only", help="只处理指定的课文 id")
    parser.add_argument("--voice", default=DEFAULT_VOICE, help=f"默认音色，缺省 {DEFAULT_VOICE}")
    parser.add_argument("--rate", default=DEFAULT_RATE, help=f"语速，缺省 {DEFAULT_RATE}")
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
        made, skipped, failed = await process_article(path, args.voice, args.rate, args.force)
        total_made += made
        total_skipped += skipped
        total_failed += failed

    print(f"\n新合成 {total_made} 句，跳过 {total_skipped} 句（未变化），失败 {total_failed} 句")
    return 1 if total_failed else 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
