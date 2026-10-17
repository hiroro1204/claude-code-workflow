#!/usr/bin/env bash
# Vault の coding-rules/*.md を、指定リポジトリの .cursor/rules/*.mdc へ書き出す（一方通行）。
#
# 使い方:
#   export-cursor-rules.sh [オプション] <書き出し先リポジトリのフォルダ>
#
# オプション:
#   --dry-run          何も書き込まず、変わる内容だけ表示する
#   --only <a,b,...>   書き出すサブフォルダを指定（必須。例: 共通,クライアントA,案件雛形）
#                      別クライアント用の rule が混ざらないよう、毎回はっきり指定する
#   --yes              書き込み前の確認を省略する
#   --delete=ask|yes|no
#                      Vault にない .mdc の扱い（既定: ask = 1件ずつ確認）
#
# 環境変数:
#   VAULT_RULES        正本フォルダ（既定: ~/Desktop/Obsidian/20_Knowledge/coding-rules）
#
# 中身はそのままコピーする（frontmatter も変えない）。拡張子だけ .md → .mdc。
# 改行コード（CRLF / LF）の違いは無視して比べ、書き出し先の改行コードに合わせて書く。

set -euo pipefail

VAULT_RULES="${VAULT_RULES:-$HOME/Desktop/Obsidian/20_Knowledge/coding-rules}"
DRY_RUN=0
ONLY=""
YES=0
DELETE_MODE="ask"
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --only) ONLY="${2:-}"; shift ;;
    --only=*) ONLY="${1#--only=}" ;;
    --yes) YES=1 ;;
    --delete=ask|--delete=yes|--delete=no) DELETE_MODE="${1#--delete=}" ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    -*) echo "不明なオプション: $1" >&2; exit 1 ;;
    *) TARGET="$1" ;;
  esac
  shift
done

if [ -z "$TARGET" ]; then
  echo "書き出し先のフォルダを指定してください（--help で使い方）" >&2
  exit 1
fi
if [ ! -d "$TARGET" ]; then
  echo "書き出し先が見つかりません: $TARGET" >&2
  exit 1
fi
if [ ! -d "$VAULT_RULES" ]; then
  echo "正本フォルダが見つかりません: $VAULT_RULES" >&2
  exit 1
fi

DEST="$TARGET/.cursor/rules"

# 端末がないときは確認できないので止める
ask() {
  local prompt="$1" ans
  if [ ! -t 0 ]; then
    echo "確認が必要ですが、対話できない環境です（--yes / --delete= を指定してください）" >&2
    exit 1
  fi
  read -r -p "$prompt [y/N] " ans
  [ "$ans" = "y" ] || [ "$ans" = "Y" ]
}

# 改行コードを無視して同じ内容か
same_text() { cmp -s <(sed 's/\r$//' "$1") <(sed 's/\r$//' "$2"); }

# 書き出し先の改行コード（既存の .mdc が CRLF なら CRLF、無ければ CRLF）
EOL="crlf"
if [ -d "$DEST" ]; then
  first="$(find "$DEST" -maxdepth 1 -name '*.mdc' -type f | head -n 1)"
  if [ -n "$first" ] && [ "$(head -n 1 "$first" | tr -cd '\r' | wc -c)" -eq 0 ]; then EOL="lf"; fi
fi
write_rule() {
  if [ "$EOL" = "crlf" ]; then sed 's/\r$//; s/$/\r/' "$1" > "$2"; else sed 's/\r$//' "$1" > "$2"; fi
}

# --- 書き出す .md を集める ---
declare -A SRC=()   # 名前 → 正本のパス
if [ -z "$ONLY" ]; then
  echo "--only で書き出すフォルダを指定してください。Vault にあるフォルダ:" >&2
  for d in "$VAULT_RULES"/*/; do [ -d "$d" ] && echo "  $(basename "$d")" >&2; done
  echo "例: --only 共通,クライアントA,案件雛形" >&2
  exit 1
fi
IFS=',' read -r -a DIRS <<< "$ONLY"

for d in "${DIRS[@]}"; do
  dir="$VAULT_RULES/$d"
  if [ ! -d "$dir" ]; then
    echo "サブフォルダが見つかりません: $d" >&2
    exit 1
  fi
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    name="$(basename "$f" .md)"
    if [ -n "${SRC[$name]:-}" ]; then
      echo "同じ名前の rule が2つあります: $name（${SRC[$name]} と $f）" >&2
      exit 1
    fi
    SRC[$name]="$f"
  done
done

if [ ${#SRC[@]} -eq 0 ]; then
  echo "書き出す rule がありません" >&2
  exit 1
fi

# Vault 全体にある名前（--only で選ばなかったものも「Vaultにある」扱いにする）
declare -A ALL=()
while IFS= read -r f; do ALL[$(basename "$f" .md)]=1; done < <(find "$VAULT_RULES" -name '*.md' -type f)

# --- 差分を調べる ---
NEW=(); CHANGED=(); SAME=(); EXTRA=()
for name in $(printf '%s\n' "${!SRC[@]}" | sort); do
  out="$DEST/$name.mdc"
  if [ ! -e "$out" ]; then
    NEW+=("$name")
  elif same_text "${SRC[$name]}" "$out"; then
    SAME+=("$name")
  else
    CHANGED+=("$name")
  fi
done
if [ -d "$DEST" ]; then
  for out in "$DEST"/*.mdc; do
    [ -e "$out" ] || continue
    name="$(basename "$out" .mdc)"
    [ -n "${ALL[$name]:-}" ] || EXTRA+=("$name")
  done
fi

# --- 表示 ---
echo "正本      : $VAULT_RULES（${DIRS[*]}）"
echo "書き出し先: $DEST"
echo
echo "変更なし ${#SAME[@]} / 新規 ${#NEW[@]} / 変更 ${#CHANGED[@]} / Vaultにない ${#EXTRA[@]}"
for n in "${NEW[@]}";     do echo "  [新規]       $n.mdc"; done
for n in "${CHANGED[@]}"; do echo "  [変更]       $n.mdc"; done
for n in "${EXTRA[@]}";   do echo "  [Vaultにない] $n.mdc"; done

for n in "${CHANGED[@]}"; do
  echo
  echo "===== [変更] $n.mdc ====="
  diff -u --strip-trailing-cr --label "現在の $n.mdc" --label "書き出し後の $n.mdc" "$DEST/$n.mdc" "${SRC[$n]}" || true
done
for n in "${NEW[@]}"; do
  echo
  echo "===== [新規] $n.mdc ====="
  cat "${SRC[$n]}"
done

if [ $DRY_RUN -eq 1 ]; then
  echo
  echo "（dry-run のため何も書き込んでいません）"
  exit 0
fi

if [ ${#NEW[@]} -eq 0 ] && [ ${#CHANGED[@]} -eq 0 ] && [ ${#EXTRA[@]} -eq 0 ]; then
  echo "変更はありません"
  exit 0
fi

# --- 書き込み ---
echo
if [ ${#NEW[@]} -gt 0 ] || [ ${#CHANGED[@]} -gt 0 ]; then
  if [ $YES -eq 1 ] || ask "新規・変更の ${#NEW[@]}+${#CHANGED[@]} 件を書き出しますか？"; then
    mkdir -p "$DEST"
    for n in "${NEW[@]}" "${CHANGED[@]}"; do
      write_rule "${SRC[$n]}" "$DEST/$n.mdc"
      echo "書き出し: $n.mdc"
    done
  else
    echo "書き出しを中止しました"
    exit 1
  fi
fi

for n in "${EXTRA[@]}"; do
  case "$DELETE_MODE" in
    yes) rm "$DEST/$n.mdc"; echo "削除: $n.mdc" ;;
    no)  echo "残す: $n.mdc" ;;
    ask)
      if ask "Vaultにない $n.mdc を削除しますか？"; then
        rm "$DEST/$n.mdc"; echo "削除: $n.mdc"
      else
        echo "残す: $n.mdc"
      fi ;;
  esac
done

echo "完了"
