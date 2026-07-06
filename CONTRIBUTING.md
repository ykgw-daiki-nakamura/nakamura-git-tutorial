# コントリビューションガイド

このプロジェクトへの貢献に興味を持っていただきありがとうございます。誤字修正から内容の改善・図の追加まで、どんな貢献も歓迎します。

このリポジトリ自体が **GitHub Flow の教材**なので、運用も GitHub Flow に揃えています。実践の練習も兼ねてご活用ください。

## 開発環境のセットアップ

前提: [Node.js](https://nodejs.org/) 20 以上。

```bash
git clone https://github.com/ykgw-daiki-nakamura/nakamura-git-tutorial.git
cd nakamura-git-tutorial
npm install
npm run docs:dev   # 表示される URL（既定では http://localhost:5173/）でプレビュー
```

## コントリビュートの流れ（GitHub Flow）

1. 最新の `main` からブランチを作成する

   ```bash
   git switch main
   git pull
   git switch -c fix/typo-in-branching   # 接頭辞: feature/ fix/ docs/ chore/
   ```

2. 変更してコミットする（[コミットの作法](https://ykgw-daiki-nakamura.github.io/nakamura-git-tutorial/guide/basics) を参照）
3. リモートに push する

   ```bash
   git push -u origin fix/typo-in-branching
   ```

4. プルリクエストを作成する（テンプレートが自動で挿入されます）
5. CI（ビルド検証）が通り、レビューで承認されたらマージされます

## 変更履歴（CHANGELOG）

ユーザー影響のある変更（ページの追加・削除、機能追加、挙動変更、修正など）を加えたら、
[CHANGELOG.md](CHANGELOG.md) の `[Unreleased]` セクションに 1 行追記してください（`Added` / `Changed` / `Fixed` などに分類）。
軽微な typo 修正や内部リファクタは省略して構いません。

## 提出前のチェック

- [ ] `npm run docs:build` がローカルで通る（CI と同じ検証）
- [ ] `npm run lint:md` がローカルで通る（Markdown の整形チェック）
- [ ] 追加・変更したページのリンクが切れていない
- [ ] Mermaid 図がプレビューで正しく描画される

## Markdown と Mermaid の書き方

- 本文は `docs/guide/` 配下に Markdown で追加します。新規ページは [config.mjs](docs/.vitepress/config.mjs) の `sidebar` にも追加してください。
- 図は Mermaid のコードフェンスで記述します。

  ````markdown
  ```mermaid
  flowchart LR
      A[作業ツリー] -->|git add| B[ステージ]
  ```
  ````

- 日本語ラベルを含む複雑な図は、必要に応じて `"..."` で囲むと崩れにくくなります。

## コミットメッセージ

1 行目は変更内容の要約を簡潔に。種類を表す接頭辞（`feat:` `fix:` `docs:` `chore:` `ci:`）を付けると履歴が読みやすくなります。

```text
docs: ブランチ命名規則の例を追加
```

## プルリクエストのタイトル

このリポジトリは **Squash Merge** を採用しているため、**PR タイトルがそのまま `main` のコミットメッセージ**になります。PR タイトルもコミットメッセージと同じ **Conventional Commits 形式**（`type(scope): summary`）にしてください。CI（`pr-title.yml`）が自動で検証します。

```text
feat(auth): ログイン失敗時のリトライを追加
```

## 行動規範

敬意を持った建設的なやり取りを心がけてください。レビューは「粗探し」ではなく、一緒に品質を上げる場です。
