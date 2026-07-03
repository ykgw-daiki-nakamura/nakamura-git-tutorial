# ADR 0001: PR 作成後の pr-watch 自動移行はフックで実装する

- ステータス: Accepted
- 日付: 2026-07-03
- 関連: Issue #40 / PR #41 / [.claude/hooks/pr-watch-handoff.sh](../.claude/hooks/pr-watch-handoff.sh) / [.claude/settings.json](../.claude/settings.json)

## コンテキスト

`gh pr create` で PR を出した後は、レビュー指摘への対応やマージ後の連動 Issue
検証を担う `pr-watch` skill へ移行したい。この「PR 作成 → pr-watch」の移行を、
人手を介さず **確実に自動化** する手段を決める必要がある。

Claude Code で自動的な振る舞いを持たせる方法は主に 3 つあり、それぞれ「誰が
実行するか」が異なる。

- **フック**: ハーネス（Claude の外）がイベント発生時に必ず実行する。
- **skill 連携**: PR を作る skill（例: worktree-task）の手順末尾に移行手順を追記。
  その skill を実行しているときだけ効く。
- **メモリ**: `feedback` メモリとして記録。イベント駆動ではなく背景コンテキストとして
  想起され、Claude が判断して従う（＝自動保証はない）。

## 決定

**PostToolUse フック**（`matcher: "Bash"`）で実装する。

- `gh pr create` の成功（`tool_response` に PR URL）を検知したら、
  `hookSpecificOutput.additionalContext` に「pr-watch へ移行せよ」を注入する。
- フック本体は `.claude/hooks/pr-watch-handoff.sh`。既存の `markdownlint.sh` に倣い、
  `jq` 優先・`node` フォールバックで JSON を安全に組み立てる（`printf` の生埋め込みは
  エスケープ漏れで壊れるため使わない）。
- `settings.json` 側は `if: "Bash(gh pr create*)"` で無関係な Bash 実行への起動を抑止し、
  引数なしの `gh pr create` でも取りこぼさないようにする。

## 検討した代替案

### skill 連携

worktree-task 等の SKILL.md に移行手順を書く案。文脈を手順として自然に書けるが、
**その skill 経由の PR 作成にしか適用されない**。素の `gh pr create` を取りこぼす。

### メモリ

`feedback` メモリに「PR 作成後は pr-watch へ」と記録する案。軽量だが
**イベント駆動でなく想起頼み**で、毎回確実には発火しない。個人ローカル保存のため
チーム共有もされない。

## 結果

### 良い点

- ハーネス保証で **手段を問わず確実に発火**（skill 経由でも手打ちでも）。
- `.claude/settings.json` として git 管理され、**チーム全員に共有**される。

### 留意点・トレードオフ

- フックはあくまで「移行指示の注入」であり、pr-watch を起動するのは Claude 側。
- イベントとコマンドのマッピング（誤発火/取りこぼしの境界）を設計する必要がある。
- 設定変更後はハーネス側の再読込が要る場合がある。
- 3 手段は排他ではなく、必要なら skill 連携・メモリと **併用** して補強できる。
