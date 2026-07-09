# .gitignore で追跡除外する

ビルド生成物・依存パッケージ・秘密情報・エディタ設定など、**Git で管理したくないファイル**は必ず出てきます。これらを追跡対象から外すのが `.gitignore` です。チーム開発では「`node_modules/` を誤ってコミットしてしまう」「各自のローカル設定が毎回差分に出る」といった事故を防ぐ、最初に押さえたい仕組みです。

## 何を無視すべきか

| 種類 | 例 |
| --- | --- |
| **依存・生成物** | `node_modules`、`dist/`、`build/`、`*.log` |
| **秘密情報** | `.env`、`*.pem`、APIキーを含む設定ファイル |
| **環境・エディタ固有** | `.DS_Store`、`.vscode/`、`.idea/` |
| **キャッシュ・一時ファイル** | `.cache/`、`*.tmp` |

逆に、**チーム全員に必要なもの**（ソース、`package.json`、ロックファイル `package-lock.json` など）は追跡対象に残します。

## 基本の書き方

リポジトリのルートに `.gitignore` というファイルを置き、1 行に 1 パターンを書きます。

```text
# コメントは行頭に書く
node_modules
# 拡張子でまとめて（ワイルドカード *）
*.log
# 末尾 / でディレクトリのみ対象
dist/
# 秘密情報
.env
# ! で「除外の例外」（これは追跡する）
!.env.example
```

::: warning コメントは必ず独立行に
`.gitignore` の `#` コメントは**行頭でのみ有効**です。`node_modules  # 依存` のようにパターンと同じ行へ書くと、`#` 以降も含めて 1 つのパターンとして扱われ、**その行の無視が効かなくなります**。コメントは必ずパターンとは別の行に書いてください。効いているかは `git check-ignore -v <ファイル>` で確認できます。
:::

パターンの要点は次のとおりです。

| 記法 | 意味 |
| --- | --- |
| `名前/` | 末尾の `/` でディレクトリのみにマッチ（symlink はマッチしない。後述の落とし穴を参照） |
| `*.log` | `*` は任意の文字列（`/` を除く）にマッチ |
| `!パターン` | 先頭の `!` で、いったん無視した対象を**除外の例外**にする（ただし親ディレクトリ自体を無視している場合は再包含できない） |
| `/名前` | 先頭の `/` でリポジトリ直下のみに限定（サブディレクトリは対象外） |
| `**/名前` | 任意の階層にマッチ（例: `**/tmp`） |

## すでに追跡済みのファイルを外す

`.gitignore` は**まだ追跡していないファイル**にしか効きません。すでに `git add` / commit してしまったファイルは、`.gitignore` に書いても追跡され続けます。この場合は追跡だけを解除します。

```bash
# 追跡をやめる（ローカルのファイルは残す）。--cached が重要
git rm --cached .env
git rm -r --cached node_modules/

# その後 .gitignore に追記してコミット
git commit -m "chore: .env と node_modules を追跡から除外"
```

::: warning すでに push した秘密情報は「無効化」する
`.env` などを一度でも push してしまったら、追跡解除だけでは**履歴に残ったまま**です。漏れたトークンやパスワードは**必ずローテーション（無効化・再発行）** してください。履歴からの完全削除は `git filter-repo` 等で可能ですが、まずは鍵の無効化が最優先です。
:::

## グローバル gitignore（自分専用の除外）

`.DS_Store`（macOS）や特定エディタの設定など、**プロジェクトではなく自分の環境に依存する**ものは、リポジトリの `.gitignore` に入れるべきではありません。自分のマシン全体に効く**グローバル gitignore** を使います。

```bash
git config --global core.excludesfile ~/.gitignore_global
# ~/.gitignore_global に .DS_Store などを書いておく
```

## .gitignore の実例

実際の [.gitignore](https://github.com/ykgw-daiki-nakamura/nakamura-git-tutorial/blob/main/.gitignore) の例です。生成物・ランタイム成果物・個人設定を的確に除外しています。内容は次のとおりです。

```text
# 末尾スラッシュを付けない: 付けるとディレクトリにしかマッチせず、
# node_modules という名前の symlink が追跡対象に入り込む
node_modules
docs/.vitepress/dist/
docs/.vitepress/cache/

# worktree-task skill が作業用 worktree を作る場所（実体はコミット対象外にする）
.claude/worktrees/

# ランタイム生成物・個人用ローカル設定（コミット対象外）
.claude/scheduled_tasks.lock
.claude/settings.local.json
```

除外しているのは、`node_modules` や `dist/` のように再生成できるものと、`.claude/worktrees/` や `.claude/settings.local.json` のように各自のローカル専用のものです。コメントは対象の直前に置いておくと、なぜ無視するのかが後から追えます。

`node_modules` にだけ末尾スラッシュが付いていないのは意図的です。理由は次節の落とし穴で説明します。

## よくある落とし穴

- **コミット後に `.gitignore` へ足しても効かない** → 追跡済みなので `git rm --cached` が必要。
- **無視されているか確かめたい** → `git check-ignore -v <ファイル>` でどのパターンに当たったか分かる。
- **空ディレクトリを残したい** → Git は空ディレクトリを追跡しないので、慣習的に `.gitkeep` を置く。

### 末尾 `/` は symlink にマッチしない

末尾の `/` は「ディレクトリだけ」に限定する意味です。意図が明確になる一方、**シンボリックリンクを取りこぼす**という副作用があります。Git はリンク先ではなくリンク自体を見るため、symlink はディレクトリとして扱われないからです。

```bash
ln -s /somewhere/node_modules node_modules

# 末尾スラッシュあり: 無視されない
echo 'node_modules/' > .gitignore
git check-ignore node_modules   # 何も出ない（＝マッチしない）

# 末尾スラッシュなし: 無視される
echo 'node_modules' > .gitignore
git check-ignore node_modules   # node_modules
```

`node_modules` のように **symlink になりうる対象には末尾スラッシュを付けない**のが安全です。monorepo や pnpm、devcontainer、`git worktree` の共有など、依存ディレクトリを symlink にする構成は珍しくありません。

::: warning このリポジトリで実際に起きた
`.gitignore` に `node_modules/` と書いてあったにもかかわらず、`node_modules` という symlink が `git add -A` で拾われ、**絶対パスを指すリンクがコミットされていました**。

`git status` には毎回 `D node_modules` が出続け、`git worktree remove` は失敗し、別のマシンでは壊れたリンクになる。原因に気づくまで時間がかかりました。修正はパターンから末尾スラッシュを外すだけです。
:::

---

無視すべきものを最初に整理しておくと、差分がノイズのない状態に保たれ、レビューもしやすくなります。追跡・除外の確認で困ったら[トラブルシューティング](./troubleshooting)も参照してください。
