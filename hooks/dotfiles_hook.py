"""PostToolUse フック：スキル・コマンド・CLAUDE.md・~/scripts が書き換わったら
sync-dotfiles.sh を実行して ~/dotfiles を GitHub に送る。
Windows の「\\」区切りのパスにも対応する。常に exit 0。
"""
import json
import os
import re
import subprocess
import sys


def normalize(path):
    p = path.replace("\\", "/")
    m = re.match(r"^/([a-zA-Z])/(.*)$", p)
    if m:
        p = f"{m.group(1)}:/{m.group(2)}"
    return p.lower()


def main():
    try:
        data = json.loads(sys.stdin.buffer.read().decode("utf-8"))
    except Exception:
        return
    path = (data.get("tool_input") or {}).get("file_path") or ""
    if not path:
        return
    p = normalize(path)
    home = normalize(os.path.expanduser("~")).rstrip("/")
    targets = (
        home + "/.claude/skills/",
        home + "/.claude/commands/",
        home + "/.claude/claude.md",
        home + "/scripts/",
    )
    if not p.startswith(targets) or "/.claude/skills/synced/" in p:
        return
    script = os.path.join(os.path.expanduser("~"), "scripts", "sync-dotfiles.sh")
    subprocess.run(["bash", script], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)


try:
    main()
except Exception:
    pass
sys.exit(0)
