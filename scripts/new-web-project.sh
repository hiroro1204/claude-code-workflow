#!/bin/bash
# Usage: new-web-project.sh <project-name> <template-repo>
# Example: new-web-project.sh my-site username/web-template

set -e

# Git Bash(MSYS)がPOSIXパスの引数を自動でWindowsパスに変換してしまう問題を防ぐ
# （例: /home/xs000000/... が C:/Program Files/Git/home/xs000000/... に化ける）
export MSYS_NO_PATHCONV=1

PROJECT_NAME="$1"
TEMPLATE_REPO="$2"
SERVER_DIR="$3"
DESKTOP="$HOME/Desktop"

if [ -z "$PROJECT_NAME" ] || [ -z "$TEMPLATE_REPO" ] || [ -z "$SERVER_DIR" ]; then
  echo "使い方: $0 <project-name> <template-repo> <server-dir>"
  echo "例: $0 my-site username/web-template /home/xs000000/public_html/my-site/"
  exit 1
fi

if [[ "$SERVER_DIR" != /* ]]; then
  echo "Error: <server-dir> は / から始まる必要があります（例: /home/xs000000/...）"
  exit 1
fi

# 末尾スラッシュがなければ付与
[[ "$SERVER_DIR" != */ ]] && SERVER_DIR="${SERVER_DIR}/"

if [ -d "$DESKTOP/$PROJECT_NAME" ]; then
  echo "Error: $DESKTOP/$PROJECT_NAME already exists."
  exit 1
fi

echo "Creating '$PROJECT_NAME' from template '$TEMPLATE_REPO'..."

cd "$DESKTOP"
gh repo create "$PROJECT_NAME" \
  --template "$TEMPLATE_REPO" \
  --private \
  --clone

REMOTE_URL=$(cd "$PROJECT_NAME" && git remote get-url origin)

echo ""
echo "Done!"
echo "  Local : $DESKTOP/$PROJECT_NAME"
echo "  Remote: $REMOTE_URL"

# デプロイ設定
source "$HOME/.deploy-secrets"

echo ""
echo "この内容でSecretsを登録します。SERVER_DIR = $SERVER_DIR  よろしいですか？ (y/n)"
read -rp "> " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "キャンセルしました。"
  exit 0
fi

echo ""
echo "GitHub Secrets を登録しています..."
cd "$DESKTOP/$PROJECT_NAME"
gh secret set SSH_HOST       --body "$SSH_HOST"
gh secret set SSH_PORT       --body "$SSH_PORT"
gh secret set SSH_USER       --body "$SSH_USER"
gh secret set SSH_PRIVATE_KEY < "$SSH_KEY_PATH"
gh secret set SERVER_DIR     --body "$SERVER_DIR"

# .deploy-infoファイルを作成
echo "SERVER_DIR=${SERVER_DIR}" > .deploy-info
echo "PROJECT_NAME=${PROJECT_NAME}" >> .deploy-info
echo "CREATED_AT=$(date '+%Y-%m-%d')" >> .deploy-info
echo "✅ .deploy-info を作成しました"

echo ""
echo "登録完了:"
echo "  SSH_HOST       = $SSH_HOST"
echo "  SSH_PORT       = $SSH_PORT"
echo "  SSH_USER       = $SSH_USER"
echo "  SSH_PRIVATE_KEY = ($(basename "$SSH_KEY_PATH") の内容)"
echo "  SERVER_DIR     = $SERVER_DIR"

# テンプレートからのリポジトリ作成時点でpushイベントが発火し、
# Secrets登録より前にデプロイワークフローが一度走って失敗している場合があるため、
# 直近の実行結果を確認し、失敗していれば自動で再実行する
echo ""
echo "初回ワークフローの状態を確認しています..."
for i in $(seq 1 10); do
  STATUS=$(gh run list --limit 1 --json status --jq '.[0].status' 2>/dev/null || echo "")
  if [ "$STATUS" = "completed" ] || [ -z "$STATUS" ]; then
    break
  fi
  sleep 3
done

RUN_ID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo "")
CONCLUSION=$(gh run list --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null || echo "")

if [ -n "$RUN_ID" ] && [ "$CONCLUSION" = "failure" ]; then
  echo "Secrets登録前に実行され失敗した初回ワークフロー (Run #$RUN_ID) を検出しました。再実行します..."
  gh run rerun "$RUN_ID"
  echo "✅ 再実行しました。GitHub Actionsで結果を確認してください。"
fi
