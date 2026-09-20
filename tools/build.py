#!/usr/bin/env python3
"""校验 content/ 下的课文并构建 dist/ 发布产物。

用法:
    python tools/build.py            # 校验并写出 dist/
    python tools/build.py --check    # 只校验，不写文件（CI 用）
    python tools/build.py --out site # 换个输出目录

零第三方依赖。若环境里装了 jsonschema，会额外跑一遍完整的 JSON Schema 校验。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARTICLES_DIR = ROOT / "content" / "articles"
SCHEMA_PATH = ROOT / "content" / "schema" / "article.schema.json"
# 预生成音频由 tools/tts.py 产出并入库，构建时只做搬运与注入
AUDIO_DIR = ROOT / "audio"

MANIFEST_SCHEMA_VERSION = 1

STAGES = ("P0", "P1", "P2", "P3")
LEVELS = ("N5", "N4", "N3", "N2", "N1")
TYPES = ("article", "dialogue")

ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")
LINE_ID_RE = re.compile(r"^[A-Za-z0-9_-]+$")
MODULE_RE = re.compile(r"^[A-Z]+[0-9]?(-[A-Z0-9]+)*$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# 汉字（含日本新字体）区间，用于核对 furigana 是否标在汉字上
KANJI_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\u3005]")

# manifest 里保留的轻量字段，列表页只需要这些
MANIFEST_FIELDS = (
    "id",
    "title",
    "titleZh",
    "stage",
    "week",
    "level",
    "type",
    "scene",
    "tags",
    "grammarModules",
    "vocabTopic",
    "updatedAt",
)


class Problem:
    """一条校验问题。level 为 error 时阻断构建，warning 只提示。"""

    def __init__(self, level: str, where: str, message: str) -> None:
        self.level = level
        self.where = where
        self.message = message

    def __str__(self) -> str:
        mark = "ERROR" if self.level == "error" else "WARN "
        return f"  [{mark}] {self.where}: {self.message}"


def err(where: str, message: str) -> Problem:
    return Problem("error", where, message)


def warn(where: str, message: str) -> Problem:
    return Problem("warning", where, message)


def _require_str(obj: dict, key: str, where: str, problems: list[Problem]) -> str | None:
    value = obj.get(key)
    if not isinstance(value, str) or not value.strip():
        problems.append(err(where, f"缺少非空字符串字段 `{key}`"))
        return None
    return value


def validate_line(line: object, idx: int, where_prefix: str, is_dialogue: bool,
                  problems: list[Problem]) -> str | None:
    where = f"{where_prefix} lines[{idx}]"
    if not isinstance(line, dict):
        problems.append(err(where, "行必须是对象"))
        return None

    line_id = line.get("id")
    if not isinstance(line_id, str) or not LINE_ID_RE.match(line_id):
        problems.append(err(where, f"`id` 非法: {line_id!r}"))
        line_id = None
    else:
        where = f"{where_prefix} lines[{idx}]({line_id})"

    jp = _require_str(line, "jp", where, problems)
    _require_str(line, "reading", where, problems)
    _require_str(line, "zh", where, problems)

    speaker = line.get("speaker")
    if is_dialogue and not (isinstance(speaker, str) and speaker.strip()):
        problems.append(err(where, "对话类课文每行必须有 `speaker`"))
    if speaker is not None and not isinstance(speaker, str):
        problems.append(err(where, "`speaker` 必须是字符串或 null"))

    if "isSentenceEnd" in line and not isinstance(line["isSentenceEnd"], bool):
        problems.append(err(where, "`isSentenceEnd` 必须是布尔值"))

    validate_furigana(line.get("furigana"), jp, where, problems)
    validate_grammar(line.get("grammar"), where, problems)
    validate_vocab(line.get("vocab"), where, problems)

    return line_id


def validate_furigana(spans: object, jp: str | None, where: str,
                      problems: list[Problem]) -> None:
    """核对注音区间：不越界、不重叠、确实落在汉字上。AI 最容易在这里数错下标。"""
    if spans is None:
        return
    if not isinstance(spans, list):
        problems.append(err(where, "`furigana` 必须是数组"))
        return

    occupied: list[tuple[int, int]] = []
    for i, span in enumerate(spans):
        tag = f"{where} furigana[{i}]"
        if not isinstance(span, dict):
            problems.append(err(tag, "注音区间必须是对象"))
            continue
        start, length, ruby = span.get("start"), span.get("len"), span.get("ruby")
        if not isinstance(start, int) or isinstance(start, bool) or start < 0:
            problems.append(err(tag, f"`start` 必须是非负整数，当前 {start!r}"))
            continue
        if not isinstance(length, int) or isinstance(length, bool) or length < 1:
            problems.append(err(tag, f"`len` 必须是正整数，当前 {length!r}"))
            continue
        if not isinstance(ruby, str) or not ruby.strip():
            problems.append(err(tag, "`ruby` 必须是非空字符串"))
            continue
        if jp is None:
            continue
        if start + length > len(jp):
            problems.append(err(
                tag,
                f"区间越界：start={start} len={length} 超出原文长度 {len(jp)}（原文 {jp!r}）",
            ))
            continue

        segment = jp[start:start + length]
        if not KANJI_RE.search(segment):
            problems.append(err(
                tag,
                f"注音没落在汉字上：截出的是 {segment!r}（ruby={ruby!r}，原文 {jp!r}），下标很可能数错了",
            ))
        for other_start, other_len in occupied:
            if start < other_start + other_len and other_start < start + length:
                problems.append(err(tag, f"与前面的注音区间重叠：{segment!r}"))
                break
        occupied.append((start, length))


def validate_grammar(items: object, where: str, problems: list[Problem]) -> None:
    if items is None:
        return
    if not isinstance(items, list):
        problems.append(err(where, "`grammar` 必须是数组"))
        return
    for i, item in enumerate(items):
        tag = f"{where} grammar[{i}]"
        if not isinstance(item, dict):
            problems.append(err(tag, "语法点必须是对象"))
            continue
        _require_str(item, "point", tag, problems)
        _require_str(item, "explain", tag, problems)
        module = item.get("module")
        if module is not None and (not isinstance(module, str) or not MODULE_RE.match(module)):
            problems.append(err(tag, f"`module` 不是合法模块号: {module!r}"))


def validate_vocab(items: object, where: str, problems: list[Problem]) -> None:
    if items is None:
        return
    if not isinstance(items, list):
        problems.append(err(where, "`vocab` 必须是数组"))
        return
    for i, item in enumerate(items):
        tag = f"{where} vocab[{i}]"
        if not isinstance(item, dict):
            problems.append(err(tag, "生词必须是对象"))
            continue
        _require_str(item, "word", tag, problems)
        _require_str(item, "reading", tag, problems)
        _require_str(item, "zh", tag, problems)


def validate_article(data: object, path: Path, problems: list[Problem]) -> None:
    where = path.name
    if not isinstance(data, dict):
        problems.append(err(where, "课文根节点必须是对象"))
        return

    article_id = data.get("id")
    if not isinstance(article_id, str) or not ID_RE.match(article_id):
        problems.append(err(where, f"`id` 非法: {article_id!r}"))
    elif article_id != path.stem:
        problems.append(err(where, f"`id` 与文件名不一致：id={article_id}，文件名={path.stem}"))

    _require_str(data, "title", where, problems)
    _require_str(data, "titleZh", where, problems)

    stage = data.get("stage")
    if stage not in STAGES:
        problems.append(err(where, f"`stage` 必须是 {'/'.join(STAGES)} 之一，当前 {stage!r}"))

    week = data.get("week")
    if not isinstance(week, int) or isinstance(week, bool) or not 1 <= week <= 42:
        problems.append(err(where, f"`week` 必须是 1–42 的整数，当前 {week!r}"))

    level = data.get("level")
    if level not in LEVELS:
        problems.append(err(where, f"`level` 必须是 {'/'.join(LEVELS)} 之一，当前 {level!r}"))

    art_type = data.get("type")
    if art_type not in TYPES:
        problems.append(err(where, f"`type` 必须是 {'/'.join(TYPES)} 之一，当前 {art_type!r}"))

    updated_at = data.get("updatedAt")
    if not isinstance(updated_at, str) or not DATE_RE.match(updated_at):
        problems.append(err(where, f"`updatedAt` 必须是 YYYY-MM-DD，当前 {updated_at!r}"))

    declared_modules = data.get("grammarModules") or []
    if not isinstance(declared_modules, list):
        problems.append(err(where, "`grammarModules` 必须是数组"))
        declared_modules = []
    else:
        for module in declared_modules:
            if not isinstance(module, str) or not MODULE_RE.match(module):
                problems.append(err(where, f"`grammarModules` 含非法模块号: {module!r}"))

    lines = data.get("lines")
    if not isinstance(lines, list) or not lines:
        problems.append(err(where, "`lines` 必须是非空数组"))
        return

    is_dialogue = art_type == "dialogue"
    seen_ids: set[str] = set()
    used_modules: set[str] = set()
    for idx, line in enumerate(lines):
        line_id = validate_line(line, idx, where, is_dialogue, problems)
        if line_id:
            if line_id in seen_ids:
                problems.append(err(where, f"行 id 重复: {line_id}"))
            seen_ids.add(line_id)
        if isinstance(line, dict):
            for item in line.get("grammar") or []:
                if isinstance(item, dict) and isinstance(item.get("module"), str):
                    used_modules.add(item["module"])

    missing = [m for m in declared_modules if isinstance(m, str) and m not in used_modules]
    if missing:
        problems.append(warn(
            where,
            f"声明了但正文没解析到的语法模块: {', '.join(missing)}",
        ))


def check_audio_coverage(articles: list[tuple[Path, dict]], problems: list[Problem]) -> None:
    """音频是硬要求：App 只播整篇预生成音频，缺文件或 cues 对不齐就拦下。"""
    for path, data in articles:
        if not isinstance(data, dict) or not isinstance(data.get("lines"), list):
            continue
        article_id = data.get("id")
        if not isinstance(article_id, str):
            continue
        article_mp3, cues = article_audio(article_id)
        if article_mp3 is None:
            problems.append(err(path.name, "缺少 audio/<id>/article.mp3，跑 python tools/publish.py 合成"))
            continue
        if not cues:
            problems.append(err(path.name, "index.json 缺少 cues，跑 python tools/tts.py 重新合并"))
            continue
        line_ids = [
            line["id"] for line in data["lines"]
            if isinstance(line, dict) and isinstance(line.get("id"), str)
        ]
        cue_ids = [c["id"] for c in cues if isinstance(c, dict) and isinstance(c.get("id"), str)]
        if cue_ids != line_ids:
            problems.append(err(
                path.name,
                f"cues 与 lines 不一致（cues={len(cue_ids)} lines={len(line_ids)}），跑 python tools/tts.py --force",
            ))


def article_audio(article_id: str) -> tuple[Path | None, list[dict]]:
    """返回整篇音频路径与 cues。"""
    folder = AUDIO_DIR / article_id
    mp3 = folder / "article.mp3"
    if not mp3.is_file():
        return None, []
    index_path = folder / "index.json"
    cues: list[dict] = []
    if index_path.is_file():
        try:
            raw = json.loads(index_path.read_text(encoding="utf-8")).get("cues") or []
            if isinstance(raw, list):
                cues = [c for c in raw if isinstance(c, dict)]
        except json.JSONDecodeError:
            cues = []
    return mp3, cues


def with_audio(data: dict) -> dict:
    """把篇级 audio / cues 注入到输出副本。源文件保持干净。"""
    mp3, cues = article_audio(data["id"])
    if mp3 is None:
        return data
    output = dict(data)
    output["audio"] = f"audio/{data['id']}/article.mp3"
    output["cues"] = [
        {
            "id": c["id"],
            "startMs": int(c["startMs"]),
            "endMs": int(c["endMs"]),
        }
        for c in cues
        if "id" in c and "startMs" in c and "endMs" in c
    ]
    # 确保不把旧的逐句 audio 带出去
    lines = []
    for line in data.get("lines") or []:
        if not isinstance(line, dict):
            lines.append(line)
            continue
        cleaned = {k: v for k, v in line.items() if k != "audio"}
        lines.append(cleaned)
    output["lines"] = lines
    return output


def run_jsonschema(articles: list[tuple[Path, dict]], problems: list[Problem]) -> bool:
    """装了 jsonschema 就再跑一遍完整校验，没装就跳过。"""
    try:
        import jsonschema  # type: ignore
    except ImportError:
        return False

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    validator = jsonschema.Draft202012Validator(schema)
    for path, data in articles:
        for error in sorted(validator.iter_errors(data), key=lambda e: list(e.path)):
            location = "/".join(str(p) for p in error.path) or "<root>"
            problems.append(err(path.name, f"schema {location}: {error.message}"))
    return True


def load_articles(problems: list[Problem]) -> list[tuple[Path, dict]]:
    if not ARTICLES_DIR.is_dir():
        problems.append(err("content/articles", "目录不存在"))
        return []

    articles: list[tuple[Path, dict]] = []
    for path in sorted(ARTICLES_DIR.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            problems.append(err(path.name, f"JSON 解析失败: {exc}"))
            continue
        articles.append((path, data))
    return articles


def stage_sort_key(data: dict) -> tuple:
    stage = data.get("stage", "")
    stage_index = STAGES.index(stage) if stage in STAGES else len(STAGES)
    week = data.get("week") if isinstance(data.get("week"), int) else 999
    return (stage_index, week, str(data.get("id", "")))


def build_manifest(articles: list[tuple[Path, dict]]) -> dict:
    entries = []
    for _, data in sorted(articles, key=lambda pair: stage_sort_key(pair[1])):
        payload = json.dumps(data, ensure_ascii=False, sort_keys=True).encode("utf-8")
        entry = {key: data[key] for key in MANIFEST_FIELDS if key in data}
        entry["lineCount"] = len(data.get("lines") or [])
        entry["contentHash"] = hashlib.sha256(payload).hexdigest()[:16]
        entry["path"] = f"articles/{data['id']}.json"
        entries.append(entry)

    return {
        "schemaVersion": MANIFEST_SCHEMA_VERSION,
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "count": len(entries),
        "articles": entries,
    }


def render_index_html(manifest: dict) -> str:
    """一个极简落地页，方便在浏览器里确认 Pages 发布成功。"""
    rows = "\n".join(
        "      <li><a href=\"{path}\">{title}</a>"
        "<span class=\"meta\">{stage} · W{week:02d} · {level} · {lines} 行</span></li>".format(
            path=a["path"],
            title=f'{a.get("titleZh", "")}（{a.get("title", "")}）',
            stage=a.get("stage", "--"),
            week=a.get("week", 0),
            level=a.get("level", "--"),
            lines=a.get("lineCount", 0),
        )
        for a in manifest["articles"]
    )
    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>ja — 日语课文数据源</title>
  <style>
    body {{ font-family: system-ui, sans-serif; max-width: 720px; margin: 2rem auto; padding: 0 1rem; line-height: 1.7; }}
    h1 {{ font-size: 1.4rem; }}
    ul {{ list-style: none; padding: 0; }}
    li {{ padding: .6rem 0; border-bottom: 1px solid #eee; }}
    .meta {{ color: #888; font-size: .85rem; margin-left: .6rem; }}
    code {{ background: #f5f5f5; padding: .1rem .35rem; border-radius: 3px; }}
  </style>
</head>
<body>
  <h1>ja — 日语课文数据源</h1>
  <p>App 的内容接口。清单：<a href="manifest.json"><code>manifest.json</code></a>，共 {manifest['count']} 篇，生成于 {manifest['generatedAt']}。</p>
  <ul>
{rows}
  </ul>
</body>
</html>
"""


def write_dist(out_dir: Path, articles: list[tuple[Path, dict]], manifest: dict) -> None:
    articles_out = out_dir / "articles"
    articles_out.mkdir(parents=True, exist_ok=True)
    audio_out = out_dir / "audio"

    # 清掉上一次构建的残留，避免删了源文件但产物还挂在 Pages 上
    for stale in articles_out.glob("*.json"):
        stale.unlink()
    if audio_out.exists():
        shutil.rmtree(audio_out)

    for _, data in articles:
        payload = with_audio(data)
        target = articles_out / f"{payload['id']}.json"
        target.write_text(
            json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )

        mp3, _ = article_audio(data["id"])
        if mp3 is not None:
            dest = audio_out / data["id"] / "article.mp3"
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(mp3, dest)

    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    (out_dir / "index.html").write_text(render_index_html(manifest), encoding="utf-8")
    (out_dir / ".nojekyll").write_text("", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="校验课文并构建发布产物")
    parser.add_argument("--check", action="store_true", help="只校验，不写文件")
    parser.add_argument("--out", default="dist", help="输出目录，默认 dist")
    args = parser.parse_args()

    problems: list[Problem] = []
    articles = load_articles(problems)

    seen_ids: dict[str, Path] = {}
    for path, data in articles:
        validate_article(data, path, problems)
        if isinstance(data, dict) and isinstance(data.get("id"), str):
            if data["id"] in seen_ids:
                problems.append(err(path.name, f"id 与 {seen_ids[data['id']].name} 重复"))
            seen_ids[data["id"]] = path

    check_audio_coverage(articles, problems)
    used_jsonschema = run_jsonschema(articles, problems)

    errors = [p for p in problems if p.level == "error"]
    warnings = [p for p in problems if p.level == "warning"]

    print(f"扫描 {len(articles)} 篇课文"
          f"（{'含' if used_jsonschema else '未装'} jsonschema 完整校验）")
    for problem in problems:
        print(problem)

    if errors:
        print(f"\n校验失败：{len(errors)} 个错误，{len(warnings)} 个警告")
        return 1

    manifest = build_manifest(articles)

    if args.check:
        print(f"\n校验通过：{len(articles)} 篇，{len(warnings)} 个警告（--check 模式不写文件）")
        return 0

    out_dir = (ROOT / args.out) if not Path(args.out).is_absolute() else Path(args.out)
    write_dist(out_dir, articles, manifest)
    print(f"\n构建完成：{len(articles)} 篇 → {out_dir.relative_to(ROOT) if out_dir.is_relative_to(ROOT) else out_dir}")
    print(f"  manifest.json / articles/*.json / index.html，{len(warnings)} 个警告")
    return 0


if __name__ == "__main__":
    sys.exit(main())
