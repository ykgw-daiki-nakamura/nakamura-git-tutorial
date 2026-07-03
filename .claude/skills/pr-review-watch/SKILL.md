---
name: pr-review-watch
description: >-
  リポジトリに新しく作成された Pull Request を一定間隔で監視し、検知したら diff を取得して
  レビューし、結果を PR コメントとして投稿する自走ループ skill。Dependabot 等のボットが
  作成した PR は既定で対象外。「新しい PR が来たらレビューして」「PR 作成を監視して」等で使う。
  Watch for newly created PRs, review the diff, and post the review as a PR comment (bots excluded).
---

# pr-review-watch — 新規 PR 監視・自動レビュー

リポジトリに **新しく作成された PR** を自走で監視し、検知したらレビューして結果を
PR コメントに投稿する skill。ScheduleWakeup で一定間隔ごとに自分を再起動して監視を継続する。

自分の 1 つの PR に付いたレビューコメントへ対応する用途は [pr-watch](../pr-watch/SKILL.md) を使う。
本 skill は「他者・自分が新規に立てた PR を検知してレビューする側」を担当する。

## 引数

`args` は自由記述。以下を読み取る（省略時は既定値）。

- **監視間隔** — 例 `5m` / `90s`。省略時は約 `270s`。ScheduleWakeup は 60〜3600 秒に丸められる。
  外部状態（GitHub）のポーリングなので、プロンプトキャッシュ（TTL 5 分）を温存できる 270 秒前後が既定。
- **除外対象** — 既定で **ボット全般**（`author.is_bot == true`。Dependabot・Renovate 等）。
  特定ボットだけ通したい場合は login 単位で個別指定する。
- **自作 PR の扱い** — 自分が作成した PR も既定で **対象に含める**（レビュー対象からは外さない）。
- **投稿方針** — `自動投稿` か `確認してから投稿` か。既定は **自動投稿**（検知した新規 PR のレビュー結果を確認なしで PR コメントに投稿する）。慎重に進めたい場合は `確認してから投稿` を明示指定する。
- **対象ラベル/ベースブランチ** — 例 `base:main`。指定時は絞り込む。

## 手順

### 1. 起動時（初回のみ）: ベースライン確立

現在オープンな PR の最大番号を控え、「これ以降に作成された PR」だけを対象にする。

```bash
gh pr list --state open --json number \
  --jq '[.[].number] | max // 0'   # 現在の最大 PR 番号 = ベースライン（0 件なら 0）
```

- ベースライン番号・監視間隔・除外対象・投稿方針を ScheduleWakeup の `prompt` 本文に埋め込み、
  次回起動時の自分へ引き継ぐ（ループの状態保持）。
- 既存のオープン PR は原則スキャン対象外（ユーザーが「既存の #N も見て」と言えばその番号は対象に含める）。

### 2. 毎回: 新規 PR を検知

```bash
gh pr list --state open --json number,title,author,createdAt \
  --jq 'sort_by(.number) | .[]
        | select(.number > <BASELINE>)
        | select(.author.is_bot == false)
        | "\(.number)\t\(.author.login)\t\(.title)"'
```

- **該当なし** → 1 行で「新規なし」と報告し、`delaySeconds`＝指定間隔で ScheduleWakeup を再スケジュールして継続。
- **新規 PR あり** → 各 PR について下記「レビュー」を実行。処理後、ベースラインを検知した最大番号に更新。

### 3. レビュー

各対象 PR について:

```bash
gh pr view <PR> --json number,title,body,baseRefName,additions,deletions,changedFiles,author
gh pr diff <PR>
```

- diff を読み、必要なら関連ファイル全体を Read して文脈を確認する。
- **観点**: 正誤・バグ、設計/意図との整合、セキュリティ、保守性、影響範囲、規約（Conventional Commits 等）。
- 総評（Approve 相当 / 要修正 / 要議論）と、良い点・修正必須点・提案（ブロッカー可否を明記）を簡潔にまとめる。
- コードを **変更・push はしない**。本 skill はレビューに徹する（修正対応は [pr-watch](../pr-watch/SKILL.md)）。

### 4. 投稿

投稿方針に従う。

- **自動投稿**（既定）: レビュー結果を確認なしでそのまま PR コメントに投稿する。投稿後に内容を会話へ 1 行で報告する。
- **確認してから投稿**: レビュー結果を会話に提示し、投稿してよいかユーザーに確認。承認後に投稿。

**署名は必須**。レビューが Claude によるものと分かるよう、コメント末尾に署名行を必ず付ける。

```bash
gh pr comment <PR> --body "$(cat <<'BODY'
## レビュー結果: ...
...

---
🤖 **Claude** によるレビュー（Claude Code / Opus 4.8・自動レビュー skill `pr-review-watch`）
BODY
)"
```

既定は自動投稿。ユーザーが「確認してから」と指定した間は必ず確認を挟み、承認後に投稿する。
「以降は自動で」と言われたら（あるいは既定のまま進める場合は）投稿方針 `自動投稿` として確認なしで投稿する。

### 5. 継続 / 終了

- レビュー・投稿後もループは継続（ベースライン更新済み）。ScheduleWakeup を再スケジュール。
- ユーザーが「止めて」と言ったら ScheduleWakeup を呼ばず終了する。

## 注意

- PR コメント投稿は outward-facing。既定は自動投稿だが、ユーザーが「確認してから」と指定した間は自動投稿しない。
- ポーリング対象は GitHub の外部状態で harness からの自動通知が無いため、
  ScheduleWakeup による能動的な再確認が必要。Monitor では捕捉できない。
- 間隔は 270 秒前後を既定とする。60 秒級の短間隔はレスポンス重視だが idle tick が増える。
  5 分（300 秒）ちょうどはキャッシュを外しつつ待ちも短い最悪値なので避ける。
- ベースライン・投稿方針・除外対象は毎回 ScheduleWakeup の `prompt` に埋めて引き継ぐ。
