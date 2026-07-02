#!/usr/bin/env bash
# PostToolUse フック: 編集された Markdown を markdownlint-cli2 で検査する。
# 違反があれば exit 2 で Claude にフィードバックし、CI(lint) 前に修正を促す。
#
# - .md 以外の編集では何もしない
# - 依存(markdownlint-cli2)が未インストールの環境では黙ってスキップ（作業を止めない）
# - リポジトリ直下の .markdownlint-cli2.jsonc 設定が自動適用される
set -uo pipefail

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# .md 以外は対象外
case "$file" in
  *.md) ;;
  *) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# 依存が無い環境ではスキップ（例: 依存未インストールの worktree）
if [ ! -x node_modules/.bin/markdownlint-cli2 ] && ! command -v markdownlint-cli2 >/dev/null 2>&1; then
  exit 0
fi

if ! out=$(npx --no-install markdownlint-cli2 "$file" 2>&1); then
  {
    echo "markdownlint に違反があります（$file）。CI(lint) と同じ検査です。修正してください:"
    echo "$out"
  } >&2
  exit 2
fi
exit 0
