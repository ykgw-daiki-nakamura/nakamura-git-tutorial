---
outline: [2, 3]
---

# マージルールと PR タイトル規約

`main` / `release/*` への取り込み方式と、PR タイトルの書式を定める。ブランチ体系は[ブランチ運用](./branching)、保護設定は[ブランチ保護](./branch-protection)を参照。全体像は[概要](./)を参照。

## マージルール

1. `feature/*` → `main` のマージ方式は **squash merge** とする（merge commit / rebase merge はリポジトリ設定で無効化する）。
2. `main` → `release/*` への反映は **cherry-pick のみ**とする。merge / rebase による取り込みは禁止する。
3. `release/*` → `main` のマージは禁止する（upstream first の徹底）。
4. PR は小さく保つ。大きくなる場合は分割し、未完成の部分は到達不能な状態で `main` へ入れる。隔離手段は dark launch / 非公開 API としての先行マージ / branch by abstraction の 3 つで、適用条件は[バージョン運用](./versioning#導入までの暫定規約)に定める。long-lived な feature ブランチへ退避してはならない。feature flag による分割は[現時点では利用を見送り検討中](./versioning#feature-flag-運用)であり、導入後に上記を置き換える。

## PR タイトル規約

squash merge では **PR タイトルがそのまま `main` のコミットメッセージ**になる。加えて、GitHub の自動リリースノートはマージ済み PR のタイトルを見出しとして列挙する（[リリースとデプロイ](./release#github-release-運用規約)）。したがって PR タイトルは `main` の履歴とリリースノートの双方に残る文字列であり、次を規約とする。

1. PR タイトルは **Conventional Commits**（`<type>(<scope>): <要約>`）に準拠させる。`<scope>` は任意で、省略してよい。
2. 許可する type の一覧は設定ファイル（例: `.github/conventions.json` の `commit.conventional.types`）を単一の情報源とし、CI の検証スクリプトは実行時にそこを読む。type の追加・削除は設定ファイルの変更だけで済ませ、本規約は一覧を持たない（二重管理を避けるため）。設定ファイルは、規約を強制するゲートである CI 自身が持つ場所（`.github/` 配下など）に置く。特定のエディタや AI エージェント向けの設定ディレクトリに置くと、そのツールを使わない者にも効く規約が、任意のツールの設定に依存してしまう。検証スクリプトが設定ファイルを読めない環境向けに既定値を内蔵する場合は、その既定値が設定ファイルと一致することを CI で検査する。
3. 後方互換性を壊す変更は type の直後に `!` を付ける（例: `feat(api)!: ...`）。破壊的変更の内容は PR 本文に記載する。
4. **CI で PR タイトルの書式を検証**し、非準拠の PR はマージ不可とする（required status check に含める）。
5. 要約は変更内容を利用者視点で具体的に書く。`修正` `対応` のような内容を持たない要約は認めない（リリースノートの見出しとして読まれるため）。
6. squash merge 時のコミットメッセージは**リポジトリ設定で固定**し、マージ実行者の手作業に依存させない。GitHub の Settings → General → Pull Requests を開き、`Allow squash merging` の下にあるドロップダウンで `Pull request title and description` を選ぶ。UI ではタイトルと本文をこの 1 つのドロップダウンでまとめて決めるが、API では `squash_merge_commit_title: PR_TITLE` と `squash_merge_commit_message: PR_BODY` の 2 つのフィールドに対応する。設定が意図どおりかは API 側で確かめられる。

    ```bash
    gh api repos/{owner}/{repo} --jq '{squash_merge_commit_title, squash_merge_commit_message}'
    ```

7. 既定値（API では `squash_merge_commit_title: COMMIT_OR_PR_TITLE` と `squash_merge_commit_message: COMMIT_MESSAGES`）を避ける理由は 2 つある。1 つは、本文にブランチ側のコミット一覧が差し込まれ、`main` の履歴に `wip` などの作業過程が残ること。もう 1 つは、既定のタイトルが「ブランチのコミットが 1 個ならそのコミットの件名、2 個以上なら PR タイトル」という条件分岐になっていること。CI が検証するのは PR タイトルだけなので、**単一コミットの PR では検証を通っていない文字列が `main` に着地する**。

ブランチ（`feature/*` / `fix/*`）内の個々のコミットメッセージも Conventional Commits に揃えることを推奨するが、squash により `main` へは残らないため必須とはしない。
