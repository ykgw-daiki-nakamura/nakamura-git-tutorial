# nakamura-git-tutorial

Git / GitHub を**チーム開発で実践的に使いこなす**ための、図解付きチュートリアルサイトです。[VitePress](https://vitepress.dev/) で構築し、Mermaid によるダイアグラムで概念を視覚的に解説しています。

🔗 **公開サイト**: https://ykgw-daiki-nakamura.github.io/nakamura-git-tutorial/

## 扱う内容

- **はじめに・基礎** — セットアップ、Git の 3 領域、基本コマンド
- **チーム開発** — ブランチ戦略、リモート操作、GitHub Flow、プルリクエストとレビュー、コンフリクト解決、rebase、CI 連携
- **付録** — コマンド早見表、トラブルシューティング

## ローカルで動かす

前提: [Node.js](https://nodejs.org/) 18 以上。

```bash
# 依存をインストール
npm install

# 開発サーバーを起動（http://localhost:5173/）
npm run docs:dev

# 本番ビルド
npm run docs:build

# ビルド結果をプレビュー
npm run docs:preview
```

## ディレクトリ構成

```
docs/
├─ .vitepress/
│  └─ config.mjs       # サイト設定（nav / sidebar / Mermaid）
├─ guide/              # チュートリアル本文（Markdown）
└─ index.md            # トップページ
.github/workflows/     # CI（PR ビルド検証）と Pages デプロイ
```

## デプロイ

`main` への push をトリガーに [GitHub Actions](.github/workflows/deploy.yml) が自動でビルドし、GitHub Pages へ公開します。

## コントリビュート

改善・修正は歓迎します。手順は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## ライセンス

[MIT License](LICENSE) © 2026 Daiki Nakamura
