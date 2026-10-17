"""PostToolUse フック：スキル / スラッシュコマンドが作成・更新されたら、
Vault のスキル一覧を更新するよう Claude に知らせる。

対象（ユーザー直下のものだけ。案件・テンプレートのフォルダは対象外）:
  ~/.claude/skills/<名前>/SKILL.md   （synced/ は除く）
  ~/.claude/commands/<名前>.md
何があっても作業を止めないよう、常に exit 0 で終わる。
"""
import json
import os
import re
import sys


def normalize(path):
    p = path.replace("\\", "/")
    m = re.match(r"^/([a-zA-Z])/(.*)$", p)  # Git Bash 形式 /c/Users/... → c:/Users/...
    if m:
        p = f"{m.group(1)}:/{m.group(2)}"
    return p


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
    prefix = re.escape(home.lower())

    m = re.match(prefix + r"/\.claude/skills/([^/]+)/skill\.md$", p.lower())
    if m:
        name = p.split("/")[-2]
        if name.lower() == "synced":
            return
        kind = "スキル"
    else:
        m = re.match(prefix + r"/\.claude/commands/([^/]+)\.md$", p.lower())
        if not m:
            return
        name = os.path.splitext(p.split("/")[-1])[0]
        kind = "スラッシュコマンド"

    msg = (
        f"{kind}「{name}」が作成・更新されました（{path}）。"
        f"この作業の区切りで vault-skill-doc スキルの手順に従い、"
        f"Obsidian Vault の 20_Knowledge/スキル一覧/{name}.md と 00_一覧.md を作成・更新してください。"
        f"同じスキルを続けて編集している途中なら、編集が終わってから1回だけ更新すれば十分です。"
    )
    sys.stdout.reconfigure(encoding="utf-8")
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": msg,
        }
    }, ensure_ascii=False))


try:
    main()
except Exception:
    pass
sys.exit(0)
