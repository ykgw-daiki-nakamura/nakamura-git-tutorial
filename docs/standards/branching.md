---
outline: [2, 3]
---

# ブランチ運用

ブランチ体系（命名規則を含む）と、ブランチプロテクション・マージルールを定める。全体像は[概要](./)を参照。

## ブランチ体系

### ブランチ一覧

| ブランチ | 役割 | 寿命 | 作成元 | マージ先 |
| --- | --- | --- | --- | --- |
| `main` | 唯一の統合ブランチ。次期バージョンの開発ライン | 永続 | — | — |
| `feature/*` | 機能開発・改善 | 短命 | `main` | `main`（PR 経由） |
| `fix/*` | バグ修正 | 短命 | `main` | `main`（PR 経由） |
| `release/vX.Y` | バージョン X.Y の安定化・出荷・保守ライン（SaaS / セルフホスト共通） | サポート期間中 | `main` | マージしない（cherry-pick のみ受け入れる） |

### ブランチモデル全体像

```mermaid
gitGraph
  commit id: "feat A"
  branch feature/1234-tenant-flag-api
  commit id: "flag: 実装"
  commit id: "flag: レビュー反映"
  checkout main
  commit id: "feat B (squash)"
  branch release/v1.1
  commit id: "rc" tag: "v1.1.0-rc.1"
  commit id: "ga" tag: "v1.1.0"
  checkout main
  branch fix/1250-forecast-nan-handling
  commit id: "fix: NaN 検出"
  commit id: "fix: テスト追加"
  checkout main
  commit id: "fix C (squash)"
  checkout release/v1.1
  cherry-pick id: "fix C (squash)" tag: "v1.1.1"
  checkout main
  branch release/v1.2
  commit id: "rc2" tag: "v1.2.0-rc.1"
  commit id: "ga2" tag: "v1.2.0"
  checkout main
  commit id: "hotfix X" type: HIGHLIGHT
  commit id: "feat D"
  checkout release/v1.2
  cherry-pick id: "hotfix X" tag: "v1.2.1"
  checkout main
  commit id: "feat E"
```

- `main` は常に「次期バージョン（N+1）」の開発ラインであり、直接デプロイ・出荷の起点にはしない。
- 機能追加・修正は `main` から `feature/*` / `fix/*` を切って進め、**squash merge** で `main` に取り込む。
- squash では枝側の複数コミット（`flag: 実装`・`flag: レビュー反映` など）が `main` 上の 1 コミット（`feat B (squash)`）にまとまる。枝のコミットは `main` に個別には現れず、マージコミットも作らない（図でブランチ線が `main` に戻らないのはこのため。`main` は linear history を保つ）。
- 出荷（SaaS 本番デプロイ / セルフホスト配布）は必ず `release/vX.Y` 上のタグから行う。
- 図の `fix C (squash)` → `v1.1.1` や `hotfix X` → `v1.2.1` のように、修正は **main → release の一方向**にのみ流れる（upstream first）。
- どの `release/*` へ backport するかは**選択的**で、そのバグが存在し、かつ保守期間内の release にのみ cherry-pick する。`fix C` は保守中の v1.1 へ戻して `v1.1.1` を出す一方、v1.2 は fix C を載せた後の `main` から切るため最初から含む。

### 命名規則

| 種別 | 形式 | 例 |
| --- | --- | --- |
| feature ブランチ | `feature/<issue番号>-<短い説明>` | `feature/1234-tenant-flag-api` |
| fix ブランチ | `fix/<issue番号>-<短い説明>` | `fix/1250-forecast-nan-handling` |
| release ブランチ | `release/vX.Y` | `release/v1.2` |
| リリース候補タグ | `vX.Y.Z-rc.N` | `v1.2.0-rc.1` |
| GA タグ | `vX.Y.Z`（SemVer） | `v1.2.1` |

## ブランチプロテクションとマージルール

### ブランチ・タグ保護（Repository Rulesets）

保護設定は従来の branch protection ではなく **Repository Rulesets** で行う（ブランチとタグの保護、および bypass 権限の管理を一元化できるため）。

#### `main` に適用するルール

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

#### `release/*` に適用するルール

- `main` と同一のルールセットを適用する。
- 加えて、ブランチの**作成をリリース責任者（またはリリースワークフロー）に限定**する（creation restriction）。
- release ブランチへの PR は cherry-pick PR のみを想定し、PR テンプレートで元 PR（main 側）へのリンクを必須項目とする。

#### タグ `v*` に適用するルール

- 作成: Ruleset の許可アクター（actor allowlist）を **リリース責任者ロール** と **リリース用 GitHub App** の 2 者に限定する。これは bypass ではなく正規の許可であり、「Bypass 権限の方針」の対象外である。
- 更新・削除: 全員禁止（bypass 対象なし）。公開済みバージョンの改変を構造的に不可能にする。

タグ push はリリースワークフローの起動トリガーであるため、**そのワークフロー自身が最初のタグを打つことはできない**。誰がタグを作るかは次のとおり使い分ける。

| タグを打つ主体 | 手段 | 用途 |
| --- | --- | --- |
| リリース責任者ロール（人間） | ローカルまたは GitHub UI からタグを push | 通常の RC / GA。押下者が監査ログに残る |
| リリース用 GitHub App | `workflow_dispatch` で起動したワークフローが App トークンでタグを作成 | タグ付けを含めて自動化したい場合。起動者が監査ログに残る |

- GitHub App を用いる場合、**タグ作成に `GITHUB_TOKEN` を使わない**。`GITHUB_TOKEN` が作成したタグ・Release は他のワークフローを起動しないため、後続のビルド・昇格ワークフローが動かない。App のインストールトークンか専用の PAT を用いる。
- いずれの経路でも、タグが指すコミットは `release/vX.Y` 上になければならない。ワークフロー側で検証し、満たさない場合は失敗させる。

#### Bypass 権限の方針

- 組織管理者を含め、bypass list への恒常的な登録は行わない。緊急時は bypass ではなく、規約で定めた緊急手順（[障害対応](./incident#ホットフィックス手順)の緊急パッチ: RC タグは打ち、staging 検証のみ省略する）で対応する。
- bypass が発生した場合（監査ログで検知）は、事後レビューを必須とする。

### マージルール

1. `feature/*` → `main` のマージ方式は **squash merge** とする（merge commit / rebase merge はリポジトリ設定で無効化する）。
2. `main` → `release/*` への反映は **cherry-pick のみ**とする。merge / rebase による取り込みは禁止する。
3. `release/*` → `main` のマージは禁止する（upstream first の徹底）。
4. PR は小さく保つ。大きくなる場合は分割し、未完成の部分は到達不能な状態で `main` へ入れる。隔離手段は dark launch / 非公開 API としての先行マージ / branch by abstraction の 3 つで、適用条件は[バージョン運用](./versioning#導入までの暫定規約)に定める。long-lived な feature ブランチへ退避してはならない。feature flag による分割は[現時点では利用を見送り検討中](./versioning#feature-flag-運用)であり、導入後に上記を置き換える。

### PR タイトル規約

squash merge では **PR タイトルがそのまま `main` のコミットメッセージ**になる。加えて、GitHub の自動リリースノートはマージ済み PR のタイトルを見出しとして列挙する（[リリースとデプロイ](./release#github-release-運用規約)）。したがって PR タイトルは `main` の履歴とリリースノートの双方に残る文字列であり、次を規約とする。

1. PR タイトルは **Conventional Commits**（`<type>(<scope>): <要約>`）に準拠させる。`<scope>` は任意で、省略してよい。
2. 許可する type の一覧は設定ファイル（例: `.claude/checks.json` の `commit.conventional.types`）を単一の情報源とし、CI の検証スクリプトは実行時にそこを読む。type の追加・削除は設定ファイルの変更だけで済ませ、本規約は一覧を持たない（二重管理を避けるため）。検証スクリプトが設定ファイルを読めない環境向けに既定値を内蔵する場合は、その既定値が設定ファイルと一致することを CI で検査する。
3. 後方互換性を壊す変更は type の直後に `!` を付ける（例: `feat(api)!: ...`）。破壊的変更の内容は PR 本文に記載する。
4. **CI で PR タイトルの書式を検証**し、非準拠の PR はマージ不可とする（required status check に含める）。
5. 要約は変更内容を利用者視点で具体的に書く。`修正` `対応` のような内容を持たない要約は認めない（リリースノートの見出しとして読まれるため）。
6. squash merge 時のコミットメッセージは**リポジトリ設定で固定**し、マージ実行者の手作業に依存させない。GitHub の Settings → General → Pull Requests を開き、`Allow squash merging` の下にあるドロップダウンで `Pull request title and description` を選ぶ。UI ではタイトルと本文をこの 1 つのドロップダウンでまとめて決めるが、API では `squash_merge_commit_title: PR_TITLE` と `squash_merge_commit_message: PR_BODY` の 2 つのフィールドに対応する。設定が意図どおりかは API 側で確かめられる。

    ```bash
    gh api repos/{owner}/{repo} --jq '{squash_merge_commit_title, squash_merge_commit_message}'
    ```

7. 既定値（API では `squash_merge_commit_title: COMMIT_OR_PR_TITLE` と `squash_merge_commit_message: COMMIT_MESSAGES`）を避ける理由は 2 つある。1 つは、本文に枝側のコミット一覧が差し込まれ、`main` の履歴に `wip` などの作業過程が残ること。もう 1 つは、既定のタイトルが「枝のコミットが 1 個ならそのコミットの件名、2 個以上なら PR タイトル」という条件分岐になっていること。CI が検証するのは PR タイトルだけなので、**単一コミットの PR では検証を通っていない文字列が `main` に着地する**。

枝（`feature/*` / `fix/*`）内の個々のコミットメッセージも Conventional Commits に揃えることを推奨するが、squash により `main` へは残らないため必須とはしない。
