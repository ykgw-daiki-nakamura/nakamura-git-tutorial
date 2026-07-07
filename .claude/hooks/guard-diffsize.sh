#!/usr/bin/env bash
# PreToolUse フック（非ブロッキング）: git push / gh pr create の直前に、ベースブランチ
# （既定 origin/main）との diff 行数（追加+削除）を測り、閾値超過なら「Issue/PR 分割を検討」
# と additionalContext で促す。**ブロックはしない**（exit 0）。
#
# 設計（既存フックの作法を踏襲）:
# - 設定は .claude/checks.json の guard.diffSize（maxLines 既定 400 / skipPaths / allow）から読む。
# - 生成物・ロックファイル等は skipPaths（パス接頭辞）で行数集計から除外。
# - allow（正規表現）に一致するコマンドは対象外。
# - 依存（git/jq）欠如・ベース取得不能・判定不能は fail-open（何もせず exit 0）。
set -uo pipefail

command -v git >/dev/null 2>&1 || exit 0
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
[ -n "$cmd" ] || exit 0

# 種別判定は skeleton（ヒアドキュメント本文・引用符内・コメントを除去）に対して行い、docs / skills /
# Issue 本文に書かれた "git push" 等の文字列で誤警告しないようにする（既存 guard と同じ作法）。
# node が無ければ原文にフォールバック。
skel=$(printf '%s' "$cmd" | node "$(dirname "${BASH_SOURCE[0]}")/lib/cmd-skeleton.js" 2>/dev/null)
[ -n "$skel" ] || skel="$cmd"

# 対象は push 系 / PR 作成のみ
printf '%s' "$skel" | grep -Eq '\bgit[[:space:]]+push\b|\bgh[[:space:]]+pr[[:space:]]+create\b' || exit 0

cd "$proj" 2>/dev/null || exit 0

# 設定読み取り（jq が無ければ既定値で続行）
maxLines=400
skip_res=""
allow_res=""
if [ -f "$checks" ]; then
  if command -v jq >/dev/null 2>&1; then
    v=$(jq -r '.guard.diffSize.maxLines // empty' "$checks" 2>/dev/null || true)
    [ -n "$v" ] && maxLines="$v"
    skip_res=$(jq -r '(.guard.diffSize.skipPaths // []) | .[]' "$checks" 2>/dev/null || true)
    allow_res=$(jq -r '(.guard.diffSize.allow // []) | .[]' "$checks" 2>/dev/null || true)
  elif command -v node >/dev/null 2>&1; then
    v=$(CHECKS="$checks" node -e 'try{const m=JSON.parse(require("fs").readFileSync(process.env.CHECKS,"utf8")).guard?.diffSize?.maxLines;if(m!=null)process.stdout.write(String(m))}catch(e){}')
    [ -n "$v" ] && maxLines="$v"
    skip_res=$(CHECKS="$checks" node -e 'try{((JSON.parse(require("fs").readFileSync(process.env.CHECKS,"utf8")).guard?.diffSize?.skipPaths)||[]).forEach(x=>console.log(x))}catch(e){}')
    allow_res=$(CHECKS="$checks" node -e 'try{((JSON.parse(require("fs").readFileSync(process.env.CHECKS,"utf8")).guard?.diffSize?.allow)||[]).forEach(x=>console.log(x))}catch(e){}')
  fi
fi

# allow に一致するコマンドは対象外
while IFS= read -r re; do
  [ -n "$re" ] || continue
  printf '%s' "$cmd" | grep -Eq -- "$re" && exit 0
done <<EOF
$allow_res
EOF

# ベースブランチ（origin/main）とのマージベースから HEAD までの diff 行数
base="origin/main"
git rev-parse --verify --quiet "$base" >/dev/null 2>&1 || exit 0
mb=$(git merge-base "$base" HEAD 2>/dev/null) || exit 0
[ -n "$mb" ] || exit 0

skips=$(printf '%s' "$skip_res" | tr '\n' '\036')  # awk へ RS 区切りで渡す
total=$(git diff --numstat "$mb"...HEAD 2>/dev/null | awk -F '\t' -v skips="$skips" '
  BEGIN { n = split(skips, S, "\036") }
  {
    a = $1; d = $2; p = $3         # numstat はタブ区切り。FS=タブでパスにスペースがあっても壊れない

    if (a == "-") next                       # バイナリは行数集計しない
    for (i = 1; i <= n; i++) { if (S[i] != "" && index(p, S[i]) == 1) next }  # skipPaths(接頭辞)除外
    sum += a + d
  }
  END { print sum + 0 }
')
[ -n "$total" ] || exit 0

# 閾値以下なら何もしない
[ "$total" -gt "$maxLines" ] 2>/dev/null || exit 0

ctx="差分サイズの注意喚起: origin/main との差分が約 ${total} 行（追加+削除）で、目安の ${maxLines} 行を超えています。1 PR ≒ 約 ${maxLines} 行を目安に、Issue/PR の分割（独立して着手・レビューできる単位）を検討してください。生成物・ロックファイルは skipPaths で除外済み。分割不要と判断したらこのまま進めて構いません（本フックは警告のみ・ブロックしません）。"
if command -v jq >/dev/null 2>&1; then
  jq -cn --arg ctx "$ctx" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$ctx}}'
elif command -v node >/dev/null 2>&1; then
  CTX="$ctx" node -e 'process.stdout.write(JSON.stringify({hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:process.env.CTX}}))'
fi
exit 0
