# デュアル配布（SaaS + セルフホスト）でのリリース運用

同じプロダクトを **SaaS 版**（自社が運用してホスト）と **セルフホスト版**（顧客が自分の環境に導入して運用。オンプレミスや持ち込み VM など）の両方で提供するとき、「リリース」の意味が 2 つに割れます。このページは、[GitLab Flow](./gitlab-flow) を土台に、**対外バージョン（セルフホスト）と環境自動リリース（SaaS）を、単一の `main` の上で両立**させる設計をまとめます。

## デプロイとリリースは別のこと

まず用語を分けます。混ぜると設計が破綻します。

| | 環境自動リリース（SaaS） | 対外バージョン（セルフホスト） |
| --- | --- | --- |
| 本質 | **デプロイ**（コードを環境に載せる） | **リリース**（出荷単位に版を確定する） |
| 主体 | 自社 | 顧客（自前 VM に導入） |
| 起点 | `main` / 環境ブランチへの push | 版を切る意思決定 |
| 頻度 | 継続的（毎マージ） | 節目（週次・月次など） |
| バージョン | 顧客に見えない（`1.6.0-rc.3` 等） | **顧客が指定する GA の SemVer**（`1.6.0`） |
| 成果物 | なし（環境に反映されるだけ） | **Release にインストーラ／イメージを添付** |
| GitHub 機能 | Deployments / Environments | **タグ + GitHub Release** |

要点は、**[GitHub Release](./release#github-release) はタグに紐づく＝出荷点にだけ打つもの**で、これは主に **セルフホスト のためのもの**だということです。SaaS は継続デプロイなので、Release ではなく Deployments で「いま本番に何が出ているか」を追います。

## 全体像：単一 main から 2 レーンへ

すべての変更は **`main` に upstream-first で入れる**のが唯一の絶対ルールです。そこから 2 つのレーンに分岐します。

```mermaid
flowchart LR
    F["feature/*"] --> M["main"]
    M --> S["staging"]
    S --> P["production<br/>(SaaS 継続デプロイ)"]
    M --> R["release/1.6"]
    R --> T["tag v1.6.0<br/>+ GitHub Release<br/>(セルフホスト 成果物)"]
```

- **SaaS**: `main → staging → production` の[環境ブランチ](./gitlab-flow#パターン-a-環境ブランチ)。タグ不要、継続デプロイ。
- **セルフホスト**: リリース時に `main` から `release/x.y` を切り、[リリースブランチ](./gitlab-flow#パターン-b-リリースブランチ)として SemVer タグと GitHub Release を出す。旧版の保守は複数の `release/*` を残して行う（[複数バージョンの保守](./release-branches)）。

::: info なぜ セルフホスト だけ Release が要るのか
SaaS は更新タイミングを自社が握るので「版」を顧客に見せる必要がありません。セルフホスト は **顧客が自分のペースで導入・更新**するため、`v1.2` のまま数ヶ月動く現場が普通にあります。だから複数の版を並行保守し、それぞれに GitHub Release（＋インストール成果物）が要ります。
:::

## 決めるべき唯一の分岐：SaaS は「main 追従」か「GA 追従」か

ここだけ選べば設計が確定します。

### モデル 1：SaaS は main を追う（先行デプロイ・推奨）

```mermaid
flowchart LR
    Fe["feature/*"] --> Ma["main"]
    Ma --> Pr["production<br/>(SaaS: 常に最新 1.6.0-rc.N)"]
    Ma --> Re["release/1.6 → v1.6.0<br/>(セルフホスト: 後から GA)"]
```

SaaS は GA より先を走り、実質の **dogfooding（自社が最初に踏む）** になります。セルフホスト に GA を出す頃には SaaS で揉まれた後なので品質が上がります。SaaS 本番は `1.6.0-rc.N`、セルフホスト は `1.6.0`。**速度と品質検証を重視するならこちら。**

### モデル 2：SaaS も GA を追う（リリース先行）

```mermaid
flowchart LR
    Fe2["feature/*"] --> Ma2["main"]
    Ma2 --> Re2["release/1.6"]
    Re2 --> V2["v1.6.0 (セルフホスト)"]
    Re2 --> Pr2["production<br/>(SaaS も release/1.6 から)"]
```

SaaS＝「常に最新 GA を継続パッチ」。SaaS と セルフホスト が**同じ版のコード**を走るのでサポートが楽になる代わりに、SaaS への機能投入がリリース周期に律速されます。**サポートの一貫性を最優先するならこちら。**

::: tip 迷ったらモデル 1
「SaaS の速度」という当初の狙いを活かせ、SaaS がステージング代わりになって セルフホスト の GA 品質が上がります。まずモデル 1 で始め、サポート負荷が問題になったらモデル 2 への移行を検討すれば十分です。
:::

## 対外バージョンを自動で出す

手動タグ運用は忘れ・ズレが起きるので、**[Conventional Commits](./release#conventional-commits-と対応している)（このリポジトリでは必須）から版を自動計算**するツールを噛ませます。

- **release-please（推奨）**: `main` のコミットから次版を判定し、「リリース PR」（version bump + CHANGELOG）を自動で開く。それをマージした瞬間に**タグ + GitHub Release を自動作成**する。
- **semantic-release**: マージ即リリースまで自動化したい場合の選択肢。

環境デプロイ（SaaS）とリリース（セルフホスト）は**別々のワークフロー**にして干渉させないのがコツです。

```yaml
# .github/workflows/release.yml（セルフホスト 版の GA を自動リリースする例）
on:
  push:
    branches: [main]        # release-please がリリース PR を維持
# 既定は読み取りのみ。リリース PR 作成・タグ・Release に必要な権限だけを付与
permissions:
  contents: write
  pull-requests: write
# actions は commit SHA でピン留めし # vX.Y.Z コメントを添える（本リポジトリの方針）
```

環境デプロイは `on: push: branches: [staging, production]` など別トリガーの独立ワークフローにします。

## リリースノート自動生成の落とし穴

`gh release create --generate-notes` は「**前タグ以降に、そのブランチにマージされた PR**」からノートを作ります。GitLab Flow の cherry-pick 運用ではここが崩れます。

- パッチは upstream-first で **PR が `main` にマージ**され、`release/*` には cherry-pick コミットが乗るだけ。→ リリースブランチ基準の自動生成が **元 PR を取りこぼす**。
- 対策: `--notes-start-tag <前の系列タグ>` で基準を明示する／cherry-pick コミットに元 PR 番号 `(#123)` を残す／重要な系列は手動でノートを整える。

## セキュリティ修正のファンアウト

1 つの修正を**すべての出荷先に届ける**のが最重要です。upstream-first を徹底すると構造的に漏れません。

```mermaid
gitGraph
    commit id: "脆弱性修正(main-first)" type: HIGHLIGHT
    branch "release-1.6"
    checkout "release-1.6"
    commit id: "cherry-pick→1.6" tag: "v1.6.1"
    checkout main
    branch "release-1.5"
    checkout "release-1.5"
    commit id: "cherry-pick→1.5" tag: "v1.5.4"
```

- まず `main` に修正を入れる → **SaaS 本番へ即昇格**（staging→production）。
- 同時に**サポート中の `release/*` すべてへ cherry-pick** → それぞれパッチ版をタグ＆Release（セルフホスト 顧客へ配布）。
- 逆順（リリースブランチだけ直す）は `main` 取り込み漏れで次版に再発するので厳禁です。

## 決めておくこと

1. **サポート版マトリクス**: いくつ前まで（N-1 / N-2）セキュリティ backport するか。無限には支えられないので明文化する。
2. **エディション差分の出し分け**: SaaS 限定／セルフホスト 限定の機能を**ブランチで分けない**。単一 `main` のまま**ビルドフラグ・設定・フィーチャーフラグ**で切り替える（[顧客カスタマイズとバージョン運用](./customization) の考え方）。ブランチで分けると保守が破綻します。
3. **成果物の中身**: セルフホスト の Release には、顧客が導入する**インストーラ / コンテナイメージ / Helm chart** 等の実体を添付する。

::: info これは実在するモデル
GitLab 自身がこの形です。**GitLab.com（SaaS）** は auto-deploy ブランチで継続デプロイし、**self-managed（セルフホスト 相当）** は毎月の stable ブランチから版付きリリースを出して backport で保守しています。実績のある構成なので安心して踏襲できます。
:::

## 関連ページ

- [GitLab Flow](./gitlab-flow) — 環境ブランチ／リリースブランチの基礎
- [リリースとバージョン管理](./release) — タグ・SemVer・GitHub Release の基本
- [複数バージョンの保守（リリースブランチ）](./release-branches) — 旧版保守と cherry-pick の実際
- [顧客カスタマイズとバージョン運用](./customization) — エディション差分の扱い
- [ブランチ戦略の使い分け](./branching-strategies) — そもそもどの戦略を選ぶか
