# ① ローカルで基本操作

最初の実習では、Git の心臓部である **「作業ツリー → ステージ → リポジトリ」** の流れを、このリポジトリの中で体験します。編集するのは [練習場](../practice/) ページ（`docs/practice/index.md`）です。対応する解説は [Git の基本](../guide/basics) です。

## 🎯 この実習のゴール

- 作業ブランチを作って練習ページを編集できる
- `status` / `diff` で変更を確認できる
- `add` → `commit` の 2 段階を理解する
- `git log` で履歴を読める

| 前提 | 所要時間 |
| --- | --- |
| [実習の進め方](./) の clone まで完了（以降ローカルのみ） | 約 15 分 |

## ステップ 1：作業ブランチを作る

clone したディレクトリに入り、最新の `main` から作業ブランチを切ります。**いきなり main で作業しない**のが鉄則です。

```bash
cd nakamura-git-tutorial      # 共有リポジトリのクローン
git switch main
git switch -c practice/basics
```

✅ **チェックポイント**

```bash
git status
```

```text
On branch practice/basics
nothing to commit, working tree clean
```

`practice/basics` ブランチにいて、まだ何も変更していない状態です。

## ステップ 2：練習ページを編集して状態を見る

[練習場](../practice/) ページ（`docs/practice/index.md`）をエディタで開き、「練習ログ」の箇条書きに **1 行追記** します。

```markdown
## 練習ログ

実習①②⑥ では、このリストに行を追加していきます。

- YYYY-MM-DD サンプル: 練習を始めました
- YYYY-MM-DD はじめてのコミットに挑戦   ← この行を追加（日付は今日の日付に）
```

保存したら、Git にどう見えているか確認します。

```bash
git status
```

✅ **チェックポイント**

```text
On branch practice/basics
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
        modified:   docs/practice/index.md

no changes added to commit (use "git add" and/or "git commit -a")
```

`docs/practice/index.md` が **modified（変更あり・未ステージ）** として現れました。

## ステップ 3：差分を見る

`git diff` で「何が変わったか」を確認します。

```bash
git diff
```

✅ **チェックポイント**

```text
diff --git a/docs/practice/index.md b/docs/practice/index.md
@@ ... @@
 - YYYY-MM-DD サンプル: 練習を始めました
+- YYYY-MM-DD はじめてのコミットに挑戦
```

`+` で始まる行が**追加した内容**です。`git diff` は **まだステージしていない変更** を表示します。

## ステップ 4：ステージしてコミットする

`git add` で次のコミットに含める変更を選び、`git commit` で履歴に確定します。

```bash
git add docs/practice/index.md
git status
```

✅ **チェックポイント**

```text
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        modified:   docs/practice/index.md
```

緑色の **Changes to be committed** に移動しました。コミットします。

```bash
git commit -m "docs: 練習ログに1行追加"
```

::: details 🔍 add した後に diff を見るには
`git add` した後に `git diff` を実行すると、何も表示されません。ステージ済みの差分を見るには `--staged`（または `--cached`）を付けます。

```bash
git diff --staged
```

:::

## ステップ 5：もう一周して履歴を作る

もう一度、練習ログにさらに 1 行追記して、2 つ目のコミットを作ります。

```bash
# エディタで docs/practice/index.md にもう1行追記してから:
git add docs/practice/index.md
git commit -m "docs: 練習ログにもう1行追加"
git log --oneline -3
```

✅ **チェックポイント**

自分が作った 2 つのコミットが、**履歴の先頭に乗っている**ことを確認します（その下は元からあるプロジェクトのコミット）。

```text
e4f5g6h (HEAD -> practice/basics) docs: 練習ログにもう1行追加
a1b2c3d docs: 練習ログに1行追加
5ac3fde build(vitepress): chunk size 警告を解消するため...
```

`HEAD -> practice/basics` は「いま practice/basics ブランチの最新にいる」ことを表します。

## ⚠️ つまずきポイント

::: warning add し忘れてコミットすると
`git add` していない変更は、コミットに含まれません。「コミットしたのに変更が反映されない」ときは、たいてい add 漏れです。`git status` で**緑色（ステージ済み）になっているか**を必ず確認しましょう。

`git commit` をメッセージなしで実行するとエディタが開きます。慣れないうちは `-m "メッセージ"` を付けると安全です。
:::

## まとめ

- 作業は必ず **`main` から切った作業ブランチ**で行う
- **`git add`（選ぶ）→ `git commit`（確定）** の 2 段階が基本
- `git status` で現在地、`git diff` で変更内容、`git log` で履歴を確認する

この add → commit のサイクルが、これ以降のすべての操作の土台になります。
