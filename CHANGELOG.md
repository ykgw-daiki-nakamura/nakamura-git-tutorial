# Changelog

このプロジェクトの主な変更点を記録します。書式は [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に、
バージョニングは [セマンティックバージョニング](https://semver.org/lang/ja/) に従います。

> **教材としての位置づけ**: このファイルは [リリースとバージョン管理](docs/guide/release.md) で学ぶ
> CHANGELOG・SemVer の**実例**です。PR をマージしたら、変更を下の `[Unreleased]` に 1 行追記し、
> リリース時にバージョン見出しへ繰り上げます。

## [Unreleased]

_次のリリースに向けた変更をここに追記する。_

## [1.0.0] - 2026-07-03

チーム開発向け Git / GitHub チュートリアルサイトの初回リリース。

### Added

- ガイド本文（はじめに・基礎・ブランチ・リモート・GitHub Flow・プルリクエスト・コンフリクト・rebase・CI ほか）と実習（ハンズオン）コンテンツ一式。
- リリース／バージョン管理、複数バージョンの並行保守（リリースブランチ）、顧客カスタマイズ、デュアル配布（SaaS + セルフホスト）などの発展ガイド。
- Git Flow / GitLab Flow の解説と使い分け判断ガイド、ブランチ更新の merge/rebase 選択ガイド。
- サイト機能: ローカル全文検索、`editLink`、`lastUpdated`、OGP メタ、Mermaid ダイアグラム対応。
- CI/CD: VitePress ビルド・markdownlint・dependency-review の PR チェック、GitHub Pages 自動デプロイ、外部リンクの週次検査。
- `package.json` に `engines.node >=20` を追加し、対応 Node バージョンを明記。
- エージェント向けハーネス: `CLAUDE.md`、補助 skill（worktree-task / pr-watch / pr-review-watch / commit）、`checks.json` 駆動の編集後チェック、コミット衛生ガード、Issue / PR テンプレート。

### Changed

- ガイドを体系的に再編（サイドバーの 6 グループ化・学習ロードマップ・相互リンク整備）。
- Node.js のバージョン表記をドキュメント全体で CI（Node 20）に統一。

### Fixed

- lychee による内部リンクの誤検出を解消（検査対象を http/https に限定）。
- VitePress ビルド時の chunk size 警告を解消。
- Git Flow の hotfix 図に、既存 `develop` ブランチであることを示す注釈を追加。

[Unreleased]: https://github.com/ykgw-daiki-nakamura/nakamura-git-tutorial/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ykgw-daiki-nakamura/nakamura-git-tutorial/releases/tag/v1.0.0
