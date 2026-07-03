#!/usr/bin/env bash
# PreToolUse フック: 保護ブランチ（既定 main）上での直接 commit / push を阻止する。
# GitHub Flow を外れて main に直接コミット／プッシュするのを防ぐ。
#
# 設計（既存フックの作法を踏襲）:
# - 保護ブランチ一覧は .claude/checks.json の protectedBranches から読む。無ければ既定 ["main"]。
# - 現在ブランチが保護対象で、対象コマンドが git commit / git push なら exit 2 で阻止する。
# - detached HEAD やブランチ判定不能時は fail-open（作業を止めない）。
set -uo pipefail

input=$(cat)
proj="${CLAUDE_PROJECT_DIR:-.}"
checks="$proj/.claude/checks.json"

extract_command() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null
    return 0
  fi
  if command -v node >/dev/null 2>&1; then
    printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(String(JSON.parse(s).tool_input?.command||""))}catch(e){}})'
  fi
}
cmd=$(extract_command)

# git commit / git push 以外は対象外
op=""
case "$cmd" in
  *"git commit"*) op="commit" ;;
  *"git push"*)   op="push" ;;
  *) exit 0 ;;
esac

# 現在ブランチ（detached HEAD や非 git は fail-open）
branch=$(git -C "$proj" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ -n "$branch" ] && [ "$branch" != "HEAD" ] || exit 0

# 保護ブランチ一覧（無ければ既定 main）
protected=""
if [ -f "$checks" ]; then
  if command -v jq >/dev/null 2>&1; then
    protected=$(jq -r '(.protectedBranches // []) | .[]' "$checks" 2>/dev/null)
  elif command -v node >/dev/null 2>&1; then
    protected=$(CHECKS="$checks" node -e 'try{((JSON.parse(require("fs").readFileSync(process.env.CHECKS,"utf8")).protectedBranches)||[]).forEach(b=>console.log(b))}catch(e){}')
  fi
fi
[ -n "$protected" ] || protected="main"

# 現在ブランチが保護対象なら阻止
while IFS= read -r p; do
  [ -n "$p" ] || continue
  if [ "$branch" = "$p" ]; then
    {
      echo "保護ブランチ '$branch' 上での直接 ${op} は禁止です（GitHub Flow）。"
      echo "作業用ブランチを切ってから行ってください:"
      echo "  git switch -c <type>/<summary>    # 例: feat/login-retry"
      echo "（.claude/skills/worktree-task を使うと Issue 化→ブランチ→PR を踏み外しません）"
    } >&2
    exit 2
  fi
done <<EOF
$protected
EOF

exit 0
