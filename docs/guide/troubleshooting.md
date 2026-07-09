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

> [!WARNING]
> **reset --hard の前に**
>
> `--hard` は作業中の変更を**完全に破棄**します。本当に不要か確認してから実行しましょう。

## 公開済みのコミットを取り消したい

すでに push したコミットの直し方は 2 つあり、**そのブランチを他の人が参照しているか**で選びます。

### 既定: `revert` で打ち消す

`reset` で消すのではなく、**打ち消しコミットを作る**のが安全です。履歴を書き換えないため、他の人の手元と食い違いません。共有ブランチ・保護ブランチではこれ一択です。

```bash
git revert <commit>
git push
```

### 例外: 自分しか触っていないブランチなら書き換えてよい

まだレビューも取り込みもされていない、**自分専用の作業ブランチ**なら、コミットを直して履歴を差し替えられます。コミット ID が変わるので、通常の `push` は拒否されます。

```bash
git commit --amend          # 直前のコミットを直す
git push --force-with-lease # 履歴が変わるので force push が要る
```

`--force-with-lease` は「自分が知らないうちにリモートが更新されていたら中断する」安全な force push です。単なる `--force` は他人の push を上書きしかねないので使いません。

> [!CAUTION]
> **書き換えてはいけない場面**
>
> - **保護ブランチ**（`main` など） — このリポジトリでは `guard-dangerous` フックが保護ブランチへの force push を機械的に阻止します
> - **他の人が同じブランチで作業している** — 相手の次の `pull` で履歴が食い違います
> - **他の人が既にそのコミットを取り込んでいる**
>
> 判断が付かないなら `revert` を選んでください。取り消せる操作のほうが常に安全です。

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

### まだコミットしていない場合

stash で移動できます。

```bash
git stash
git switch correct-branch
git stash pop
```

### `main` に直接コミットしてしまった（まだ push していない）

実務でいちばん多い失敗です。**コミットは消さずに作業ブランチへ移し替え**、`main` をリモートの状態へ戻します。

```bash
# 1. いまの main の位置に作業ブランチを作る（コミットはここに残る）
git branch feature/x

# 2. main をリモートの状態まで巻き戻す
git reset --hard origin/main

# 3. 作業ブランチへ移動して、いつもどおり push → PR
git switch feature/x
```

> [!WARNING]
> **手順 2 の前に確認する**
>
> `git reset --hard` は未コミットの変更を破棄します。手順 1 で `feature/x` を作ってからでないと、コミットを見失います。仮に消してしまっても `git reflog` から救出できます。

すでに push してしまった場合は、`main` の履歴を書き換えず [`revert`](#公開済みのコミットを取り消したい) で打ち消します。

## push が拒否される (rejected)

リモートの**同じブランチ**が自分の手元より先に進んでいるサインです。まず上流ブランチ（通常 `origin/<現在のブランチ>`）を取り込みます。

```bash
git pull --no-rebase   # 上流ブランチを fetch + merge
# コンフリクトがあれば解決して
git push
```

> [!WARNING]
> **取り込む先を間違えない**
>
> 拒否の原因は「**現在のブランチの上流**が進んでいること」です。作業ブランチで拒否されたときに `origin/main` を merge しても解消しません（`main` にいるなら上流はそもそも `origin/main` です）。PR 画面の `Update branch` を押すと、リモートの作業ブランチが進んでこの状態になります。
>
> `--no-rebase` は、`pull.rebase` を設定している環境でも merge で取り込むための保険です。

## よくある状況と対処の早見表

| 状況 | 対処 |
| --- | --- |
| 編集を捨てたい（コミット前） | `git restore <file>` |
| ステージを取り消したい | `git restore --staged <file>` |
| 直前コミットを修正 | `git commit --amend` |
| コミットを取り消す（手元に残す） | `git reset --soft HEAD~1` |
| 公開済みコミットを打ち消す | `git revert <commit>` |
| 自分専用ブランチの公開済みコミットを直す | `git commit --amend` → `git push --force-with-lease` |
| `main` に直接コミットした（未 push） | `git branch feature/x` → `git reset --hard origin/main` → `git switch feature/x` |
| 作業を一時退避 | `git stash` / `git stash pop` |
| 消したコミット/ブランチを復元 | `git reflog` から救出 |
| push が rejected | `git pull --no-rebase`（上流ブランチを取り込む）してから push |

困ったら、まず `git status` と `git reflog` で現状を把握することが解決への近道です。

---

関連: [コマンド早見表](./commands)（コマンドの逆引き）
