#!/usr/bin/env bash
# ~/.claude のスキル・コマンド・CLAUDE.md と ~/scripts を ~/dotfiles にコピーし、GitHub に送る。
# パソコン側が正。dotfiles 側を手で直しても、次の同期で上書きされる。
#
# 使い方:
#   sync-dotfiles.sh            コピー → コミット → プッシュ
#   sync-dotfiles.sh --no-push  コピーとコミットまで（プッシュしない）
#
# 入れないもの: ~/.claude/skills/synced（claude.ai から同期されるもの）、.trash（削除済み）、__pycache__

set -euo pipefail

DOT="$HOME/dotfiles"
PUSH=1
[ "${1:-}" = "--no-push" ] && PUSH=0

if [ ! -d "$DOT/.git" ]; then
  echo "dotfiles が見つかりません: $DOT" >&2
  exit 1
fi

# src の中身を dst に丸ごと置き換える
mirror() {
  local src="$1" dst="$2"; shift 2
  [ -d "$src" ] || return 0
  rm -rf "$dst"
  mkdir -p "$dst"
  (cd "$src" && tar --exclude='__pycache__' "$@" -cf - .) | (cd "$dst" && tar -xf -)
}

mirror "$HOME/.claude/skills"   "$DOT/claude-skills" --exclude='./synced' --exclude='./.trash'
mirror "$HOME/.claude/commands" "$DOT/claude-commands"
mirror "$HOME/scripts"          "$DOT/scripts"
if [ -f "$HOME/.claude/CLAUDE.md" ]; then
  mkdir -p "$DOT/claude"
  cp "$HOME/.claude/CLAUDE.md" "$DOT/claude/CLAUDE.md"
fi

cd "$DOT"
git add -A
if git diff --cached --quiet; then
  echo "変更なし"
  exit 0
fi
git diff --cached --stat
git commit -q -m "Sync dotfiles $(date '+%Y-%m-%d %H:%M')"
if [ $PUSH -eq 1 ]; then
  git push -q
  echo "GitHub に送りました"
else
  echo "コミットしました（プッシュはしていません）"
fi
