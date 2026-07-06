---
name: plan
description: >-
  作業指示を受けたら、コードベースを調査して計画を立て、plan.md 準拠の GitHub Issue を作成する
  skill。**実装（ブランチ・コード・PR）には進まない**のが worktree-task との違いで、「計画だけ立てて
  止めたい」用途の入口を担う。前提（最新の origin/main の実態など）を検証してから計画し、規模が
  大きければ独立した Issue に分割する。作成した Issue は後で worktree-task が実装に着手する。
  「計画して」「Issue で計画して」「タスクを分解して Issue 化して（実装はまだしない）」等で使う。
  Investigate the codebase, draft a plan, and create a plan.md-style GitHub Issue — stopping before
  implementation (no branch/code/PR). Hand off to worktree-task for the actual work.
---

# plan — 調査して計画を立て、plan.md 準拠の Issue を作る（実装はしない）

作業指示を受けたら、**現物を調査して計画を立て、`.github/ISSUE_TEMPLATE/plan.md` 準拠の
GitHub Issue を作成する**ところまでを担う skill。**ブランチ・worktree・コード変更・PR は一切作らない。**
実装は `worktree-task` に引き継ぐ。

`worktree-task` も冒頭で計画を Issue 化するが、そのまま「ブランチ → PR」まで進む。`plan` は
**Issue 作成で止める**点が違い、「まず計画だけ固めたい」「タスクを分解して Issue にしておきたい」
用途に使う。

## 引数

`args` は自由記述。以下を読み取る（省略時は会話文脈から解決）。

- **タスク内容** — 何を計画するか。省略時は直近の会話の作業指示を対象にする。
- **既存 Issue** — 更新したい計画 Issue があればその番号（無ければ新規作成）。
- **分割方針** — 明示があれば従う。無ければ規模から判断し、案をユーザーに提示する。

## 手順

### 1. 要件把握

- 何を・なぜ・どこまで（スコープ）を掴む。**指示が曖昧なら着手前に確認する**（複数解がある、
  対象範囲が読み取れない、等）。ここで詰めておくと後続の計画がぶれない。

### 2. 実態調査（前提を検証する）

- 関連ファイルを読み、**計画を現物に基づかせる**。推測でなく実在の構成・命名・既存実装を確認する。
- **前提の検証を必須にする**。特に:
  - ローカル `main` は古いことがある。`git fetch` してから **`origin/main` の実態**（マージ済み
    の有無・最新の関連ファイル）を確認してから計画する。*古い main を前提に立てた計画が実態と
    ズレる事故を防ぐ。*
  - 関連 Issue / PR の有無を `gh issue list` / `gh pr list` で確認し、**重複や依存**を把握する。
- 広く読む必要があるときは Explore／サブエージェントに **fan-out** して調査を分担してよい。

### 3. 計画ドラフト

- [.github/ISSUE_TEMPLATE/plan.md](../../../.github/ISSUE_TEMPLATE/plan.md) の構成で起こす:
  **目的 / スコープ（含む・含まない）/ 作業計画（チェックリスト）/ 完了条件 / 依存・参考**。
- 「含まない」を明記して**スコープを締める**。完了条件は検証可能な形（コマンド・観測できる結果）で書く。
- ドラフトをユーザーに提示して**合意を取る**。

### 4. 規模見積りと分割

- 1 Issue ≒ 1 PR ≒ **約 400 行**を目安にする。超えるなら分割する。
- **関連が薄いものは親子にせず独立した Issue** にする（既定・ユーザーの明示的な好み）。
  強く関連し順序依存がある場合のみ、親 Issue＋タスクリスト（またはトラッキング Issue）にする。
- 分割案（各 Issue の狙い・依存関係）をユーザーに提示して合意する。

### 5. Issue 作成

- `gh issue create` で plan.md 準拠の本文を作る（既存 Issue を使う場合は `gh issue edit` で更新）。
- **ラベル**: `.claude/checks.json` の `issueLabels`（type→ラベル・領域ラベル）があればそれで決める。
  既存の `issue-label` skill があれば**それに委譲／踏襲**する。どちらも無ければ、内容から妥当な
  ラベル（例: `enhancement` / `bug` / `documentation` と領域ラベル）を付ける。ロジックと対応表を
  分離する既存方針に合わせ、**語彙は設定側（checks.json）を正**とする。
- **`status: in-progress` は付けない**。着手ラベルの付与は実装に入る `worktree-task` の責務。
  `plan` は「計画済み・未着手」の Issue を残す。

### 6. 停止して引き継ぎ

- **ブランチ・worktree・コード変更・PR は一切作らない。** 作成した Issue 番号を報告し、
  「実装は `worktree-task`（`worktree-task <Issue番号>` 等）で着手する」と明示して終える。

## worktree-task との棲み分け

- **plan** = 調査 → 計画 → **Issue 作成で止める**（実装しない）。
- **worktree-task** = （計画 Issue を用意し）**ブランチ → 実装 → PR** まで進む。着手時に
  `status: in-progress` を付与しアサインする。
- 典型フロー: `plan` で計画 Issue を用意 → 後で `worktree-task <Issue>` が実装に着手。
