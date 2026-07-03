# コマンド早見表

日々のチーム開発でよく使うコマンドをまとめました。詳しい説明は各ページを参照してください。

## 設定

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --list                      # 設定の確認
```

## リポジトリ作成・取得

```bash
git init                               # 新規作成
git clone <url>                        # 複製
```

## 基本サイクル

```bash
git status                             # 状態確認
git diff                               # 変更差分（作業ツリー）
git diff --staged                      # 変更差分（ステージ）
git add <file>                         # ステージに追加
git add .                              # すべてステージ
git commit -m "メッセージ"             # コミット
git commit --amend                     # 直前のコミットを修正
git log --oneline --graph --all        # 履歴をグラフ表示
```

## ブランチ

```bash
git branch                             # 一覧
git switch -c <branch>                 # 作成して切り替え
git switch <branch>                    # 切り替え
git branch -d <branch>                 # 削除（マージ済み）
git branch -D <branch>                 # 強制削除
git merge <branch>                     # マージ
git merge --no-ff <branch>             # マージコミットを必ず作る
```

## リモート同期

```bash
git remote -v                          # リモート確認
git remote add origin <url>            # リモート追加
git fetch                              # 取得のみ
git pull                               # 取得 + 統合
git pull --rebase                      # 取得 + rebase
git push                               # 送信
git push -u origin <branch>            # 初回（上流設定）
git push origin --delete <branch>      # リモートブランチ削除
```

## rebase / 履歴整理

```bash
git rebase main                        # main の上に乗せ直す
git rebase -i HEAD~3                    # 直近3件を編集
git rebase --continue                  # コンフリクト解決後に続行
git rebase --abort                     # 中止
```

## 取り消し・復旧

```bash
git restore <file>                     # 作業ツリーの変更を破棄
git restore --staged <file>            # ステージから外す
git reset --soft HEAD~1                # 直前コミットを取り消し（変更は残す）
git reset --hard HEAD~1                # 直前コミットを取り消し（変更も破棄）
git revert <commit>                    # 打ち消しコミットを作成（安全）
git stash                              # 作業を一時退避
git stash pop                          # 退避した作業を戻す
git reflog                             # HEAD の移動履歴（救出用）
```

## GitHub CLI (`gh`)

```bash
gh pr create --fill                    # PR 作成
gh pr list                             # PR 一覧
gh pr checkout <number>                # PR をローカルにチェックアウト
gh pr view --web                       # PR をブラウザで開く
```

---

関連: [ガイドの歩き方](./)（全体像） / [トラブルシューティング](./troubleshooting)（「困った」の対処）
