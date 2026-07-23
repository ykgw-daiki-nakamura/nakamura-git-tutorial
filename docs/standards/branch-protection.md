---
outline: [2, 3]
---

# ブランチ保護

ブランチとタグの保護設定、および bypass 権限の方針を定める。ブランチ体系は[ブランチ運用](./branching)、マージ方式と PR タイトルの規約は[マージルールと PR タイトル規約](./merge-rules)を参照。全体像は[概要](./)を参照。

## このページの要点

- 保護は Repository Rulesets で設定する。`main` と `release/*` には同じルールセットを適用する。
- タグ `v*` は作成できる主体を限定し、更新・削除は全員に禁じる。
- bypass 権限は恒常的に付与しない。緊急時も規約で定めた緊急手順で対応する。

保護設定は従来の branch protection ではなく **Repository Rulesets** で行う（ブランチとタグの保護、および bypass 権限の管理を一元化できるため）。

## `main` に適用するルール

| ルール | 設定 | 意図 |
| --- | --- | --- |
| Restrict direct pushes（PR 必須） | 有効 | すべての変更を PR 経由に強制する |
| Required approvals | 1 名以上 | レビューの担保 |
| Dismiss stale approvals on push | 有効 | 承認後の追加 push で承認を無効化し、未レビューコードの混入を防ぐ |
| Required status checks | lint / 型チェック / テスト / ビルド | CI 成功をマージ条件とする。Require branches to be up to date を有効化（頻度が高くなった場合は merge queue の導入を検討） |
| Require conversation resolution | 有効 | 指摘の放置マージを防ぐ |
| Require linear history | 有効 | squash merge 運用と整合させ、履歴を 1 PR = 1 コミットに保つ |
| Block force pushes / deletions | 有効 | 履歴改変・ブランチ消失の防止 |
| CODEOWNERS review | 有効（対象: DB マイグレーション、IaC、`.github/workflows/`） | 影響の大きい変更にドメイン責任者のレビューを必須化する。特にリリースワークフロー自体の変更はリリース責任者のレビューを必須とする |

## `release/*` に適用するルール

- `main` と同一のルールセットを適用する。
- 加えて、ブランチの**作成をリリース責任者（またはリリースワークフロー）に限定**する（creation restriction）。
- release ブランチへの PR は原則 cherry-pick PR のみとし、PR テンプレートで元 PR（main 側）へのリンクを必須項目とする。
- **例外**: 該当コードが `main` に存在しない場合（リファクタリング・削除済みで、そのバグが `main` には無い）に限り、`release/*` への直接 PR を認める。この場合は cherry-pick 元が存在しないため、次の 2 点を課す。
  - PR 本文に「`main` に該当コードが無い理由」と「`main` 側で同じ不具合が再発しないことの根拠」を明記する。
  - リリース責任者の承認を必須とする。

  upstream first の目的は `main` への取り込み漏れを防ぐことにある。取り込むべきコードが `main` に無いケースは、その目的の対象外である。

## タグ `v*` に適用するルール

- 作成: Ruleset の許可アクター（actor allowlist）を **リリース責任者ロール** と **リリース用 GitHub App** の 2 者に限定する。これは bypass ではなく正規の許可であり、「Bypass 権限の方針」の対象外である。
- 更新・削除: 全員禁止（bypass 対象なし）。公開済みバージョンは誰も改変できない。

タグ push はリリースワークフローの起動トリガーであるため、**そのワークフロー自身が最初のタグを打つことはできない**。誰がタグを作るかは次のとおり使い分ける。

| タグを打つ主体 | 手段 | 用途 |
| --- | --- | --- |
| リリース責任者ロール（人間） | ローカルまたは GitHub UI からタグを push | 通常の RC / GA。押下者が監査ログに残る |
| リリース用 GitHub App | `workflow_dispatch` で起動したワークフローが App トークンでタグを作成 | タグ付けを含めて自動化したい場合。起動者が監査ログに残る |

- GitHub App を用いる場合、**タグ作成に `GITHUB_TOKEN` を使わない**。`GITHUB_TOKEN` が作成したタグ・Release は他のワークフローを起動しないため、後続のビルド・昇格ワークフローが動かない。App のインストールトークンか専用の PAT を用いる。
- いずれの経路でも、タグが指すコミットは `release/vX.Y` 上になければならない。ワークフロー側で検証し、満たさない場合は失敗させる。

## Bypass 権限の方針

- 組織管理者を含め、bypass list への恒常的な登録は行わない。緊急時は bypass ではなく、規約で定めた緊急手順（[障害対応](./incident#ホットフィックス手順)の緊急パッチ: RC タグは打ち、staging 検証のみ省略する）で対応する。
- bypass が発生した場合（監査ログで検知）は、事後レビューを必須とする。
