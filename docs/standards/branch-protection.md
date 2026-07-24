---
outline: [2, 3]
---

# ブランチ保護

ブランチとタグの保護設定、および bypass 権限の方針を定める。

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
| Required status checks | lint / 型チェック / テスト / ビルド | CI 成功をマージ条件とする。Require branches to be up to date を有効化し、`main` の最新を取り込んでいない PR もマージ不可にする（`main` が動くたびに PR の更新と CI の再実行が要るため、この待ち時間が問題になったら merge queue を検討する） |
| Require conversation resolution | 有効 | 指摘の放置マージを防ぐ |
| Require linear history | 有効 | マージコミットを禁じる結果、merge commit 方式は使えず squash merge と rebase merge だけが通る。squash merge 運用と整合させ、履歴を 1 PR = 1 コミットに保つ |
| Block force pushes / deletions | 有効 | 履歴改変・ブランチ消失の防止 |
| CODEOWNERS review | 有効（対象: DB マイグレーション、IaC、`.github/workflows/`） | 影響の大きい変更にドメイン責任者のレビューを必須化する。特にリリースワークフロー自体の変更はリリース責任者のレビューを必須とする |

各ルールを有効にしたとき GitHub が何を拒否し、何を要求するかは GitHub の仕様に属する。本ページでは繰り返さず、[参考](#参考)に挙げた一次情報を参照する。規約として定めるのは、その仕様を踏まえた本リポジトリの判断（上表の設定値と意図）である。

## `release/*` に適用するルール

- `main` と同一のルールセットを適用する。
- 加えて、ブランチの**作成をリリース責任者（またはリリースワークフロー）に限定**する（creation restriction）。
- release ブランチへの PR は原則 cherry-pick PR のみとし、PR テンプレートで元 PR（main 側）へのリンクを必須項目とする。

> [!TIP]
> **cherry-pick 元が無いときだけは直接 PR を認める**
>
> 該当コードが `main` に存在しない場合（リファクタリングや削除により、そのバグが `main` には無い）に限り、`release/*` への直接 PR を認める。cherry-pick してくる元のコミットが存在しないためで、代わりに次の 2 点を課す。
>
> - PR 本文に「`main` に該当コードが無い理由」と「`main` 側で同じ不具合が再発しないことの根拠」を明記する。
> - リリース責任者の承認を必須とする。
>
> upstream first の目的は `main` への取り込み漏れを防ぐことにある。取り込むべきコードが `main` に無いケースは、その目的の対象外である。

## タグ `v*` に適用するルール

- 作成: Ruleset の許可アクター（actor allowlist）を **リリース責任者ロール** に限定する。これは bypass ではなく正規の許可であり、「Bypass 権限の方針」の対象外である。
- 更新・削除: 全員禁止（bypass 対象なし）。公開済みバージョンは誰も改変できない。

タグはリリース責任者がローカルまたは GitHub UI から push する。押下者が監査ログに残り、誰がどのバージョンを出荷したかを追える。タグが指すコミットは `release/vX.Y` 上になければならない。ワークフロー側で検証し、満たさない場合は失敗させる。

> [!TIP]
> **タグ付けを自動化するなら、ワークフローとは別のアクターが要る**
>
> タグ push はリリースワークフローの起動トリガーであるため、**そのワークフロー自身が最初のタグを打つことはできない**。加えて、ワークフローが既定で持つ `GITHUB_TOKEN` で作成したタグ・Release は他のワークフローを起動しない（GitHub がワークフローの無限ループを防ぐために設けた仕様）。タグ push を待っているビルド・昇格ワークフローは、このトークンで打ったタグでは動かない。
>
> 自動化する場合は、`GITHUB_TOKEN` とは別のアクターのトークンでタグを打つ必要がある。候補は GitHub App（組織に作成してリポジトリにインストールするアプリで、実行基盤である Actions とは別のアクターとして扱われる）のインストールトークンか、専用の PAT である。その主体も Ruleset の許可アクターに登録する。**現時点では自動化せず、リリース責任者による手動のタグ push を正とする。**

## Bypass 権限の方針

- 組織管理者を含め、bypass list への恒常的な登録は行わない。緊急時は bypass ではなく、規約で定めた緊急手順（[障害対応](./incident#ホットフィックス手順)の緊急パッチ: RC タグは打ち、staging 検証のみ省略する）で対応する。
- bypass が発生した場合（監査ログで検知）は、事後レビューを必須とする。

## 参考

本ページの規約は GitHub の仕様に依存する。挙動の一次情報は次のとおり。

- [ルールセットで使用できるルール](https://docs.github.com/ja/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets) — 各ルールが何を拒否し、何を要求するか。上表に挙げた各ルールの挙動はここで確かめる。
- [ルールセットについて](https://docs.github.com/ja/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) — Repository Rulesets の考え方、許可アクター（actor allowlist）と bypass の扱い。
- [コードオーナーについて](https://docs.github.com/ja/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) — `CODEOWNERS` の書式と、レビュアーが自動指名される条件。
- [ワークフローでの認証に GITHUB_TOKEN を使用する](https://docs.github.com/ja/actions/security-for-github-actions/security-guides/automatic-token-authentication) — `GITHUB_TOKEN` で作成したタグ・Release が他のワークフローを起動しない仕様。タグ作成を自動化する場合の前提になる。
