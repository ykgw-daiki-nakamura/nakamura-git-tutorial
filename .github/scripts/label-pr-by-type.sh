#!/usr/bin/env bash
# PR タイトルの Conventional Commits type から対応ラベルを付与する。
# 対応表は .claude/checks.json の issueLabels.types（issue-label skill と単一ソース）。
#
# - 対応表（issueLabels.types）に無い type はスキップして成功終了。
# - 実在しないラベルは付けない（type: * ラベルは scripts/sync-labels.sh で用意する）。既存ラベルは消さず追加のみ。
# - タイトル・番号は環境変数（PR_TITLE / PR_NUMBER）で受け取り、run へ ${{ }} を直接展開しない。
set -euo pipefail

title="${PR_TITLE:-}"
pr="${PR_NUMBER:-}"
checks=".claude/checks.json"

if [ -z "$title" ] || [ -z "$pr" ]; then
  echo "PR タイトル/番号を取得できませんでした。スキップします。"
  exit 0
fi

# 先頭の type を取り出す（scope・破壊的変更 ! は無視）
type=$(printf '%s' "$title" | sed -nE 's/^([a-z]+)(\([^)]*\))?!?:.*/\1/p')
if [ -z "$type" ]; then
  echo "Conventional Commits 形式でないためスキップ: \"$title\""
  exit 0
fi

# checks.json の issueLabels.types で type→label を解決
label=""
if [ -f "$checks" ] && command -v jq >/dev/null 2>&1; then
  label=$(jq -r --arg t "$type" '(.issueLabels.types // {})[$t] // empty' "$checks" 2>/dev/null || true)
fi
if [ -z "$label" ]; then
  echo "type=$type に対応するラベルがありません（未対応 type）。スキップします。"
  exit 0
fi

# 実在ラベルのみ付与
if ! gh label list --limit 200 --json name --jq '.[].name' 2>/dev/null | grep -Fxq "$label"; then
  echo "ラベル '$label' がこのリポジトリに存在しません。スキップします。"
  exit 0
fi

echo "PR #$pr に '$label' を付与します（type=$type）。"
gh pr edit "$pr" --add-label "$label"
