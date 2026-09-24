#!/usr/bin/env python3
"""新增或修改课文后，一条命令走完：合成音频 → 校验构建 → 提交推送。

用法:
    python tools/publish.py                  # 全流程，含提交推送
    python tools/publish.py --no-push        # 只到构建为止，自己检查后再提交
    python tools/publish.py -m "加 W24 短文"  # 自定义提交信息
    python tools/publish.py --only W24-x     # 只处理某一篇的音频
    python tools/publish.py --force-audio    # 忽略缓存重新合成全部音频

推送之后 GitHub Actions 会自动发布到 Pages，App 下拉刷新即可看到。
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"

# 只有这些目录的改动才值得触发一次内容发布。
# docs/lessons 会被 build.py 打进 dist/lessons，所以同属发布内容。
CONTENT_PATHS = ["content", "audio", "docs/lessons"]


def step(title: str) -> None:
    # 子进程直接写终端，自己的输出必须先 flush，否则标题会排在子进程输出后面
    print(f"\n── {title} ──", flush=True)


def run(cmd: list[str], title: str) -> int:
    step(title)
    return subprocess.call(cmd, cwd=ROOT)


def git(*args: str, capture: bool = False) -> str | int:
    cmd = ["git", *args]
    if capture:
        return subprocess.check_output(cmd, cwd=ROOT, text=True, encoding="utf-8")
    return subprocess.call(cmd, cwd=ROOT)


def changed_articles() -> list[str]:
    """从待提交的改动里推断出涉及哪些课文，用来生成提交信息。"""
    out = git("status", "--porcelain", "--", *CONTENT_PATHS, capture=True)
    assert isinstance(out, str)
    ids: set[str] = set()
    for line in out.splitlines():
        path = line[3:].strip().strip('"')
        parts = path.split("/")
        if len(parts) >= 3 and parts[0] == "content" and parts[1] == "articles":
            ids.add(Path(parts[2]).stem)
        elif len(parts) >= 2 and parts[0] == "audio":
            ids.add(parts[1])
    return sorted(ids)


def has_content_changes() -> bool:
    """content / audio / lessons 任一有改动即需要发布。"""
    out = git("status", "--porcelain", "--", *CONTENT_PATHS, capture=True)
    assert isinstance(out, str)
    return bool(out.strip())


def main() -> int:
    parser = argparse.ArgumentParser(description="一条命令发布课文")
    parser.add_argument("-m", "--message", help="提交信息，默认按改动的课文自动生成")
    parser.add_argument("--no-push", action="store_true", help="只到构建为止，不碰 git")
    parser.add_argument("--only", help="只处理指定课文的音频")
    parser.add_argument("--force-audio", action="store_true", help="忽略缓存重新合成音频")
    parser.add_argument("--skip-audio", action="store_true", help="跳过音频合成")
    args = parser.parse_args()

    py = sys.executable

    if not args.skip_audio:
        cmd = [py, str(TOOLS / "tts.py")]
        if args.only:
            cmd += ["--only", args.only]
        if args.force_audio:
            cmd.append("--force")
        if run(cmd, "合成音频") != 0:
            print("\n音频合成失败，已中止。检查网络或代理后重试。", file=sys.stderr)
            return 1

    if run([py, str(TOOLS / "build.py")], "校验并构建") != 0:
        print("\n校验没过，已中止。按上面的报错改完再跑一次。", file=sys.stderr)
        return 1

    if args.no_push:
        print("\n构建完成（--no-push，未提交）。确认无误后自行 git commit && git push。")
        return 0

    ids = changed_articles()
    if not has_content_changes():
        print("\n内容源没有改动，无需发布。")
        return 0

    step(
        "提交并推送"
        + (f"  涉及课文：{', '.join(ids)}" if ids else "  （词库/计划/练习等）")
    )
    git("add", "--", *CONTENT_PATHS)
    if ids:
        message = args.message or f"更新课文：{', '.join(ids)}"
    else:
        message = args.message or "更新内容源"
    if git("commit", "-m", message) != 0:
        print("提交失败，已中止。", file=sys.stderr)
        return 1
    if git("push") != 0:
        print("推送失败。网络恢复后执行 git push 即可，提交已经在本地了。", file=sys.stderr)
        return 1

    print("\n发布完成。Actions 跑完（约一分钟）后，App 下拉刷新就能看到。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
