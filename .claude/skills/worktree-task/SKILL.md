---
name: worktree-task
description: >-
  作業指示を受けたら、その作業専用の git worktree を新しいブランチで作成し、その中だけで
  ファイルを編集・コミットして作業する skill。既存の作業ツリーや他ブランチを汚さずに独立して
  進められる。作業後は差分提示 → 確認の上で push / PR まで対応し、不要になった worktree を後片付けする。
  「worktree で作業して」「worktree を切ってこのタスクをやって」「隔離環境で〜を実装して」等で使う。
  Create a dedicated git worktree on a new branch for a task, do all work inside it, then clean up.
---

# worktree-task — 作業専用の git worktree を切って作業する

作業指示を受けたら、**その作業だけのための git worktree** を新しいブランチで作成し、
その worktree の中でファイルを編集・コミットする skill。メインの作業ツリーや現在のブランチに
未コミット変更を持ち込まず、タスクごとに隔離して進められる。

このリポジトリでは worktree を `.claude/worktrees/<name>` 配下に作る運用（gitignore 済み）。

## 引数

`args` は自由記述。以下を読み取る（省略時は既定値／会話文脈から解決）。

- **タスク内容** — 何をするか。省略時は直近の会話の作業指示を対象にする。指示が曖昧なら着手前に確認する。
- **ブランチ種別 (type)** — Conventional Commits の type（`feat` / `fix` / `docs` / `chore` / `ci` / `build` / `refactor` / `test`）。省略時はタスク内容から推定する。
- **派生元 (base)** — worktree を切る元。例 `main` / `feat/xxx`。省略時は既定で **`main`**（独立作業のため）。現在の未コミット変更を引き継ぎたい場合のみ現在ブランチを base にする。
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

### 2. worktree を作成

派生元ブランチ（既定 `main`）は最新化してから切ると安全。

```bash
git fetch origin --quiet 2>/dev/null || true
git worktree add -b <type>/<kebab-summary> .claude/worktrees/<name> <base>
git worktree list   # 作成を確認
```

- `.claude/worktrees/` は gitignore 済みなので worktree 実体はコミット対象にならない。
- 以降のファイル編集・`git` 操作は **すべてこの worktree ディレクトリ内** で行う
  （`git -C <worktree> ...` またはそのパス配下のファイルを編集）。メインの作業ツリーは触らない。

### 3. worktree 内で作業

- 指示された変更を worktree 内のファイルに対して実施する。
- 必要に応じてビルド/テスト/lint をその worktree 内で実行し、成否を確認する（例 `npm run build`）。
- 進捗が多段になる場合は TodoWrite で管理してよい。

### 4. コミット（push 前に確認）

1. `git -C <worktree> status` と `git -C <worktree> diff` で変更内容を確認・提示する。
2. **Conventional Commits 準拠**のメッセージでコミットする（`type(scope): 要約`）。
   このリポジトリの規約 [[conventional-commits]] に従う。
3. push は outward-facing。**push / PR 作成の前にユーザーへ確認**を取る。
   - 承認されたら: `git -C <worktree> push -u origin <branch>` → 必要なら `gh pr create`。
   - 保留なら: コミットを保持したまま指示を待つ。

```bash
git -C <worktree> add -A
git -C <worktree> commit -m "<type>(<scope>): <要約>"
git -C <worktree> diff --stat HEAD~1   # 直前コミットの範囲確認
```

### 5. 後片付け

作業が完了し、成果（ブランチ / PR）が保全されたら worktree の実体を撤去する。
**ブランチは消さない**（push 済み・PR 済みの成果を保持するため）。

- 後片付け方針が「確認してから削除」（既定）なら、削除してよいかユーザーに確認する。
- コミットしていない変更が残っていないことを確認してから削除する。

```bash
git -C <worktree> status --porcelain   # 空であることを確認
git worktree remove .claude/worktrees/<name>
git worktree prune
git worktree list                      # 撤去を確認
```

- 未コミット変更が残っている場合は削除しない。ユーザーに残すか破棄するか確認する。
- worktree を残す指示なら削除せず、パスをユーザーに伝えて終了する。

## 注意

- **すべての編集・コミットは worktree 内で行う。** メインの作業ツリーや他ブランチを変更しない。
- push・PR 作成は outward-facing。手順どおり事前確認を挟む。
- ブランチ名・コミットメッセージは Conventional Commits に従う（[[conventional-commits]]）。
- `git worktree remove` は未コミット変更があると失敗する（安全側）。強制削除 `--force` は
  変更破棄を伴うため、ユーザーの明示確認なしに使わない。
- 派生元は既定 `main`。現在ブランチの未コミット変更を引き継ぎたい場合のみ base を現在ブランチにする
  （その際は先に元ブランチで stash/commit するか確認する）。
- 1 タスク = 1 worktree = 1 ブランチ を基本とし、無関係な変更を混在させない。
