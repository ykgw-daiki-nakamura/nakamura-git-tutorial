---
name: pr-watch
description: >-
  自分が出した Pull Request を一定間隔で監視し、(1) レビューコメントが付いたら修正案を作成して
  push 前に確認を取り、(2) マージ/クローズされたら連動 Issue（PR 本文の closing keywords で
  GitHub が自動クローズ）の状況を検証して監視を終了する。
  「PR を監視して」「レビューが付いたら直して」「マージされたら連動 Issue の自動クローズを確認して」等の依頼で使う。
  PR watch loop: poll a PR, fix review comments (confirm before push), verify auto-closed linked issues on merge.
---

# pr-watch — Pull Request 監視ループ

自分の PR を自走監視し、レビュー対応とマージ後処理を行う skill。
ScheduleWakeup で一定間隔（既定 60 秒）ごとに自分を再起動して監視を継続する。

本 skill は「**自分が出した 1 つの PR を追う側**」を担当する。逆に、新規に立った PR を検知して
レビューを投稿する「レビューする側」は [pr-review-watch](../pr-review-watch/SKILL.md) を使う。
PR を作るところから始めたい場合は [worktree-task](../worktree-task/SKILL.md) で PR を作成し、
その PR をそのまま本 skill で監視する、という流れになる。各 skill の棲み分けは
[skills の一覧](../README.md) を参照。

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
- **レビュー元は Copilot だけではない。** 人間・Copilot に加え、自動レビュー skill [pr-review-watch](../pr-review-watch/SKILL.md) が
  **`gh` を実行する認証ユーザー名義で**投稿する（その名義が誰かは環境依存で、Copilot のようなボット名では来ない）。
  投稿者名だけでは自動レビューか人間かを区別できないため、**投稿者を問わず全レビューを対象**にする
  （`user.login == "Copilot"` だけで絞り込まない）。
- **inline（`.../pulls/<PR>/comments`）だけでなく issue-level のレビュー本文（`reviews` / `comments`）も確認する。**
  pr-review-watch は Reviews API（`event=COMMENT`）で**総評（本文）＋インライン**を投稿し、本文冒頭の
  `## レビュー結果: …` 見出しで **Approve 相当 / 要修正 / 要議論** を示す。本文側を見ないと要対応を取りこぼす。
- **単なる概要・Approve 相当・非アクションな賛辞は対応不要**として扱う（既読に含める）。要対応（要修正・変更要求）は
  **投稿者に依らず**対応する。
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
`gh pr edit`（PR 本文編集）は影響が大きいので、**実行前にユーザー確認を挟む**
（軽微なレビュー修正の push は確認不要だが、PR 本文編集はこれと別扱い）。

### 3. レビュー対応（軽微な修正は自動 push）

1. 新規コメントの指摘内容を要約する。**投稿者を問わず**（人間 / Copilot / pr-review-watch）
   実質的な変更要求・要修正を対象にする。概要・Approve 相当・非アクションな賛辞は無視。
2. 作業ツリー（worktree があればその中）で該当ファイルを修正する。
3. **軽微な修正は事前確認なしで自動で進める。** 軽微とは lint / typo / 表現統一・用語ゆれ /
   小さな記述修正 / レビューアの明確な指摘に沿う機械的修正など。
   - Conventional Commits 準拠でコミット → `git push` → 対応内容を**指摘元に応じて返信**
     （下記「3a. 返信」）、までを確認待ちせず実行する。
   - `git diff` は**事後に提示（報告）**する（push 前の許可待ちはしない）。これは本リポジトリ
     オーナーの運用方針（確認の往復を減らして自走させる）。
4. **確認を挟むのは「設計変更を伴う」「判断に迷う（要求が曖昧・複数解がある）」指摘のみ。**
   その場合は自動修正せず、要約して指示を仰ぐ。

### 3a. 返信（インライン指摘はスレッド返信を既定とする）

指摘の**出どころ**で返信手段を必ず使い分ける（取り違えない）。

- **インラインレビューコメント**（diff の行に紐づく指摘。`GET /repos/{owner}/{repo}/pulls/<PR>/comments`
  で取得できるもの）→ **必ず指摘元スレッドへ返信する**。トップレベルの `gh pr comment` で代用しない。

  ```bash
  gh api repos/{owner}/{repo}/pulls/<PR>/comments/<comment_id>/replies -f body="…"
  ```

  `<comment_id>` は返信先インラインコメントの `id`。1 指摘＝1 スレッド返信にすると、どの指摘に
  どう対応したかがスレッド上で 1:1 に追え、レビュアー（人／Copilot／`pr-review-watch`）が
  解決状況を把握しやすい。返信が紐づいたかは応答／再取得で `in_reply_to_id` が当該 `id` を
  指すことで確認できる。
- **イシューレベルのレビュー**（行に紐づかない総評・まとめ。`pr-review-watch` のサマリコメントや
  `gh pr view <PR> --json comments,reviews` 側）→ 従来どおり `gh pr comment <PR> --body "…"` で返信する。
- **対応不要と判断した指摘**（非アクションな概要・賛辞・Copilot の要約など）には返信しなくてよい。

返信本文には必ず **(1) 対応内容の要約 (2) 修正コミットの SHA (3) 末尾の署名** を含める。

**未返信の検出（既読管理）**: インラインコメントのうち `in_reply_to_id == null`（＝トップレベルの指摘）
を対象に、**自分（認証ユーザー）の返信**が無いものを「未返信」として洗い出す。判定は
「`in_reply_to_id` が当該 `id` を指す」だけでなく、**その返信の `user.login` が自分**であることも
条件に含める（他者・レビュアーの返信を「対応済み」と誤判定しないため）。認証ユーザーは
`gh api user -q .login` で得る。一覧取得は**既定で 1 ページ（30 件）**しか返らないため、
コメントが多い PR での取りこぼしを防ぐよう **`--paginate` で全件走査**する:

```bash
me=$(gh api user -q .login)
# 自分（$me）が未返信のトップレベル指摘（id / path / line）を洗い出す
gh api --paginate repos/{owner}/{repo}/pulls/<PR>/comments --jq '.[]' \
  | jq -s --arg me "$me" '
      (map(select(.in_reply_to_id and .user.login == $me) | .in_reply_to_id)) as $replied
      | map(select(.in_reply_to_id == null and ((.id) as $i | $replied | index($i) | not)))
      | .[] | {id, path, line}'
```

`owner`/`repo` は `gh repo view --json owner,name -q '.owner.login+"/"+.name'` で得る。

**署名**: PR に投稿するコメント／返信（インライン・イシューレベルとも）の本文末尾には、認証アカウントとは
別に Claude による対応であることを示す署名を必ず付ける。
`gh` はユーザーのトークンで投稿するため投稿者名は区別できない（本文で明示する）。

```text

— 🤖 Claude Code による対応
```

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
3. 修正した場合は「レビュー対応」と同様に扱う。lint / build / test の**機械的修正は確認なしで
   commit / push** し、`git diff` は事後に提示する。原因が設計変更に及ぶ・判断に迷う場合のみ確認する。
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

- **軽微なレビュー修正の push・PR コメント返信は事前確認不要**（本リポジトリオーナーの方針）。
  diff は事後報告でよい。確認を挟むのは「設計変更を伴う／判断に迷う」修正のみ。
- 一方で **マージ／Issue クローズ／`git push --force` 等の破壊的・取り消しにくい操作は従来どおり確認**する。
  未マージ CLOSED の Issue 操作、PR 本文編集（`gh pr edit`）も確認を挟む。
- 監視は自走ループ。ユーザーが「止めて」と言ったら ScheduleWakeup を呼ばず終了する。
- ポーリングは GitHub の外部状態が対象で harness からの自動通知が無いため、
  ScheduleWakeup による能動的な再確認が必要。
