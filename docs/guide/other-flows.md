# 他のブランチ戦略（Git Flow / GitLab Flow / Release Flow）

[GitHub Flow](./github-flow) が扱いやすい場面は多いですが、**複数バージョンの並行保守**や**環境ごとのデプロイ表現**が必要になると、別のブランチ運用モデルが選択肢に入ります。ここでは代表的な 3 つ——**Git Flow** / **GitLab Flow** / **Microsoft Release Flow**——を、比較の材料として紹介します。どれを選ぶかの判断は [ブランチ戦略の使い分け](./branching-strategies) を参照してください。

## Git Flow

Git Flow は、Vincent Driessen 氏が 2010 年に提唱した、**役割の異なる複数のブランチ**を使い分けるブランチ運用モデルです。リリースを計画的に区切る開発（パッケージ製品・モバイルアプリ・バージョン番号を明示するソフトウェア）に向いています。

### 5 種類のブランチ

Git Flow では、次の 2 本の「常設ブランチ」と 3 種類の「支援ブランチ」を使います。

| ブランチ | 寿命 | 役割 |
| --- | --- | --- |
| `main`（旧 `master`） | 常設 | **出荷済み**の安定版。タグでバージョンを刻む |
| `develop` | 常設 | 次回リリースに向けた**開発の統合先** |
| `feature/*` | 短命 | 個々の機能開発。`develop` から切り `develop` へ戻す |
| `release/*` | 短命 | リリース準備（バグ修正・バージョン調整）。`develop` から切り `main` と `develop` へ戻す |
| `hotfix/*` | 短命 | 出荷後の緊急修正。`main` から切り `main` と `develop` へ戻す |

### 全体の流れ

```mermaid
gitGraph
    commit tag: "v1.0"
    branch develop
    checkout develop
    commit
    branch feature/login
    checkout feature/login
    commit
    commit
    checkout develop
    merge feature/login
    branch release/1.1
    checkout release/1.1
    commit id: "バグ修正"
    checkout main
    merge release/1.1 tag: "v1.1"
    checkout develop
    merge release/1.1
```

- **機能開発**は `feature/*` で行い、完成したら `develop` へマージする。
- リリースが近づいたら `develop` から `release/*` を切り、**そのブランチ上でのみ**バグ修正やバージョン番号の確定を行う（新機能は入れない）。
- リリース確定時に `release/*` を `main` へマージして**タグを打ち**、同じ内容を `develop` へも戻す。

### hotfix（緊急修正）

出荷済みの `main` に緊急の不具合が見つかったら、`develop` を待たずに `main` から `hotfix/*` を切って修正します。

```mermaid
gitGraph
    commit tag: "v1.1"
    branch hotfix/critical
    checkout hotfix/critical
    commit id: "緊急修正"
    checkout main
    merge hotfix/critical tag: "v1.1.1"
    branch develop
    checkout develop
    merge hotfix/critical
```

修正は `main` へマージしてタグを打ち、**`develop` にも必ず取り込む**（同じ不具合が次期リリースで再発しないようにするため）。

::: info 図の補足
上の gitGraph では作図の都合で `develop` を新規ブランチとして描いていますが、実際の `develop` は常設の既存ブランチです。hotfix は「新しく `develop` を作る」のではなく、**既存の `develop` へ取り込む**操作を表しています。
:::

### 長所と短所

- **長所**:
  - リリースの区切りが明確で、**複数バージョンの並行開発・保守**に強い。
  - 「開発中（`develop`）」と「出荷済み（`main`）」がブランチとして分離され、状態が把握しやすい。
- **短所**:
  - ブランチ数が多く運用が複雑。**継続的デプロイ（CD）とは相性が悪い**。
  - `develop` と `main` の二重マージなど手順が煩雑で、長命ブランチはコンフリクトを招きやすい。

::: tip Git Flow は選択肢の一つ
多くの場面ではよりシンプルな [GitHub Flow](./github-flow) で十分で、Git Flow はあくまで「選択肢の一つ」です。どの戦略を選ぶべきかは [ブランチ戦略の使い分け](./branching-strategies) を参照してください。
:::

## GitLab Flow

GitLab Flow は、[GitHub Flow](./github-flow) のシンプルさを保ちつつ、**「本番へどう反映するか」という現実**を補うブランチ運用モデルです。GitHub Flow（`main` 一本）と [Git Flow](#git-flow)（多数のブランチ）の中間に位置づけられます。

中心にあるのは 2 つの原則です。

1. **環境ブランチ**または**リリースブランチ**で、デプロイ先やリリース版を表現する。
2. **Upstream first**（上流優先）——修正は必ず一番上流（`main`）へ先に入れ、そこから下流へ流す。

### パターン A: 環境ブランチ

ステージング・本番など、**デプロイ先の環境をブランチで表す**やり方です。コードは上流から下流へ一方向に流れます。

```mermaid
flowchart LR
    F["feature/*"] -->|マージ| M["main<br/>(開発の最新)"]
    M -->|昇格| S["staging<br/>(検証環境)"]
    S -->|昇格| P["production<br/>(本番環境)"]
```

- `main` へマージされた変更は、まず `staging` へ、検証を経て `production` へと**昇格（promote）** していく。
- 本番で不具合が出たら、まず `main` を直してから各環境ブランチへ反映する（**upstream first**）。特定環境だけを直接パッチしない。
- 「いま本番に何が出ているか」が `production` ブランチを見れば分かる。継続的デプロイと相性が良い。

### パターン B: リリースブランチ

バージョンを明示して出荷するソフトウェア向けに、**リリースごとにブランチを固定**するやり方です。

```mermaid
gitGraph
    commit
    commit tag: "作業"
    branch "2-3-stable"
    checkout "2-3-stable"
    commit tag: "v2.3.0"
    checkout main
    commit id: "バグ修正(main-first)" type: HIGHLIGHT
    checkout "2-3-stable"
    commit id: "cherry-pick→2.3" tag: "v2.3.1"
```

- リリース時点の状態を `2-3-stable` のような**安定ブランチ**として切り出す。
- バグ修正は**まず `main` に入れて**から、必要な安定ブランチへ `cherry-pick` で反映する（ここでも upstream first）。これにより「古いバージョンだけ直って `main` で直っていない」という退行を防ぐ。

### GitHub Flow / Git Flow との違い

- **[GitHub Flow](./github-flow) との違い**: GitHub Flow は `main` にマージ＝即デプロイを前提とする。GitLab Flow は、デプロイのタイミングと `main` へのマージを**環境／リリースブランチで分離**できる。
- **[Git Flow](#git-flow) との違い**: Git Flow のような常設 `develop` を持たず、`main` を開発の中心に据える。ブランチの種類が少なく運用が軽い。

### 長所と短所

- **長所**:
  - `main` を中心にしつつ、**デプロイ／リリースの現実**を無理なく表現できる。
  - upstream first のルールで、修正漏れによる退行を防ぎやすい。
- **短所**:
  - 環境ブランチとリリースブランチのどちらを採るか、**チームで運用を設計する必要**がある。
  - GitHub Flow よりは登場するブランチが増える。

## Microsoft Release Flow

**Microsoft Release Flow**（以下このページでは Release Flow）は、Microsoft（Azure DevOps チーム）が公開しているブランチ運用のガイダンスです。[GitHub Flow](./github-flow) をベースにしつつ、**大規模チームで定期リリースと複数バージョンの保守を回す**ための工夫を加えた「型」で、GitHub Flow / [Git Flow](#git-flow) / [GitLab Flow](#gitlab-flow) と並ぶ選択肢の一つです。

出典: [Microsoft の Git 分岐ガイダンス（Release Flow）](https://learn.microsoft.com/ja-jp/azure/devops/repos/git/git-branching-guidance)

::: tip この節の位置づけ
ここでは Release Flow を**戦略の紹介・比較**として扱います。本リポジトリがどれを採用するか（規約）は別で扱い、ここでは「どういう考え方か」に徹します。
:::

### 3 つの原則

Release Flow の土台は GitHub Flow と同じく、次のシンプルな原則です。

- **すべての作業を feature ブランチで行う** — `main` で直接作業しない。
- **変更は必ず Pull Request で `main` にマージする** — レビューと CI を通す。
- **`main` を常に高品質・最新に保つ** — いつでもここからリリースを切り出せる状態にする。

### ブランチの命名規則

Release Flow は**用途が一目で分かる階層的なブランチ名**を推奨します（原文の例）。

```text
users/<username>/<description>
users/<username>/<workitem>
feature/<feature-name>
feature/<feature-area>/<feature-name>
bugfix/<description>
hotfix/<description>
```

Azure Repos では **「Require branch folders」ポリシー**で「`/` を含む（＝フォルダ階層を持つ）名前」を強制でき、命名を機械的に揃えられます。個人の下書きは `users/<名前>/…`、共有する機能開発は `feature/…` といった住み分けが分かりやすくなります。

### リリースは「長命な release ブランチ」で表す

Release Flow の最大の特徴は、**リリースを長命な `release` ブランチで表現する**ことです。

- リリースのたびに `main` から `release/<番号>`（例 `release/20`）を切る。
- **`release` ブランチから `main` へは PR で戻さない**（マージしない）。
- サポート中のバージョンごとに `release` ブランチが 1 本あり、**サポート終了（EOL）でロック**する。

```mermaid
gitGraph
    commit
    commit tag: "スプリント20"
    branch "release/20"
    checkout main
    commit id: "次の開発"
    checkout "release/20"
    commit id: "hotfix"
    checkout main
    commit id: "同じ修正を先に"
```

この「バージョン系列 = 長命なブランチ」という考え方は、[複数バージョンの保守（リリースブランチ運用）](./release-branches) と同じ発想です。

### main-first + cherry-pick

`release/*` ブランチのバグを直すときは、**先に `main`（mainline）を直し、その修正を `release/*` ブランチへ `cherry-pick` で移植**します。`release/*` から `main` へマージして戻すことはしません（Release Flow 固有のルール）。

この **main-first + cherry-pick** の具体的な手順・コマンド・図は [リリースブランチ運用](./release-branches) にまとめています。「修正が `main` に無い状態を作らない（順序を逆にすると次のリリースで同じバグが復活する）」という鉄則も共通です。

### タグ主軸との違い

Release Flow は「**リリースはタグではなくブランチで表す**」という立場を取ります。一方、継続デプロイ（`main` → GitHub Pages）を前提とする場合は、[リリースとバージョン管理](./release) で説明したとおり**タグ（＋ GitHub Release）を主軸**にする選び方もあります。

どちらが正しいということはありません。**「サポート中の版を長期間 back-patch し続ける」** なら release ブランチが要になり、**「常に最新の 1 版を出し続ける」** ならタグで十分、という使い分けです。

### 環境ブランチ `deploy/<環境>`

Release Flow では、特定環境へのデプロイを表す **`deploy/<環境>`**（例 `deploy/performance-test`）というブランチも、`release` ブランチと同じ要領（main-first + cherry-pick）で扱う手法が紹介されています。これは [GitLab Flow の環境ブランチ](#パターン-a-環境ブランチ)（`staging` / `production` など）と同じ狙いのものです。

### どんなチームに向くか

- 定期的な**スプリント／リリース**を回しつつ、`main` は常にデプロイ可能に保ちたい。
- 出荷済みの版に**緊急修正を back-patch** する必要がある（複数バージョンの並行保守）。
- 大人数で**命名やレビューを機械的に統一**したい（ブランチフォルダ強制など）。

継続デプロイの単一サービスなら [GitHub Flow](./github-flow) で十分です。まずはそこから始め、必要に応じて考え方を採り入れるのが安全です——戦略の選び方は [ブランチ戦略の使い分け](./branching-strategies) を参照してください。

## 関連ページ

- [GitHub Flow](./github-flow) — `main` 一本のシンプルな運用
- [ブランチ戦略の使い分け](./branching-strategies) — どれを選ぶかの判断
- [複数バージョンの保守（リリースブランチ運用）](./release-branches) — release ブランチ運用の実際
- [リリースとバージョン管理](./release) — タグ主軸のリリース
- [デュアル配布（SaaS + セルフホスト）でのリリース運用](./dual-distribution) — SaaS と自ホスト版を単一 main で両立
