---
name: pr-desc
description: >-
  現在のブランチの差分と連動 Issue から、`Closes #N` 付きの PR 説明文（概要・変更点・確認）を
  生成する skill。まだ PR が無ければ本文案を提示し、既にあれば本文を更新する。
  worktree-task で作った変更をそのまま PR 化する／pr-watch へ引き継ぐ用途に繋がる。
  「PR の説明を書いて」「この差分で PR 本文を作って」「Closes 付きの説明を生成して」等で使う。
  Generate a PR description (with Closes #N) from the branch diff and its linked issue.
---

# pr-desc — PR 説明文の生成

現在のブランチの**差分**と**連動 Issue** から、レビューしやすい PR 説明文を組み立てる skill。
本文は「概要 / 変更点 / 確認 / `Closes #N`」の定型に沿わせる。
[worktree-task](../worktree-task/SKILL.md) で作った変更を PR 化する仕上げ、または既存 PR の
本文を整えるのに使う。生成後は [pr-watch](../pr-watch/SKILL.md) にそのまま監視を引き継げる。

## 引数

`args` は自由記述。以下を読み取る（省略時は解決）。

- **連動 Issue 番号** — 例 `#48`。省略時は「ブランチ名／コミットメッセージ中の `#N`」から推定する。
- **派生元 (base)** — 差分の比較先。省略時は `main`。
- **投稿方針** — `提示のみ`（既定）／`PR 作成`／`既存 PR 更新`。

## 手順

### 1. コンテキスト収集

```bash
git branch --show-current
git fetch origin --quiet
git diff --stat origin/<base>...HEAD          # 変更ファイルと規模
git log --oneline origin/<base>..HEAD         # コミット一覧（要約の素材）
```

- 連動 Issue が未指定なら、ブランチ名やコミット本文の `#N` を拾って候補にする。
  確定できなければユーザーに確認する（誤った Issue を閉じないため）。
- 対象 Issue の趣旨を `gh issue view <N> --json title,body` で把握し、要約に反映する。

### 2. 本文を組み立て

以下のテンプレートに差分の要点を埋める。**要約は差分から機械的に列挙するのではなく、
「何を・なぜ」を1〜3行で述べる**。変更点は主要な追加/変更/削除を箇条書きにする。

```markdown
## 概要

<何を・なぜ。1〜3 行>

Closes #<ISSUE>

## 変更点

- <主な変更1>
- <主な変更2>

## 確認

- [ ] `npm run lint:md` / `npm run docs:build` が通る（該当する場合）
- [ ] <その変更特有の確認>
```

- マージ時に Issue を閉じたくない場合は `Closes` ではなく `Refs #<ISSUE>` を使う。
- 末尾に本リポジトリの規約どおり生成署名（`🤖 Generated with Claude Code`）を付す。

### 3. 反映

- **提示のみ（既定）**: 本文案を提示して終わり。ユーザーが自分で貼れる。
- **PR 作成**: `gh pr create --base <base> --body "<本文>"`。作成後 `gh pr view --json closingIssuesReferences` で
  Issue 連動を検証する（空なら closing keyword を見直し `gh pr edit --body` で修正）。
- **既存 PR 更新**: `gh pr edit <PR> --body "<本文>"`。

## 注意

- PR 作成・本文編集は outward-facing。本リポジトリの方針では push / PR 作成は事前確認不要だが、
  他リポジトリで使う場合はその場の運用に合わせる。
- `Closes #N` は連動 Issue が**その PR で完結する**場合のみ。部分対応なら `Refs #N` にして Issue を残す。
- 連動 Issue の推定に自信が持てないときは閉じずに確認する（誤クローズ防止）。
