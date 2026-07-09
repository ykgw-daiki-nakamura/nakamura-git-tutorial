# トラブルシューティング

「やってしまった」というときの復旧方法をまとめます。多くの操作は取り消せるので、落ち着いて対処しましょう。

## まず知っておくこと: reflog は命綱

`git reflog` は HEAD が動いたすべての履歴を記録しています。**「コミットを消してしまった」「ブランチを消した」** ようなときも、ここから救出できることが多いです。

```bash
git reflog
# 例: a1b2c3d HEAD@{2}: commit: 消したはずの作業
git switch -c recover a1b2c3d   # その時点を新しいブランチで復元
```

## コミット前の変更を取り消したい

```bash
# 特定ファイルの編集を破棄（コミット前）
git restore file.txt

# ステージしたが、まだコミットしていない → ステージから外す
git restore --staged file.txt
```

## 直前のコミットをやり直したい

```bash
# メッセージだけ直す / ファイルを追加し忘れた
git add forgotten.txt
git commit --amend

# コミットを取り消すが、変更内容は手元に残す
git reset --soft HEAD~1

# コミットも変更もすべて捨てる（要注意）
git reset --hard HEAD~1
```

::: warning reset --hard の前に
`--hard` は作業中の変更を**完全に破棄**します。本当に不要か確認してから実行しましょう。
:::

## 公開済みのコミットを取り消したい

すでに push した（チームが参照している）コミットは `reset` で消すのではなく、**`revert` で打ち消しコミットを作る**のが安全です。履歴を書き換えないため混乱を招きません。

```bash
git revert <commit>
git push
```

## 作業を中断して別の対応をしたい

コミットするほどではない作業を一時退避できます。

```bash
git stash              # 現在の変更を退避
git switch main        # 別のブランチで作業
# ...対応が終わったら戻る...
git switch feature/x
git stash pop          # 退避した変更を復元
```

## 間違ったブランチで作業してしまった

まだコミットしていなければ stash で移動できます。

```bash
git stash
git switch correct-branch
git stash pop
```

## push が拒否される (rejected)

リモートの**同じブランチ**が自分の手元より先に進んでいるサインです。まず上流ブランチ（通常 `origin/<現在のブランチ>`）を取り込みます。

```bash
git pull --no-rebase   # 上流ブランチを fetch + merge
# コンフリクトがあれば解決して
git push
```

::: warning 取り込む先を間違えない
拒否の原因は「**現在のブランチの上流**が進んでいること」です。作業ブランチで拒否されたときに `origin/main` を merge しても解消しません（`main` にいるなら上流はそもそも `origin/main` です）。PR 画面の `Update branch` を押すと、リモートの作業ブランチが進んでこの状態になります。

`--no-rebase` は、`pull.rebase` を設定している環境でも merge で取り込むための保険です。
:::

## よくある状況と対処の早見表

| 状況 | 対処 |
| --- | --- |
| 編集を捨てたい（コミット前） | `git restore <file>` |
| ステージを取り消したい | `git restore --staged <file>` |
| 直前コミットを修正 | `git commit --amend` |
| コミットを取り消す（手元に残す） | `git reset --soft HEAD~1` |
| 公開済みコミットを打ち消す | `git revert <commit>` |
| 作業を一時退避 | `git stash` / `git stash pop` |
| 消したコミット/ブランチを復元 | `git reflog` から救出 |
| push が rejected | `git pull --no-rebase`（上流ブランチを取り込む）してから push |

困ったら、まず `git status` と `git reflog` で現状を把握することが解決への近道です。

---

関連: [コマンド早見表](./commands)（コマンドの逆引き）
