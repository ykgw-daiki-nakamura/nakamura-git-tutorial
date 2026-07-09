#!/usr/bin/env bash
# PR タイトルが Conventional Commits に準拠しているか検証する。
# Squash Merge ではマージコミットメッセージ = PR タイトルになるため、main の履歴の一貫性を守る。
#
# 許可 type の出典は .github/conventions.json の commit.conventional.types（guard-commit.sh と同一・単一ソース）。
# jq / conventions.json が無い場合は既定 type にフォールバックする。
# タイトルは環境変数 PR_TITLE で受け取る（run へ ${{ }} を直接展開せずインジェクションを防ぐ）。
set -euo pipefail

title="${PR_TITLE:-}"
conventions=".github/conventions.json"

# guard-commit.sh と同じ既定 type
default_types="feat|fix|docs|chore|ci|build|refactor|test|perf|style|revert"
types=""
if [ -f "$conventions" ] && command -v jq >/dev/null 2>&1; then
  types=$(jq -r '(.commit.conventional.types // []) | join("|")' "$conventions" 2>/dev/null || true)
fi
[ -n "$types" ] || types="$default_types"

if [ -z "$title" ]; then
  echo "PR タイトルを取得できませんでした（PR_TITLE 未設定）。" >&2
  exit 1
fi

# guard-commit.sh と同じ subject 正規表現（scope 任意・破壊的変更 ! 可）
if printf '%s' "$title" | grep -Eq "^(${types})(\([^)]+\))?!?: .+"; then
  echo "OK: PR タイトルは Conventional Commits に準拠しています:"
  echo "  ${title}"
  exit 0
fi

{
  echo "NG: PR タイトルが Conventional Commits に準拠していません:"
  echo "  \"${title}\""
  echo
  echo "形式: type(scope): summary   （scope は任意、破壊的変更は type! も可）"
  echo "許可 type: ${types//|/, }"
  echo "例: feat(auth): ログイン失敗時のリトライを追加"
  echo
  echo "本リポジトリは Squash Merge のため、PR タイトルがそのまま main のコミットメッセージになります。"
  echo "タイトルを修正すると、この検証は自動で再実行されます。"
} >&2
exit 1
