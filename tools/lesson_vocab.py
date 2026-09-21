#!/usr/bin/env python3
"""精讲笔记词表解析与音频指纹（无第三方依赖，可供 build.py 引用）。"""

from __future__ import annotations

import hashlib
import re

DEFAULT_VOICE = "ja-JP-NanamiNeural"
DEFAULT_RATE = "-10%"

_JP_CHAR = re.compile(r"[\u3040-\u30ff\u3400-\u9fff]")
_BOLD = re.compile(r"\*\*([^*]+)\*\*")


def text_key(text: str, voice: str = DEFAULT_VOICE, rate: str = DEFAULT_RATE) -> str:
    raw = f"{text}\u0000{voice}\u0000{rate}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()[:16]


def strip_md(text: str) -> str:
    text = _BOLD.sub(r"\1", text)
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    return text.strip()


def split_row(line: str) -> list[str]:
    line = line.strip()
    if not line.startswith("|"):
        return []
    return [p.strip() for p in line.strip("|").split("|")]


def is_sep_row(cells: list[str]) -> bool:
    if not cells:
        return False
    return all(re.fullmatch(r":?-{3,}:?", c.replace(" ", "")) for c in cells)


def has_jp(text: str) -> bool:
    return bool(_JP_CHAR.search(text))


def speak_text(word: str, reading: str) -> str:
    """决定合成 / 播放用哪段文字。"""
    word = strip_md(word)
    reading = strip_md(reading)
    if reading and has_jp(reading):
        return reading
    if word:
        return word
    return reading


def extract_speak_texts(md: str) -> list[str]:
    """抽出所有「读音」表中应合成的文本（去重保序）。"""
    lines = md.splitlines()
    texts: list[str] = []
    seen: set[str] = set()
    i = 0
    while i < len(lines):
        header = split_row(lines[i])
        if len(header) < 2:
            i += 1
            continue
        if i + 1 >= len(lines) or not is_sep_row(split_row(lines[i + 1])):
            i += 1
            continue

        reading_idx = next((j for j, h in enumerate(header) if h == "读音"), None)
        if reading_idx is None:
            i += 1
            continue
        word_idx = next(
            (j for j, h in enumerate(header) if h in ("日语", "词", "助词")),
            None,
        )
        if word_idx is None:
            word_idx = next((j for j in range(len(header)) if j != reading_idx), None)
        if word_idx is None:
            i += 1
            continue

        i += 2
        while i < len(lines):
            cells = split_row(lines[i])
            if not cells or is_sep_row(cells):
                break
            if len(cells) < max(word_idx, reading_idx) + 1:
                break
            word = cells[word_idx] if word_idx < len(cells) else ""
            reading = cells[reading_idx] if reading_idx < len(cells) else ""
            text = speak_text(word, reading)
            if text and text not in seen:
                seen.add(text)
                texts.append(text)
            i += 1
        continue
    return texts


def rewrite_vocab_links(md: str) -> str:
    """把词列表词列改成 [词](ja-word:encoded) 链接（App 端同逻辑）。"""
    lines = md.splitlines()
    out: list[str] = []
    i = 0
    while i < len(lines):
        header = split_row(lines[i])
        if (
            len(header) >= 2
            and i + 1 < len(lines)
            and is_sep_row(split_row(lines[i + 1]))
        ):
            reading_idx = next((j for j, h in enumerate(header) if h == "读音"), None)
            if reading_idx is not None:
                word_idx = next(
                    (j for j, h in enumerate(header) if h in ("日语", "词", "助词")),
                    None,
                )
                if word_idx is None:
                    word_idx = next(
                        (j for j in range(len(header)) if j != reading_idx), None
                    )
                if word_idx is not None:
                    out.append(lines[i])
                    out.append(lines[i + 1])
                    i += 2
                    while i < len(lines):
                        cells = split_row(lines[i])
                        if not cells or is_sep_row(cells):
                            break
                        if len(cells) < max(word_idx, reading_idx) + 1:
                            break
                        word = cells[word_idx]
                        reading = cells[reading_idx]
                        # 已是链接则跳过
                        if not word.startswith("["):
                            speak = speak_text(word, reading)
                            if speak:
                                from urllib.parse import quote

                                cells[word_idx] = f"[{strip_md(word)}](ja-word:{quote(speak, safe='')})"
                                lines[i] = "| " + " | ".join(cells) + " |"
                        out.append(lines[i])
                        i += 1
                    continue
        out.append(lines[i])
        i += 1
    return "\n".join(out) + ("\n" if md.endswith("\n") else "")
