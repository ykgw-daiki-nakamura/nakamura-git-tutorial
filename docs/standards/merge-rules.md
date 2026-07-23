---
outline: [2, 3]
---

# マージルールと PR タイトル規約

`main` / `release/*` への取り込み方式と、PR タイトルの書式を定める。

## このページの要点

- 取り込み方式は 3 つとも固定する。`feature/*` → `main` は squash merge、`main` → `release/*` は cherry-pick のみ、`release/*` → `main` は禁止。
- PR タイトルは `main` の履歴とリリースノートの両方に残る。Conventional Commits に準拠させ、CI で検証する。
- squash 時のコミットメッセージはリポジトリ設定で固定し、マージ実行者の手作業に依存させない。

## マージルール

1. `feature/*` → `main` のマージ方式は **squash merge** とする（merge commit / rebase merge はリポジトリ設定で無効化する）。
2. `main` → `release/*` への反映は **cherry-pick のみ**とする。merge / rebase による取り込みは禁止する。
3. `release/*` → `main` のマージは禁止する（upstream first の徹底）。
4. PR は小さく保つ。大きくなる場合は分割し、未完成の部分は到達不能な状態で `main` へ入れる。**long-lived な feature ブランチへ退避してはならない。** 隔離の手段と適用条件は[バージョン運用](./versioning#導入までの暫定規約)に定める。

## PR タイトル規約

PR タイトルは、次の 2 か所に残る文字列である。

- squash merge では、**PR タイトルがそのまま `main` のコミットメッセージ**になる。
- GitHub の自動リリースノートは、マージ済み PR のタイトルを見出しとして列挙する（[リリースとデプロイ](./release#github-release-運用規約)）。

したがって次を規約とする。

### 書式

1. PR タイトルは **Conventional Commits**（`<type>(<scope>): <要約>`）に準拠させる。`<scope>` は任意で、省略してよい。
2. 後方互換性を壊す変更は type の直後に `!` を付ける（例: `feat(api)!: ...`）。破壊的変更の内容は PR 本文に記載する。
3. 要約は変更内容を利用者視点で具体的に書く。`修正` `対応` のような内容を持たない要約は認めない（リリースノートの見出しとして読まれるため）。
4. 許可する type の一覧は、**設定ファイルを単一の情報源**とする（例: `.github/conventions.json` の `commit.conventional.types`）。本規約は一覧を持たない。

ブランチ（`feature/*` / `fix/*`）内の個々のコミットメッセージも、Conventional Commits に揃えることを推奨する。ただし squash により `main` へは残らないため、必須とはしない。

### 規約を担保する仕組み

上記を人の注意力に委ねず、次の 2 つで機械的に担保する。

| 対象 | 設定 | 効果 |
| --- | --- | --- |
| CI | PR タイトルの書式を検証し、required status check に含める | 非準拠の PR をマージできなくする |
| リポジトリ設定 | squash merge 時のコミットメッセージを **PR のタイトルと本文**に固定する | 検証を通ったタイトルがそのまま `main` に着地する |

リポジトリ設定は GitHub の Settings → General → Pull Requests で行う。`Allow squash merging` の下にあるドロップダウンで `Pull request title and description` を選ぶ。UI ではタイトルと本文をこの 1 つのドロップダウンでまとめて決めるが、API では 2 フィールドに対応するため、意図どおりかは API 側で確かめられる（期待値は `PR_TITLE` と `PR_BODY`）。

```bash
gh api repos/{owner}/{repo} --jq '{squash_merge_commit_title, squash_merge_commit_message}'
```

### 補足: 上記の根拠

**type の一覧を設定ファイルへ置く理由。** 規約と検証スクリプトの二重管理を避けるためで、type の追加・削除は設定ファイルの変更だけで済ませる。置き場所は、規約を強制するゲートである CI 自身が持つ場所（`.github/` 配下など）とする。特定のエディタや AI エージェント向けの設定ディレクトリには置かない。そのツールを使わない者にも効く規約が、任意のツールの設定に依存してしまうためである。検証スクリプトが設定ファイルを読めない環境向けに既定値を内蔵する場合は、その既定値が設定ファイルと一致することを CI で検査する。

**squash merge の既定値を避ける理由。** 既定値（API では `squash_merge_commit_title: COMMIT_OR_PR_TITLE` と `squash_merge_commit_message: COMMIT_MESSAGES`）には 2 つの問題がある。

- 本文にブランチ側のコミット一覧が差し込まれ、`main` の履歴に `wip` などの作業過程が残る。
- 既定のタイトルが「ブランチのコミットが 1 個ならそのコミットの件名、2 個以上なら PR タイトル」という条件分岐になっている。CI が検証するのは PR タイトルだけなので、**単一コミットの PR では検証を通っていない文字列が `main` に着地する**。
