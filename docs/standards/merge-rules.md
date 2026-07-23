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
4. PR は小さく保つ。大きくなる場合は分割し、未完成の部分は到達不能な状態で `main` へ入れる。**long-lived な feature ブランチへ退避してはならない。**
    - 隔離手段は dark launch / 非公開 API としての先行マージ / branch by abstraction の 3 つ。適用条件は[バージョン運用](./versioning#導入までの暫定規約)に定める。
    - feature flag による分割は[現時点では利用を見送っている](./versioning#feature-flag-運用)。導入後は上記の 3 手段を置き換える。

## PR タイトル規約

PR タイトルは、次の 2 か所に残る文字列である。

- squash merge では、**PR タイトルがそのまま `main` のコミットメッセージ**になる。
- GitHub の自動リリースノートは、マージ済み PR のタイトルを見出しとして列挙する（[リリースとデプロイ](./release#github-release-運用規約)）。

したがって次を規約とする。

1. PR タイトルは **Conventional Commits**（`<type>(<scope>): <要約>`）に準拠させる。`<scope>` は任意で、省略してよい。
2. 許可する type の一覧は、**設定ファイルを単一の情報源**とする（例: `.github/conventions.json` の `commit.conventional.types`）。CI の検証スクリプトは実行時にそこを読む。
    - type の追加・削除は設定ファイルの変更だけで済ませ、本規約は一覧を持たない（二重管理を避けるため）。
    - 設定ファイルは、規約を強制するゲートである CI 自身が持つ場所（`.github/` 配下など）に置く。特定のエディタや AI エージェント向けの設定ディレクトリには置かない。そのツールを使わない者にも効く規約が、任意のツールの設定に依存してしまうため。
    - 検証スクリプトが設定ファイルを読めない環境向けに既定値を内蔵する場合は、その既定値が設定ファイルと一致することを CI で検査する。
3. 後方互換性を壊す変更は type の直後に `!` を付ける（例: `feat(api)!: ...`）。破壊的変更の内容は PR 本文に記載する。
4. **CI で PR タイトルの書式を検証**し、非準拠の PR はマージ不可とする（required status check に含める）。
5. 要約は変更内容を利用者視点で具体的に書く。`修正` `対応` のような内容を持たない要約は認めない（リリースノートの見出しとして読まれるため）。
6. squash merge 時のコミットメッセージは**リポジトリ設定で固定**し、マージ実行者の手作業に依存させない。
    - 設定場所は GitHub の Settings → General → Pull Requests。`Allow squash merging` の下にあるドロップダウンで `Pull request title and description` を選ぶ。
    - UI ではタイトルと本文をこの 1 つのドロップダウンでまとめて決める。API では `squash_merge_commit_title: PR_TITLE` と `squash_merge_commit_message: PR_BODY` の 2 フィールドに対応するため、設定が意図どおりかは API 側で確かめられる。

    ```bash
    gh api repos/{owner}/{repo} --jq '{squash_merge_commit_title, squash_merge_commit_message}'
    ```

7. 既定値は避ける（API では `squash_merge_commit_title: COMMIT_OR_PR_TITLE` と `squash_merge_commit_message: COMMIT_MESSAGES`）。理由は 2 つある。
    - 本文にブランチ側のコミット一覧が差し込まれ、`main` の履歴に `wip` などの作業過程が残る。
    - 既定のタイトルが「ブランチのコミットが 1 個ならそのコミットの件名、2 個以上なら PR タイトル」という条件分岐になっている。CI が検証するのは PR タイトルだけなので、**単一コミットの PR では検証を通っていない文字列が `main` に着地する**。

ブランチ（`feature/*` / `fix/*`）内の個々のコミットメッセージも、Conventional Commits に揃えることを推奨する。ただし squash により `main` へは残らないため、必須とはしない。
