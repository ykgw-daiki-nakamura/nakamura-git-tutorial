#!/usr/bin/env bash
# PostToolUse フック: 編集された Markdown を markdownlint-cli2 で検査する。
# 違反があれば exit 2 で Claude にフィードバックし、CI(lint) 前に修正を促す。
#
# - .md 以外の編集では何もしない
# - 依存(markdownlint-cli2)が未インストールの環境では黙ってスキップ（作業を止めない）
# - リポジトリ直下の .markdownlint-cli2.jsonc 設定が自動適用される
set -uo pipefail

input=$(cat)

# tool_input.file_path を抽出する。jq を優先し、無ければ node にフォールバックする
# （jq 未導入の環境でフックが黙って無効化されるのを防ぐ）。
extract_file_path() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null
    return 0
  fi
  if command -v node >/dev/null 2>&1; then
    printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(String(JSON.parse(s).tool_input?.file_path||""))}catch(e){}})'
  fi
}
file=$(extract_file_path)

# .md 以外（またはパス抽出不可）は対象外
case "$file" in
  *.md) ;;
  *) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# markdownlint-cli2 の実体を解決する。見つかったものを直接実行し、
# 依存が無い環境（例: 依存未インストールの worktree）では黙ってスキップする。
if [ -x node_modules/.bin/markdownlint-cli2 ]; then
  linter=(node_modules/.bin/markdownlint-cli2)
elif command -v markdownlint-cli2 >/dev/null 2>&1; then
  linter=(markdownlint-cli2)
else
  exit 0
fi

if ! out=$("${linter[@]}" "$file" 2>&1); then
  {
    echo "markdownlint に違反があります（$file）。CI(lint) と同じ検査です。修正してください:"
    echo "$out"
  } >&2
  exit 2
fi
exit 0
