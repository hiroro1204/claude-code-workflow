# 新規Webプロジェクト作成

新しいWebサイトプロジェクトをGitHubテンプレートから作成し、デプロイ用のGitHub Secretsを自動登録します。

## 使い方

`/new-site` と入力すると、以下の手順で進めてください：

1. **テンプレートリポジトリの取得** — `gh` CLIで以下のコマンドを実行し、`is_template: true` のリポジトリ一覧を取得する（プライベートリポジトリも含む）：
   ```bash
   gh api "user/repos?per_page=100&type=owner" --jq '[.[] | select(.is_template == true) | {name: .name, description: .description}]'
   ```
2. **テンプレートを選択** させる。取得したテンプレートリポジトリを番号付きで表示する
3. **プロジェクト名** をユーザーに質問する（例: `client-website`）
4. **デプロイ先のサーバーパス（SERVER_DIR）** をユーザーに質問する（例: `/home/xs000000/public_html/client-website/`）
5. 上記3つが揃ったら、以下のコマンドを実行する：

```bash
bash "~/scripts/new-web-project.sh" "<project-name>" "<template-repo>" "<server-dir>"
```

## スクリプトが自動で行うこと

1. 引数のバリデーション（`<server-dir>` が `/` 始まりかチェック）
2. GitHubにプライベートリポジトリを作成し、デスクトップにクローン
3. `~/.deploy-secrets` からSSH接続情報を読み込む
4. 登録内容を確認（y/n）してから、以下の5つのGitHub Secretsをリポジトリに登録する：
   - `SSH_HOST` — サーバーホスト名
   - `SSH_PORT` — SSHポート番号
   - `SSH_USER` — SSHユーザー名
   - `SSH_PRIVATE_KEY` — 秘密鍵ファイルの中身
   - `SERVER_DIR` — デプロイ先ディレクトリパス
5. Secrets登録直後に直近のGitHub Actions実行結果を確認し、失敗していれば自動で再実行する（テンプレート作成時の初回pushがSecrets登録前に走って失敗するケースに対応）

実行後、作成されたローカルパス・GitHubリポジトリのURL・登録したSecretsの内容・（再実行した場合は）その旨を表示してください。

## 既知の問題と対策（修正済み）

- **Secrets未登録での初回デプロイ失敗**: `gh repo create --template ... --clone` の時点でリポジトリに初回コミットが作成され、デプロイワークフローがSecrets登録前にpushトリガーで走ってしまい失敗することがある。→ スクリプトがSecrets登録後に直近の実行結果をチェックし、失敗していれば `gh run rerun` で自動的に再実行する。
- **`SERVER_DIR` のパス化け**: Git Bash(MSYS)は `/home/...` のようなPOSIXパスの引数を自動的に `C:/Program Files/Git/home/...` のようなWindowsパスに変換してしまうため、`gh secret set SERVER_DIR --body "..."` の値が化けることがある。→ スクリプト冒頭で `export MSYS_NO_PATHCONV=1` を設定し、この自動変換を無効化した。
