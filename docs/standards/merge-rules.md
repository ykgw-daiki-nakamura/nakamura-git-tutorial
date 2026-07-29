---
outline: [2, 3]
---

# マージルール

`main` / `release/*` への取り込み方式を定める。PR を出す開発者が守る規約は[PR タイトル規約](./pr-title)にあり、本ページの規約はリポジトリ設定とリリース運用が担保する。

## このページの要点

- 取り込み方式は 3 つとも固定する。作業ブランチ → `main` は squash merge、`main` → `release/*` は cherry-pick のみ、`release/*` → `main` は禁止。
- squash merge はリポジトリ設定で固定し、マージ画面に方式の選択肢を出さない。PR 作成者やマージ実行者の判断に委ねない。
- cherry-pick と upstream first の制約が効くのは、`release/*` を扱う場面（リリース・backport）である。日々の PR には現れない。

## 取り込み方式

| 経路 | 方式 | 担保 | 守る主体 |
| --- | --- | --- | --- |
| 作業ブランチ（feature / fix）→ `main` | squash merge | 🤖 リポジトリ設定（merge commit / rebase merge を無効化） | 設定。開発者に選択肢が出ない |
| `main` → `release/*` | cherry-pick のみ | 👤 運用（設定では merge と区別できない） | リリース責任者・backport 担当 |
| `release/*` → `main` | 禁止 | 👤 運用（PR の向き自体は正規の操作） | 同上 |

区分の意味は[規約の担保状況](./enforcement#区分の定義)に定める。

### 作業ブランチから main への取り込み

**squash merge に固定する。** merge commit と rebase merge はリポジトリ設定で無効化し、マージ画面にボタンを出さない。`main` の履歴は 1 PR = 1 コミットに揃い、[ブランチ保護](./branch-protection)で有効にする linear history とも整合する。

開発者はブランチ内で何度コミットしてもよい。作業過程は `main` に残らないため、コミットの粒度やメッセージの書式を規約では縛らない（理由は PR タイトル規約の「タイトルだけを規約にする理由」に記す）。

### squash merge のコミットメッセージ

squash merge が作るコミットメッセージは、リポジトリ設定で **PR のタイトルと本文**に固定する。CI が検証したタイトルをそのまま `main` に着地させるための設定で、PR タイトル規約の検証と対で意味を持つ（既定値のままにできない理由は[補足](#補足-上記の根拠)に記す）。

設定は GitHub の Settings → General → Pull Requests で行う。`Allow squash merging` の下にあるドロップダウンで `Pull request title and description` を選ぶ。UI ではタイトルと本文をこの 1 つのドロップダウンでまとめて決めるが、API では 2 フィールドに対応するため、意図どおりかは API 側で確かめられる（期待値は `PR_TITLE` と `PR_BODY`）。

```bash
gh api repos/{owner}/{repo} --jq '{squash_merge_commit_title, squash_merge_commit_message}'
```

### release ブランチへの反映と upstream first

`main` → `release/*` への反映は **cherry-pick のみ**とする。merge / rebase による取り込みは禁止する。`release/*` → `main` のマージも禁止する（upstream first の徹底）。

この 2 つは設定では強制できない。`release/*` への PR は正規の経路であり、その中身が cherry-pick か merge かを GitHub は区別しないためである。規約として明文化し、レビューで見る。適用する場面と手順は[障害対応](./incident#ホットフィックス手順)に定める。

## PR の粒度と未完成の機能

PR は小さく保つ。大きくなる場合は分割し、未完成の部分は到達不能な状態で `main` へ入れる。**long-lived な feature ブランチへ退避してはならない。** 隔離の手段と適用条件は[バージョン運用](./versioning#導入までの暫定規約)に定める。

変更行数の上限をマージ条件にはしていないため、この項目もレビュー観点である。

## 補足: 上記の根拠

**squash merge の既定値を避ける理由。** 既定値（API では `squash_merge_commit_title: COMMIT_OR_PR_TITLE` と `squash_merge_commit_message: COMMIT_MESSAGES`）には 2 つの問題がある。

- 本文にブランチ側のコミット一覧が差し込まれ、`main` の履歴に `wip` などの作業過程が残る。
- 既定のタイトルが「ブランチのコミットが 1 個ならそのコミットの件名、2 個以上なら PR タイトル」という条件分岐になっている。CI が検証するのは PR タイトルだけなので、**単一コミットの PR では検証を通っていない文字列が `main` に着地する**。
