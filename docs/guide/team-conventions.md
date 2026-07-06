# 私たちの開発規約

このリポジトリ自体が **GitHub Flow の教材**であり、運用も GitHub Flow に揃えています。このページは、一般的なブランチ戦略（[ブランチ戦略の使い分け](./branching-strategies) などの**リファレンス**）に対して、**本リポジトリ固有の決め事（convention）**をまとめた single source of truth です。エージェント向けの実行仕様は `CLAUDE.md` にありますが、ここは**人間の読者向け**にその決め事を公開します。

## 土台は GitHub Flow

- `main` は常にデプロイ可能な状態に保つ（`main` に入ったものは [GitHub Pages へ継続デプロイ](./release)される）。
- 作業は**短命な作業ブランチ**で行い、**Pull Request 経由でのみ** `main` にマージする。
- 直接 `main` にコミット／プッシュしない。

## ブランチの命名規則

作業ブランチは **Conventional Commits の type と同じ接頭辞**で切ります。コミットの type とブランチの接頭辞を揃えることで、履歴と作業単位が一目で対応します。

| 接頭辞 | 用途 |
| --- | --- |
| `feat/` | 機能追加 |
| `fix/` | バグ修正 |
| `docs/` | ドキュメント |
| `chore/` | 雑務・設定 |
| `ci/` | CI/ワークフロー |

例: `docs/branching-guide`、`fix/broken-link`。

::: tip 他戦略の命名は採り入れない
**Microsoft Release Flow** の `feature/…` や `users/<名前>/…`、Git Flow の `develop` などは**採用しません**。本リポジトリは上記の type 接頭辞に一本化します。
:::

## コミットメッセージ（Conventional Commits）

`type(scope): summary` 形式に従います（`type` は上表と同じ）。要約は簡潔に。詳しくは [Git の基本](./basics) を参照。

```text
docs(guide): ブランチ命名規則の例を追加
```

## Issue 先行と進行の可視化

- **着手前に計画を GitHub Issue にまとめる**（目的・スコープ・作業計画・完了条件）。数行の修正でも例外にしない。
- 着手したら Issue に `status: in-progress` ラベルを付け、自分をアサインする（二重着手を防ぐ）。

## Pull Request

- PR 本文に **`Closes #<Issue>`** を書いて連動 Issue にリンクする（マージ時に自動クローズ）。
- **1 PR はおよそ 400 行を目安**にし、超えそうなら Issue／PR を分割する。
- 提出前に **`npm run docs:build` / `npm run lint:md` / `npm run lint:text`** を通す。

### main のブランチ保護

- GitHub 側で **PR 必須・CI グリーン必須・直接 push 禁止**を設定している。
- ローカルでも `guard-branch.sh`（PreToolUse フック）が保護ブランチへの直接コミット／プッシュを止める。
- **レビュアーは 2 人が最適**という [Microsoft のガイダンス](https://learn.microsoft.com/ja-jp/azure/devops/repos/git/git-branching-guidance) を目安に置く（強制ではなく推奨）。

## リリースはタグ主軸

本リポジトリは継続デプロイ（`main` → Pages）で、リリースは [タグ（＋ GitHub Release）を主軸](./release)にします。**Microsoft Release Flow** の「リリースにタグを使わない」立場は**採用しません**。

## 環境ブランチは将来の選択肢

継続デプロイの単一サイトなので、環境ブランチは**現状不要**です。もし複数環境の昇格運用（検証→本番など）が必要になったら、`deploy/<環境>` ブランチを**リリースブランチと同じ要領（main-first + cherry-pick）**で扱います。考え方は [GitLab Flow](./gitlab-flow) の環境ブランチや **Microsoft Release Flow** の `deploy/<環境>` と同じです。

## 参照

- [ブランチ戦略の使い分け](./branching-strategies) — 一般的な戦略のリファレンス
- **Microsoft Release Flow** — 本規約が一部を参考にした型
- [リリースとバージョン管理](./release) — タグ主軸のリリース
- [複数バージョンの保守（リリースブランチ）](./release-branches) — main-first + cherry-pick の鉄則
