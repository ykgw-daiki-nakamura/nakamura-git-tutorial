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
| Required status checks | lint / 型チェック / テスト / ビルド | CI 成功をマージ条件とする。Require branches to be up to date を有効化（頻度が高くなった場合は merge queue の導入を検討） |
| Require conversation resolution | 有効 | 指摘の放置マージを防ぐ |
| Require linear history | 有効 | squash merge 運用と整合させ、履歴を 1 PR = 1 コミットに保つ |
| Block force pushes / deletions | 有効 | 履歴改変・ブランチ消失の防止 |
| CODEOWNERS review | 有効（対象: DB マイグレーション、IaC、`.github/workflows/`） | 影響の大きい変更にドメイン責任者のレビューを必須化する。特にリリースワークフロー自体の変更はリリース責任者のレビューを必須とする |

各ルールを有効にすると、GitHub 上では次の動作になる。

- **Restrict direct pushes**: `main` への直接 push を拒否する。変更を `main` へ入れる経路が PR だけになる。
- **Required approvals**: 指定した人数の Approve が付くまでマージを拒否する。なお GitHub では PR の作成者が自分の PR を承認できないため、この人数は作成者以外で満たす必要がある。
- **Dismiss stale approvals on push**: 承認後に新しいコミットが push されると、それまでの Approve を自動で取り消す。承認を得た後に中身を差し替える経路をふさぐ。
- **Required status checks**: 指定した名前のチェックが成功するまでマージを拒否する。Require branches to be up to date を併用すると、`main` の最新コミットを取り込んでいない PR もマージ不可になる（`main` 側の変更と組み合わさってはじめて壊れる変更を防げるが、`main` が動くたびに PR の更新と CI の再実行が要る。この待ち時間が問題になったら merge queue を検討する）。
- **Require conversation resolution**: PR に付いたレビューコメントのスレッドがすべて解決済み（Resolved）になるまでマージを拒否する。
- **Require linear history**: 親を 2 つ持つコミット（マージコミット）が積まれることを拒否する。結果として merge commit 方式のマージが使えなくなり、squash merge と rebase merge だけが通る。
- **Block force pushes / deletions**: `git push --force` による履歴の書き換えと、ブランチ自体の削除を拒否する。
- **CODEOWNERS review**: `CODEOWNERS` ファイルに書いたパスへ変更が及ぶと、そのパスの所有者を自動でレビュアーに指名し、所有者の承認をマージ条件に加える。

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
