# CLAUDE.md

このリポジトリで作業するエージェント／コントリビューター向けのガイドです。

## プロジェクト概要

Git / GitHub を**チーム開発で実践的に使いこなす**ための、図解付きチュートリアルサイトです。

- **技術スタック**: [VitePress](https://vitepress.dev/)（静的サイト）、Mermaid（ダイアグラム）、Node.js 18 以上、npm
- **コンテンツ言語**: 日本語
- **公開先**: GitHub Pages（<https://ykgw-daiki-nakamura.github.io/nakamura-git-tutorial/>）
- **性質**: このリポジトリ自体が **GitHub Flow の教材**であり、運用も GitHub Flow に揃えている

## コマンド

```bash
npm install          # 依存をインストール
npm run docs:dev     # 開発サーバー（既定 http://localhost:5173/）
npm run docs:build   # 本番ビルド（内部リンク切れ・Mermaid 構文エラーを検知）
npm run docs:preview # ビルド結果をプレビュー
npm run lint:md      # markdownlint-cli2 による Markdown 整形チェック
```

## ディレクトリ構成

```text
docs/
├─ .vitepress/config.mjs  # サイト設定（nav / sidebar / Mermaid）
├─ guide/                 # チュートリアル本文
├─ hands-on/              # 実習（ハンズオン）コンテンツ
├─ practice/              # 実習で編集する練習用ページ（サンドボックス）
└─ index.md               # トップページ
.github/workflows/        # CI（ci.yml）/ Pages デプロイ（deploy.yml）/ 外部リンク検査（links.yml）
```

## コンテンツ執筆の規約

- 本文は日本語で、`docs/guide/` または `docs/hands-on/` に Markdown で追加する。
- **新規ページを追加したら `docs/.vitepress/config.mjs` の `sidebar` にも登録する**（登録漏れに注意）。
- VitePress の内部リンクは**拡張子なし**で書く（例: `[ブランチ](./branching)`）。実ファイルは `.md`。
- 図は Mermaid のコードフェンス（` ```mermaid `）で記述する。日本語ラベルを含む複雑な図は `"..."` で囲むと崩れにくい。

## Markdown Lint（markdownlint-cli2）

設定は [.markdownlint-cli2.jsonc](.markdownlint-cli2.jsonc)。無効化済みルール以外は既定で有効。ハマりやすい点:

- **MD031**: コードフェンスの前後には空行が必要（過去に CI 失敗の原因になった）。
- 無効化済み: MD013（行長）、MD033（インライン HTML）、MD041（先頭 H1）、MD024 は同一階層のみ重複禁止。
- **Markdown を編集したら push 前に必ず `npm run lint:md` を通すこと**（CI の `lint` ジョブと同一）。

## 開発フロー（GitHub Flow）

1. **着手前に計画を GitHub Issue にまとめる。** 数行の docs 修正など些細な変更でも例外にしない。目的・スコープ・作業計画（チェックリスト）・完了条件を書く。既存の計画 Issue があればそれを使う。**着手したら Issue に `status: in-progress` ラベルを付与し自分をアサインする**（`gh issue edit <Issue> --add-label "status: in-progress" --add-assignee @me`）。一覧で着手中を判別でき、複数人／エージェントでの二重着手を防げる。
2. 最新の `main` からブランチを切る。接頭辞は `feat/` `fix/` `docs/` `chore/` `ci/`。
3. 変更してコミットする（下記のコミット規約）。
4. `git push -u origin <branch>` して Pull Request を作成する（テンプレートが自動挿入される）。**PR 本文に `Closes #<Issue>` を記載して連動 Issue にリンクする**（マージ時に GitHub が自動クローズ）。
5. CI が通り、レビューで承認されたらマージする。

> **エージェント補足**: コミットを伴う作業は原則 `.claude/skills/worktree-task` を既定経路にすると、この「Issue 化 → ブランチ → PR リンク」を手順として踏み外さない。行き当たりばったりで素手編集を始めない。

### コミットメッセージ（Conventional Commits）

`type(scope): summary` 形式に従う。`type` は `feat` `fix` `docs` `chore` `ci` など。要約は簡潔に。

```text
docs(guide): ブランチ命名規則の例を追加
```

### 提出前チェック

- [ ] `npm run docs:build` が通る（CI と同じ検証）
- [ ] `npm run lint:md` が通る
- [ ] 追加・変更ページのリンクが切れていない
- [ ] Mermaid 図がプレビューで正しく描画される

## CI / CD とセキュリティ方針

- **ci.yml**（PR 時）: `build`（VitePress ビルド）/ `lint`（markdownlint）/ `dependency-review`（依存の脆弱性検査）。
- **deploy.yml**: `main` への push で GitHub Pages へ自動デプロイ。
- **links.yml**: 週次で外部リンクの死活を検査（`--scheme http/https` で内部リンクは対象外）。
- **issue-label-cleanup.yml**: Issue クローズ時に `status: in-progress` ラベルを自動除去（`issues: write`）。
- **GitHub Actions は必ず commit SHA でピン留めし、`# vX.Y.Z` のバージョンコメントを添える**（Dependabot が更新）。
- ワークフローは**最小権限**（`permissions: contents: read` を既定）とし、`persist-credentials: false`、job には `timeout-minutes` を設定する。

## エージェント向けメモ

- ファイルを編集したら、対応するチェック（`lint:md` / `docs:build`）をローカルで実行してから push する。
- 破壊的・外向きの操作（push、PR 作成、マージ、Issue 操作）は方針に沿って慎重に行う。
- `.claude/skills/` に補助 skill がある。役割と棲み分け（worktree-task / pr-watch / pr-review-watch）は [.claude/skills/README.md](.claude/skills/README.md) を参照。
