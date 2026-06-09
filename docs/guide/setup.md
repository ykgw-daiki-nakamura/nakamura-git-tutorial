# セットアップ

Git のインストールと、チーム開発を始める前に**必ず**やっておくべき初期設定をまとめます。

## インストール

| OS | 方法 |
| --- | --- |
| macOS | `brew install git`（または Xcode Command Line Tools） |
| Windows | [Git for Windows](https://gitforwindows.org/) をインストール |
| Linux (Debian/Ubuntu) | `sudo apt install git` |

インストール後、バージョンを確認します。

```bash
git --version
```

## 最初にやる設定

コミットには「誰が」の情報が記録されます。名前とメールアドレスを設定しましょう。**GitHub に登録したメールアドレス**を使うと、コミットが GitHub 上のアカウントに紐づきます。

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

その他、チーム開発で推奨される設定です。

```bash
# デフォルトブランチ名を main に
git config --global init.defaultBranch main

# pull 時に余計なマージコミットを作らない（rebase 派の場合）
git config --global pull.rebase false   # マージ派なら false / リベース派なら true

# 改行コードの自動変換（Windows は true、macOS/Linux は input 推奨）
git config --global core.autocrlf input

# エディタの指定（例: VS Code）
git config --global core.editor "code --wait"
```

設定の確認は次のコマンドで行えます。

```bash
git config --list
```

## GitHub への認証

GitHub にリポジトリを push するには認証が必要です。HTTPS と SSH の 2 方式があります。

```mermaid
flowchart LR
    PC[ローカル] -->|HTTPS + PAT| GH[GitHub]
    PC -->|SSH 鍵| GH
```

### 方式1: SSH 鍵（推奨）

一度設定すれば毎回の認証が不要になります。

```bash
# 鍵を生成（パスフレーズは任意）
ssh-keygen -t ed25519 -C "you@example.com"

# 公開鍵を表示してコピー
cat ~/.ssh/id_ed25519.pub
```

表示された公開鍵を GitHub の **Settings → SSH and GPG keys → New SSH key** に登録します。接続確認は次の通りです。

```bash
ssh -T git@github.com
```

### 方式2: HTTPS + Personal Access Token (PAT)

パスワードの代わりに PAT を使います。GitHub の **Settings → Developer settings → Personal access tokens** で発行し、push 時のパスワード入力欄に貼り付けます。`git credential` に保存すると以降は省略できます。

::: tip どちらを選ぶ？
個人の開発マシンでは **SSH 鍵**が手軽でおすすめです。CI 環境や一時的なアクセスには **PAT** が向いています。
:::

設定が終わったら、次は [Git の基本](./basics) に進みましょう。
