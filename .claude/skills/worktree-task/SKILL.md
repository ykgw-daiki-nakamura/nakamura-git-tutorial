---
name: worktree-task
description: >-
  作業指示を受けたら、まず計画を GitHub Issue にまとめてから、その作業専用の git worktree を
  新しいブランチで作成し、その中だけでファイルを編集・コミットして作業する skill。既存の作業ツリーや
  他ブランチを汚さずに独立して進められる。作業後は差分を提示しつつ push / PR まで対応し
  （PR には該当 Issue をリンク）、不要になった worktree を後片付けする。
  1 PR は約 400 行を目安にし、大きくなる場合は Issue の分割を検討する。
  「worktree で作業して」「worktree を切ってこのタスクをやって」「隔離環境で〜を実装して」等で使う。
  Plan in a GitHub Issue first, then create a dedicated git worktree on a new branch, do all work inside it,
  open a PR linked to the Issue, then clean up.
---

# worktree-task — 計画を Issue にまとめ、作業専用の git worktree を切って作業する

作業指示を受けたら、**まず計画を GitHub Issue にまとめ**、その作業だけのための
**git worktree** を新しいブランチで作成し、その worktree の中でファイルを編集・コミットする skill。
メインの作業ツリーや現在のブランチに未コミット変更を持ち込まず、タスクごとに隔離して進められる。

このリポジトリでは worktree を `.claude/worktrees/<name>` 配下に作る運用。追跡対象の
`.gitignore` に `.claude/worktrees/` を登録済みなので、worktree の実体はコミット対象にならない
（他の環境でも共有される。もし未登録なら着手前に `.gitignore` へ追加すること）。

## 引数

`args` は自由記述。以下を読み取る（省略時は既定値／会話文脈から解決）。

- **タスク内容** — 何をするか。省略時は直近の会話の作業指示を対象にする。指示が曖昧なら着手前に確認する。
- **ブランチ種別 (type)** — Conventional Commits の type（`feat` / `fix` / `docs` / `chore` / `ci` / `build` / `refactor` / `test`）。省略時はタスク内容から推定する。
- **派生元 (base)** — worktree を切る元ブランチ名。例 `main` / `feat/xxx`。省略時は既定で **`main`**（独立作業のため、実際は最新の `origin/main` から切る）。現在の未コミット変更を引き継ぎたい場合のみローカルの現在ブランチを base にする。
- **Issue 番号** — 既存の計画 Issue を使う場合はその番号。省略時は本 skill が新規に作成する。
- **後片付け方針** — 完了後に worktree を残すか削除するか。省略時は **確認してから削除**。

## 手順

### 1. 作業内容とブランチ名を確定

- タスク内容を 1 行で要約し、Conventional Commits 準拠のブランチ名を決める。
  形式は `<type>/<kebab-summary>`（例 `docs/release-guide`, `feat/search-filter`）。
- worktree のディレクトリ名はブランチの `<kebab-summary>` 部分を使い、`.claude/worktrees/<name>` とする。
- 名前が既存の worktree / ブランチと衝突しないか確認する。

```bash
git worktree list
git branch --list '<type>/<kebab-summary>'
```

### 2. 作業計画を Issue にまとめてから着手

**着手前に、計画を GitHub Issue に作成してまとめる。** これ以降のコミット・PR はこの Issue に紐づける。

- 既存の計画 Issue が指定されていればそれを使う。無ければ新規作成する。
- Issue には次を書く: **目的 / 背景・スコープ / 作業計画（チェックリスト） / 完了条件（受け入れ基準）**。
- **規模の見積もりをこの段階で行う。** 1 タスク（= 1 PR）の変更は **約 400 行を目安**に収める。
  超えそうなら、**Issue（および PR）の分割**を検討し、独立して着手・レビューできる単位に割る。
  分割する場合は親 Issue に全体像とサブ Issue へのリンク（タスクリスト）を書き、各サブ Issue ごとに
  本 skill を回す（1 サブ Issue = 1 worktree = 1 ブランチ = 1 PR）。分割方針はユーザーに提示して合意を取る。
- 作成は outward-facing。本文（特に計画内容・分割方針）をユーザーに提示し、**Issue を立てる前に確認**を取る。

```bash
gh issue create \
  --title "<type>: <タスク要約>" \
  --body "$(cat <<'BODY'
## 目的

<なぜやるか>

## スコープ

<対象 / 対象外>

## 作業計画

- [ ] <ステップ1>
- [ ] <ステップ2>

## 完了条件

- [ ] <受け入れ基準>
BODY
)"
```

- 作成した Issue 番号を控える（以降 `<ISSUE>` と表記）。ブランチ名・派生元・後片付け方針とあわせて記憶しておく。
- 大きなタスクは Issue 内チェックリストで進捗を可視化する（作業に応じて `gh issue edit` で更新）。

**着手を宣言する。** Issue を確定したら、対象 Issue に `status: in-progress` ラベルを付与し、
自分をアサインする。これにより一覧で「着手中」を一目で判別でき、複数エージェント／担当が
Issue を分担する際の二重着手を防げる（`status: in-progress` ラベルは作成済み。無いリポジトリでは
先に `gh label create "status: in-progress" --color fbca04` で用意する）。

```bash
gh issue edit <ISSUE> --add-label "status: in-progress" --add-assignee @me
```

- 完了時の扱い: PR 本文の `Closes #<ISSUE>` によりマージ時に Issue は自動クローズされる。
  ラベルはクローズしても自動では外れないため、運用上残したくなければ手順 6 以降で
  `gh issue edit <ISSUE> --remove-label "status: in-progress"` を実行して除去してよい（任意）。

### 3. worktree を作成

派生元は最新のリモート追跡ブランチ（既定 `origin/main`）から切る。`git fetch` だけでは
ローカルの `main` は更新されないため、**`origin/<base>` を base に指定**して常に最新から切る。

```bash
git fetch origin --quiet                                  # リモート追跡ブランチを最新化
git worktree add -b <type>/<kebab-summary> .claude/worktrees/<name> origin/<base>
git worktree list   # 作成を確認
```

- 新ブランチ `<type>/<kebab-summary>` は `origin/<base>` の最新コミットを起点に作られる。
- ローカルの未コミット変更を引き継ぎたい場合のみ、base をローカルの現在ブランチ名にする（`origin/` は付けない）。
- `.claude/worktrees/` は追跡対象の `.gitignore` に登録済みなので worktree 実体はコミット対象にならない
  （未登録のリポジトリで使う場合は先に `.gitignore` へ追加しておく）。
- 以降のファイル編集・`git` 操作は **すべてこの worktree ディレクトリ内** で行う
  （`git -C <worktree> ...` またはそのパス配下のファイルを編集）。メインの作業ツリーは触らない。

### 4. worktree 内で作業

- Issue の作業計画に沿って、worktree 内のファイルに変更を実施する。
- 必要に応じてビルド/テスト/lint をその worktree 内で実行し、成否を確認する（例 `npm run build`）。
- 計画のステップが進んだら Issue のチェックリストを更新してよい（`gh issue edit <ISSUE>` 等）。

### 5. コミット・push

1. `git -C <worktree> status` と `git -C <worktree> diff` で変更内容を確認・提示する。
2. **Conventional Commits 準拠**のメッセージでコミットする（`type(scope): 要約`）。
   このリポジトリの規約（[Conventional Commits](https://www.conventionalcommits.org/ja/v1.0.0/)）に従う。
3. **push は事前確認不要**。コミット後そのまま `git -C <worktree> push -u origin <type>/<kebab-summary>` してよい
   （変更内容は提示するが、push の許可待ちはしない）。

```bash
git -C <worktree> add -A
git -C <worktree> commit -m "<type>(<scope>): <要約>"
git -C <worktree> diff --stat HEAD~1   # 直前コミットの範囲確認
```

### 6. PR を作成（該当 Issue をリンク）

push 後、PR を作成する。**PR には必ず該当 Issue をリンクする。**

- PR 本文に **closing keywords**（`Closes #<ISSUE>` / `Fixes #<ISSUE>`）を記載し、
  マージ時に Issue が GitHub のネイティブ機能で自動クローズされるようにする。
- 単に参照だけしたい（マージでは閉じたくない）場合は `Refs #<ISSUE>` を使う。
- **PR 作成も事前確認不要**。push 後そのまま作成してよい（本文とリンク先 Issue は結果として提示する）。

```bash
gh pr create \
  --base <base> --head <type>/<kebab-summary> \
  --title "<type>(<scope>): <要約>" \
  --body "$(cat <<'BODY'
## 概要

<変更の要約>

## 変更点

- <主な変更>

Closes #<ISSUE>
BODY
)"
gh pr view --json number,url,closingIssuesReferences   # Issue 連動が効いているか検証
```

- `closingIssuesReferences` が空なら本文の closing keyword を見直し、`gh pr edit --body ...` で修正する。

### 7. 後片付け

作業が完了し、成果（ブランチ / PR / Issue）が保全されたら worktree の実体を撤去する。
**ブランチ・Issue は消さない**（push 済み・PR 済みの成果を保持し、Issue はマージ時に自動クローズさせる）。

- 後片付け方針が「確認してから削除」（既定）なら、削除してよいかユーザーに確認する。
- コミットしていない変更が残っていないことを確認してから削除する。
- `git worktree remove` は**削除対象の worktree の中からは実行できない**（カレントディレクトリを消せないため失敗する）。
  必ず**メインの作業ツリー（またはリポジトリのルート `<main-worktree>`）から実行する**。

```bash
git -C <worktree> status --porcelain          # 空であることを確認（<worktree> = 削除対象のパス）
git -C <main-worktree> worktree remove .claude/worktrees/<name>   # メイン作業ツリーから実行
git -C <main-worktree> worktree prune
git -C <main-worktree> worktree list          # 撤去を確認
```

- 未コミット変更が残っている場合は削除しない。ユーザーに残すか破棄するか確認する。
- worktree を残す指示なら削除せず、パスをユーザーに伝えて終了する。

## 注意

- **着手前に計画 Issue を必ず作る**（既存 Issue 指定時はそれを使う）。行き当たりばったりで作業を始めない。
- **1 タスク（1 PR）の変更は約 400 行を目安**にし、超える見込みなら Issue / PR の分割を検討する。
- **PR は必ず該当 Issue をリンクする**（既定は closing keyword で自動クローズ連動）。
- **すべての編集・コミットは worktree 内で行う。** メインの作業ツリーや他ブランチを変更しない。
- Issue 作成前は計画を提示して確認を取る。**push・PR 作成は事前確認不要**でそのまま進めてよい
  （マージ／Issue クローズなどさらに外向きの操作は状況に応じて確認する）。これは本リポジトリ
  オーナーの運用方針としての既定。他リポジトリで使う場合は、その場の方針に合わせて確認要否を判断する。
- ブランチ名・コミットメッセージ・PR/Issue タイトルは [Conventional Commits](https://www.conventionalcommits.org/ja/v1.0.0/) に従う。
- `git worktree remove` は未コミット変更があると失敗する（安全側）。強制削除 `--force` は
  変更破棄を伴うため、ユーザーの明示確認なしに使わない。
- 派生元は既定 `main`。現在ブランチの未コミット変更を引き継ぎたい場合のみ base を現在ブランチにする
  （その際は先に元ブランチで stash/commit するか確認する）。
- 1 タスク = 1 Issue = 1 worktree = 1 ブランチ = 1 PR を基本とし、無関係な変更を混在させない。
