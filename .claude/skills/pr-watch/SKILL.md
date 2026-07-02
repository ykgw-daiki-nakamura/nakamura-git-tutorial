---
name: pr-watch
description: >-
  自分が出した Pull Request を一定間隔で監視し、(1) レビューコメントが付いたら修正案を作成して
  push 前に確認を取り、(2) マージ/クローズされたら連動 Issue（PR 本文の closing keywords で
  GitHub が自動クローズ）の状況を検証して監視を終了する。
  「PR を監視して」「レビューが付いたら直して」「マージされたら Issue を閉じて」等の依頼で使う。
  PR watch loop: poll a PR, fix review comments (confirm before push), verify auto-closed linked issues on merge.
---

# pr-watch — Pull Request 監視ループ

自分の PR を自走監視し、レビュー対応とマージ後処理を行う skill。
ScheduleWakeup で一定間隔（既定 60 秒）ごとに自分を再起動して監視を継続する。

## 引数

`args` は自由記述。以下を読み取る（省略時は既定値）。

- **PR 番号** — 例 `15`。省略時は現在のブランチに紐づく PR を `gh pr view --json number` で解決する。
- **間隔** — 例 `2m` / `90s`。省略時は `60s`。ScheduleWakeup は 60〜3600 秒に丸められる。
- **クローズ対象 Issue** — 例 `#11 #12 #13`。関連 Issue は原則 **PR 本文に closing keywords（`Closes #N` / `Fixes #N` 等）を記載**し、GitHub のネイティブ機能でマージ時に自動クローズさせる（手動 `gh issue close` はしない）。`gh pr view <PR> --json closingIssuesReferences` で連動が効いているか検証できる。

## 手順

### 1. 起動時（初回のみ）: ベースライン確立

現在のコメント状況を取得し「既読」として記録する。以降はこれとの差分だけを扱う。

```bash
gh pr view <PR> --json state,mergedAt,closedAt,reviews,comments,closingIssuesReferences
gh api repos/{owner}/{repo}/pulls/<PR>/comments   # インラインレビューコメント
```

- 既存のレビュー・コメントの ID / submittedAt を控える。
- Copilot 等の**単なる概要・非アクションな賛辞は対応不要**として扱う（既読に含める）。
- 次回起動時に参照できるよう、ベースライン（PR番号・間隔・既読コメントID・クローズ対象Issue）を
  ScheduleWakeup の `prompt` 本文に埋め込んで自分へ引き継ぐ。

### 2. 毎回: 状態を確認して分岐

状態・レビュー・CI の3点を確認する。

```bash
gh pr view <PR> --json state,mergedAt,closedAt
gh pr checks <PR>   # CI/チェックの成否（pass/fail/pending）
```

**A. まだ OPEN で、新規の対応必要コメントが無く、CI がすべて成功（または実行中）**
→ 状況を1行で報告し、`delaySeconds`＝指定間隔で ScheduleWakeup を再スケジュールして継続。
（60 秒程度の短間隔は外部状態のポーリングとして適切。プロンプトキャッシュも温存される。）
CI が pending の間は「実行中」と報告して継続監視する。

**B. 新規の対応必要なレビューコメント/変更要求がある**
→ 下記「レビュー対応」を実行。処理済みコメントを既読に追加し、監視を継続。

**B'. CI（チェック）が失敗している**
→ 下記「CI 失敗対応」を実行。修正後も監視を継続する。

**C. マージ済み（`mergedAt` が非 null。`gh` の `state` は `MERGED` を返す）または CLOSED**
→ 下記「マージ/クローズ後処理」を実行し、監視を**終了**（ScheduleWakeup を呼ばない）。
判定は `mergedAt`（マージ）と `closedAt`/`state`（クローズ）で行う。

起動時に、関連 Issue が PR 本文の closing keywords で連動しているか
`gh pr view <PR> --json closingIssuesReferences` で確認し、抜けていれば
`gh pr edit <PR> --body ...` で `Closes #N` を追記しておく（マージ前に済ませる）。

### 3. レビュー対応（confirm before push）

1. 新規コメントの指摘内容を要約する。人間の指摘・実質的な変更要求のみ対象。
   Copilot の非アクションな概要は無視。
2. 作業ツリー（worktree があればその中）で該当ファイルを修正する。
3. `git diff` を提示し、**commit / push する前にユーザーへ確認を取る**。
   - 承認されたら: Conventional Commits 準拠でコミット → `git push` → 対応内容を
     `gh pr comment <PR>` または該当インラインコメントへ返信。
   - 却下・保留なら: 修正を保持したまま指示を待つ。
4. 判断に迷う指摘（設計変更を伴う等）は自動修正せず、要約して指示を仰ぐ。

### 3b. CI 失敗対応

1. 失敗したチェックを特定する。

   ```bash
   gh pr checks <PR>                       # どのチェックが fail か
   gh run view <run-id> --log-failed       # 失敗ジョブのログ（run-id は checks の URL / gh run list から）
   ```

2. 原因を切り分ける。
   - **自分の変更が原因**（lint/test/build 失敗など）→ 作業ツリーで修正する。
   - **一時障害/フレーキー**（ネットワーク・レート制限等）→ `gh run rerun <run-id> --failed` で再実行し、
     継続監視。何度も再発するなら原因調査へ。
3. 修正した場合は「レビュー対応」と同様に `git diff` を提示し、
   **push 前にユーザー確認**を取ってから commit / push する。
4. push 後は CI が再実行されるため、次回以降のループで結果を再確認する。

### 4. マージ/クローズ後処理

- **MERGED の場合** — closing keywords により関連 Issue は GitHub が**自動クローズ**する。
  手動ではクローズしない。`gh issue view <N> --json state` で実際に CLOSED になったか
  **検証のみ**行う。万一閉じ残りがあれば、手動クローズせずユーザーに報告して指示を仰ぐ。

  ```bash
  gh issue view <N> --json number,state -q '"#\(.number): \(.state)"'
  ```

- **CLOSED（未マージ）の場合** — PR が却下された可能性があるため Issue は自動クローズされない。
  Issue を触るべきか一度ユーザーに確認する。
- 監視終了をユーザーへ報告（PR の最終状態・Issue の連動結果を明記）。

## 注意

- push・PR コメント・Issue クローズは outward-facing。手順どおり、push は事前確認、
  未マージ CLOSED の Issue 操作も確認を挟む。
- 監視は自走ループ。ユーザーが「止めて」と言ったら ScheduleWakeup を呼ばず終了する。
- ポーリングは GitHub の外部状態が対象で harness からの自動通知が無いため、
  ScheduleWakeup による能動的な再確認が必要。
