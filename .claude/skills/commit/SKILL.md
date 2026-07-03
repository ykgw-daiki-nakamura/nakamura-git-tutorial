---
name: commit
description: >-
  ステージ済みの差分から Conventional Commits 準拠のメッセージを生成し、提出前チェック
  （lint / build）を通してからコミットする skill。保護ブランチ（既定 main）上では直接
  コミットせずブランチ作成を促す。type 一覧・保護ブランチ名は checks.json があれば読む。
  「コミットして」「ステージした変更をコミット」「Conventional Commit を作って」等で使う。
  Generate a Conventional Commits message from staged changes, run pre-submit checks, then commit.
---

# commit — Conventional Commits でコミットする

ステージ済みの差分を要約して `type(scope): summary` 形式のメッセージを組み立て、
提出前チェックを通してからコミットする skill。GitHub Flow を外れないよう、保護ブランチ上での
直接コミットは避ける。他プロジェクトでも使える汎用設計（`~/.claude/skills` に置いてもよい）。

## 引数

`args` は自由記述。以下を読み取る（省略時は解決）。

- **type / scope** — 明示されていればそれを使う。無ければ差分から推定する。
- **保護ブランチ** — 直接コミットを避けるブランチ。省略時は checks.json の `protectedBranches`、
  無ければ既定 `main`。

## 手順

### 1. 前提を確認

```bash
git branch --show-current          # 保護ブランチ上なら中止してブランチ作成を促す
git diff --cached --stat           # ステージ済み差分。空ならステージを促して中止
```

- **保護ブランチ（既定 `main`）上なら直接コミットしない。** `feat/` `fix/` `docs/` `chore/` `ci/`
  `refactor/` 等の接頭辞でブランチを切ってから行う（worktree-task を使うのが確実）。
- ステージが空なら、対象を `git add` するようユーザーに促す（勝手に全部 add しない）。

### 2. メッセージを組み立てる

- 差分から **type** を選ぶ: `feat` `fix` `docs` `chore` `ci` `build` `refactor` `test` `perf`
  `style` `revert`。checks.json に `commit.conventional.types` があればそれを優先。
- **scope** は変更の主対象（ディレクトリ／モジュール名）を簡潔に。無ければ省略可。
- 要約は**命令形で簡潔に**。本文が要るなら「なぜ」を数行で。破壊的変更は `type(scope)!:` と
  本文に `BREAKING CHANGE:` を書く。

```text
type(scope): 要約（命令形・簡潔）

<必要なら本文。何を・なぜ>
```

### 3. 形式を検証

生成したメッセージが Conventional Commits に合致するか確認する。

```bash
printf '%s' "$subject" | grep -Eq \
  '^(feat|fix|docs|chore|ci|build|refactor|test|perf|style|revert)(\([^)]+\))?!?: .+' \
  && echo OK || echo "NG: type を見直す"
```

### 4. 提出前チェック

変更内容に応じてローカル検査を通す（CI と同じ検証）。このリポジトリなら:

```bash
npm run lint:md      # Markdown を変更した場合
npm run docs:build   # docs / 設定を変更した場合
```

失敗したら修正してからコミットする。

### 5. コミット

```bash
git commit -m "type(scope): 要約"
# 本文を含める場合は -m を重ねるか heredoc を使う
```

- 署名（`Co-Authored-By` 等）はリポジトリの方針に従って付す。
- コミット後、続けて push / PR に進むなら [worktree-task](../worktree-task/SKILL.md) /
  [pr-desc](../pr-desc/SKILL.md) と接続する。

## 注意

- **保護ブランチへの直接コミットはしない。** 逸脱しそうなら中止してブランチ作成を促す。
- 機密（トークン・鍵・認証情報）を差分に含めない。含まれていればコミットせず報告する。
- ステージ内容はユーザーの意図に沿っているか確認する（無関係な変更を巻き込まない）。
