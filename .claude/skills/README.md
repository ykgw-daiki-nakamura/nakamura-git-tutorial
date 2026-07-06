# .claude/skills — 補助 skill 一覧と役割

このリポジトリの作業を補助する skill をまとめる。各 skill は「いつ使うか」が重ならないよう
役割で棲み分けている。詳細は各 `SKILL.md` を参照。

## 一覧

| skill | 立ち位置 | いつ使う | 主な出力・副作用 |
| --- | --- | --- | --- |
| [plan](plan/SKILL.md) | **計画する** | 調査して計画を立て Issue にしておきたい（実装はまだしない） | plan.md 準拠の Issue を作成（**Issue 作成で止める**・実装しない） |
| [worktree-task](worktree-task/SKILL.md) | **作業する** | 隔離環境で変更を実装し PR まで出したい | 計画 Issue・worktree・ブランチ・PR を作成 |
| [pr-watch](pr-watch/SKILL.md) | **自分の PR を追う** | 出した 1 つの PR を監視し、レビュー対応とマージ後処理をしたい | レビュー指摘への修正 push・連動 Issue の自動クローズ検証 |
| [pr-review-watch](pr-review-watch/SKILL.md) | **PR をレビューする** | 新規に立った PR を検知してレビューを投稿したい | PR への**レビューコメント投稿**（Bot の PR は既定で対象外） |
| [pr-desc](pr-desc/SKILL.md) | **PR 説明を書く** | 差分と連動 Issue から `Closes #N` 付き PR 本文を生成したい | PR 説明文の生成・提示（任意で PR 作成／更新） |

## PR 監視 2 種の棲み分け

`pr-watch` と `pr-review-watch` はどちらも ScheduleWakeup による自走監視ループだが、
**監視の主体と目的が逆**なので用途は重ならない。

- **pr-watch = 出した側**。対象は「自分の 1 つの PR」。レビュー指摘を直し、マージされたら
  連動 Issue の自動クローズを検証して終了する。
- **pr-review-watch = レビューする側**。対象は「新しく立った PR（複数を検知）」。diff を読んで
  レビューコメントを投稿する。修正はしない。

迷ったら「**自分が直す側か（pr-watch）／他人の変更を見る側か（pr-review-watch）**」で選ぶ。

## 典型的な組み合わせ

```text
plan で調査・計画 → plan.md 準拠の Issue を作成（ここで止める）
        │
        └→ worktree-task <Issue> で実装 → PR 作成
                │
                └─（その PR を自分で追う）→ pr-watch で監視・レビュー対応・マージ後処理

pr-review-watch は独立して常駐し、新規 PR を検知してレビューを投稿する
```

計画立案の正典は `plan` にあり、**`plan` は plan.md 準拠の Issue を作って止める**（実装しない）。
`worktree-task` は計画立案を `plan` に委譲し（既存の計画 Issue があればそれを使う）、その Issue を
起点に **着手ラベル付与 → ブランチ → 実装 → PR** まで進む。「計画だけ固めたい」なら `plan`、
「計画済み Issue を実装まで持っていきたい」なら `worktree-task` を入り口にする。
`worktree-task` は「（plan で）Issue 化 → ブランチ → PR リンク」を手順として踏み外さないための既定経路。
コミットを伴う作業は原則これを入り口にすると、`pr-watch` へそのまま監視を引き継げる
（PR 作成を検知して自動移行するフックも導入済み）。
