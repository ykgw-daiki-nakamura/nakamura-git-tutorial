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

# 種別判定用スケルトン（ヒアドキュメント本文・引用符内・コメントを除去した文字列）。
# docs / skills / Issue 本文に書かれた git コマンド文字列の誤ヒットを防ぐ。得られない
# 場合（node 無し等）は原文にフォールバックする（従来どおり＝安全側）。
skel=$(printf '%s' "$cmd" | node "$(dirname "${BASH_SOURCE[0]}")/lib/cmd-skeleton.js" 2>/dev/null)
[ -n "$skel" ] || skel="$cmd"

# git commit / git push 以外は対象外。種別判定はスケルトンに対して行う。
# `git -C <dir> commit` のように git とサブコマンドの間に -C オプションが入る形も検出する
# （従来の単純な "git commit" 部分一致では -C 付きを取りこぼし、保護が素通りしていた）。
op=""
gitpfx='git([[:space:]]+-C[[:space:]]+("[^"]*"|'\''[^'\'']*'\''|[^[:space:]]+))?'
if   [[ "$skel" =~ ${gitpfx}[[:space:]]+commit([[:space:]]|$) ]]; then op="commit"
elif [[ "$skel" =~ ${gitpfx}[[:space:]]+push([[:space:]]|$) ]];   then op="push"
else exit 0
fi

# コミット/プッシュの対象ディレクトリを推定する。
# worktree 運用では実際の作業ブランチは対象 worktree 側にあり、$proj（メイン作業
# ツリー）は常に main のことが多い。コマンド中の `git -C <dir>` または先頭付近の
# `cd <dir>` を優先して解決し、見つからなければ $proj にフォールバックする。
# 引用符（" / '）で囲まれた空白入りパスも取りこぼさないよう、引用の有無ごとに判定する。
target="$proj"
if   [[ "$cmd" =~ git[[:space:]]+-C[[:space:]]+\"([^\"]+)\" ]]; then target="${BASH_REMATCH[1]}"
elif [[ "$cmd" =~ git[[:space:]]+-C[[:space:]]+\'([^\']+)\' ]]; then target="${BASH_REMATCH[1]}"
elif [[ "$cmd" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then target="${BASH_REMATCH[1]}"
elif [[ "$cmd" =~ (^|[\;\&\|][[:space:]]*)cd[[:space:]]+\"([^\"]+)\" ]]; then target="${BASH_REMATCH[2]}"
elif [[ "$cmd" =~ (^|[\;\&\|][[:space:]]*)cd[[:space:]]+\'([^\']+)\' ]]; then target="${BASH_REMATCH[2]}"
elif [[ "$cmd" =~ (^|[\;\&\|][[:space:]]*)cd[[:space:]]+([^[:space:]\;\&\|]+) ]]; then target="${BASH_REMATCH[2]}"
fi

# 解決した対象が git 作業ツリーでなければ $proj にフォールバックする。
# （抽出ミスや存在しないパスで保護判定がスキップされるのを防ぐ。真の非 git は後段で fail-open）
git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1 || target="$proj"

# 現在ブランチ（detached HEAD や非 git は fail-open）
branch=$(git -C "$target" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
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
