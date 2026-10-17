# claude-code-workflow

Webコーダー・石山克弘が、Claude Code と Cursor を仕事でどう使っているかをまとめたリポジトリです。
自作のスキル・スラッシュコマンド・フック・スクリプトと、その設計の説明を置いています。

- ポートフォリオ：https://hiron-folio.com
- 使っているAI：Cursor（約1年）、Claude Code（デスクトップアプリ）、claude.ai
- 公開にあたり、社内の人名・案件名・サーバー情報・接続情報は外しています

---

## 1. 業務自動化エージェント：工数記録（日報）

Toggl・Notion・Discord に分かれている1日の作業を集めて、工数記録の行データを作り、スプレッドシートに書き込むスキルです。
社内情報が多いので本体は非公開です。設計と、作りながら判断したことを [docs/daily-report-agent.md](docs/daily-report-agent.md) にまとめました。

- 足りない情報は「まとめて1回だけ」質問する
- AI が書き込むのは自分用のコピーだけ。共有の本番シートには書かない
- 音声入力の誤認識を辞書で直し、使うほど聞き返しが減る
- ブラウザ自動操作が不安定だったので、GAS の API で書き込む方式に切り替えた

## 2. AIエージェントの運用設計とナレッジの構造化

Obsidian の Vault を、AI と共有する知識の置き場にしています。

| ファイル | 役割 |
|---|---|
| [examples/AGENTS.md](examples/AGENTS.md) | Vault で作業するAI共通のルール。どこに何を保存するか、書き方、やってはいけないこと |
| [examples/CLAUDE.md](examples/CLAUDE.md) | Claude Code の全体の指示。AGENTS.md を読み込む |
| [skills/vault-skill-doc](skills/vault-skill-doc/SKILL.md) | スキルの使い方を Vault に書き残すスキル |
| [hooks/skill_doc_hook.py](hooks/skill_doc_hook.py) | スキルを作ったり変えたりしたら、上のスキルを動かすよう Claude に知らせるフック |
| [hooks/dotfiles_hook.py](hooks/dotfiles_hook.py) ／ [scripts/sync-dotfiles.sh](scripts/sync-dotfiles.sh) | スキルや設定が変わったら、GitHub に自動でバックアップするフック |
| [examples/settings.hooks.json](examples/settings.hooks.json) | 上の2つのフックの設定例 |

Claude Code と Cursor が同じルールで動くこと、作ったスキルの使い方を忘れないこと、を目的にしています。

## 3. 開発フローの自動化

| ファイル | 何をするか |
|---|---|
| [commands/new-site.md](commands/new-site.md) ／ [scripts/new-web-project.sh](scripts/new-web-project.sh) | `/new-site` でテンプレートから案件リポジトリを作り、GitHub Actions の自動デプロイに必要な Secrets を登録する |
| [commands/split-design-comp.md](commands/split-design-comp.md) | デザインカンプの画像を、Python（Pillow・numpy）でセクションごとに切り分ける |
| [scripts/export-cursor-rules.sh](scripts/export-cursor-rules.sh) | Vault で管理しているコーディングルールを、テンプレートの Cursor rule に書き出す |
| [skills/session-title-refresh](skills/session-title-refresh/SKILL.md) | Claude Code のセッション名を、作業内容に合わせて付け直す |

`/new-site` では、作りながら次の問題を見つけて直しました（詳しくは [commands/new-site.md](commands/new-site.md)）。

- テンプレートから作った直後の最初のデプロイが、Secrets を登録する前に動いて失敗する → 登録後に失敗を見つけて自動で再実行
- Git Bash が `/home/...` のようなパスを Windows のパスに書き換えてしまう → `MSYS_NO_PATHCONV=1` で止める

## 4. 実装・確認・管理画面の操作

ふだんのコーディングと WordPress の作業では、次のように AI を使っています。

1. **実装**：Cursor に入れたコーディングルールをもとに、Figma の MCP サーバーで読み込んだデザインデータ（またはスクリーンショット）からコーディングさせる
2. **確認・微調整**：Playwright MCP でブラウザを開いて表示を確かめながら、自分でエディタで直すか、AI に指示して直す
3. **管理画面の操作**：Playwright MCP で WordPress の管理画面を操作し、プラグインの設定や、SEO プラグインでのタイトル・ディスクリプションの入力を行う

安全のために決めていること：

- 管理画面へのログインは自分で行い、ログインした状態の画面を AI に渡す（パスワードを AI に渡さない）
- 作業はテスト環境で行うことが基本。本番サイトで行うときは、バックアップを取ってから
- 操作の前に Claude と一緒に作業の計画を立て、その計画を自分で確認してから実行する

ほとんどの作業は計画どおりに進みます。フォームのプラグインの設定では、フォームの ID がうまく入らないことがありました。

## 5. うまくいかなかった挑戦

Figma の無料プランでは、AI がデザインデータを読み込める回数が月6回までに制限されています。そこで、Figma プラグイン経由で制限なく読み込める公開ツール「Figma MCP Bridge」を、記事を参考に自分用に改造しようとしました（選んだデザインの URL をパネルに表示する、Figma に設定されたリンク先を読み取る、の2つ）。

Bridge を通して AI とつなぐところまではできましたが、選んでいるデザインの URL をまとめてプラグインのパネルに表示する部分がうまく動きませんでした。今は Figma の MCP サーバーを使ってデザインデータを読み込んでいます。

---

## 使っている道具

Claude Code ／ Cursor ／ Figma MCP ／ Playwright MCP ／ GitHub・GitHub Actions ／ Obsidian ／ Notion ／ Toggl Track ／ Google Apps Script ／ Python ／ Bash ／ PowerShell
