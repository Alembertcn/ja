#!/usr/bin/env python3
"""从精讲笔记 Markdown 词表抽取读音，用 edge-tts 合成到 audio/words/。

用法:
    python tools/lesson_tts.py
    python tools/lesson_tts.py --force
    python tools/tts.py                 # 课文合成结束后会顺带跑本脚本

产物（入库）:
    audio/words/<text_key>.mp3

text_key 与 tts.py / App 端一致：sha256(text + NUL + voice + NUL + rate)[:16]
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lesson_vocab import (  # noqa: E402
    DEFAULT_RATE,
    DEFAULT_VOICE,
    extract_speak_texts,
    text_key,
)
from tts import AUDIO_DIR, ROOT, synth  # noqa: E402

LESSONS_DIR = ROOT / "docs" / "lessons"
WORDS_DIR = AUDIO_DIR / "words"


async def process_words(voice: str, rate: str, force: bool) -> tuple[int, int, int]:
    if not LESSONS_DIR.is_dir():
        print("docs/lessons 不存在，跳过词表合成")
        return 0, 0, 0

    all_texts: list[str] = []
    seen: set[str] = set()
    for path in sorted(LESSONS_DIR.glob("*.md")):
        texts = extract_speak_texts(path.read_text(encoding="utf-8"))
        print(f"{path.name}: {len(texts)} 个词")
        for t in texts:
            if t not in seen:
                seen.add(t)
                all_texts.append(t)

    WORDS_DIR.mkdir(parents=True, exist_ok=True)
    made = skipped = failed = 0
    keep: set[str] = set()

    for text in all_texts:
        key = text_key(text, voice, rate)
        mp3 = WORDS_DIR / f"{key}.mp3"
        keep.add(mp3.name)
        if not force and mp3.exists():
            skipped += 1
            continue
        try:
            mp3.write_bytes(await synth(text, voice, rate))
            made += 1
            print(f"  + words/{key}.mp3  「{text}」")
        except Exception as e:
            failed += 1
            print(f"  ! words/{key} 「{text}」合成失败: {e}", file=sys.stderr)

    for stale in WORDS_DIR.glob("*.mp3"):
        if stale.name not in keep:
            stale.unlink()
            print(f"  - 删除孤儿词音频 {stale.name}")

    return made, skipped, failed


async def main() -> int:
    parser = argparse.ArgumentParser(description="合成精讲笔记词表音频")
    parser.add_argument("--force", action="store_true", help="忽略缓存全部重合成")
    parser.add_argument("--voice", default=DEFAULT_VOICE, help=f"音色，缺省 {DEFAULT_VOICE}")
    parser.add_argument("--rate", default=DEFAULT_RATE, help="语速，缺省 -10%%")
    args = parser.parse_args()

    print("精讲笔记词表:")
    made, skipped, failed = await process_words(args.voice, args.rate, args.force)
    print(
        f"\n词表：新合成 {made}，跳过 {skipped}（未变化），失败 {failed}"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
