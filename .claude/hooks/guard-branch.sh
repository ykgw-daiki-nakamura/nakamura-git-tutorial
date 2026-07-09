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
skel="$cmd"
if command -v node >/dev/null 2>&1; then
  _s=$(printf '%s' "$cmd" | node "$(dirname "${BASH_SOURCE[0]}")/lib/cmd-skeleton.js" 2>/dev/null)
  [ -n "$_s" ] && skel="$_s"
fi

# git commit / git push 以外は対象外。種別判定はスケルトンに対して行う。
# `git -C <dir> commit` のように git とサブコマンドの間に -C オプションが入る形も検出する
# （従来の単純な "git commit" 部分一致では -C 付きを取りこぼし、保護が素通りしていた）。
op=""
gitpfx='git([[:space:]]+-C[[:space:]]+("[^"]*"|'\''[^'\'']*'\''|[^[:space:]]+))?'
if   [[ "$skel" =~ ${gitpfx}[[:space:]]+commit([[:space:]]|$) ]]; then op="commit"
elif [[ "$skel" =~ ${gitpfx}[[:space:]]+push([[:space:]]|$) ]];   then op="push"
else exit 0
fi

# コミット/プッシュの対象ディレクトリ（worktree 対応）を共通ヘルパで推定する。
# `git -C <dir>` / `cd <dir>` を解決し、git 作業ツリーでなければ $proj にフォールバック。
. "$(dirname "${BASH_SOURCE[0]}")/lib/target-dir.sh"
target=$(resolve_target_dir "$cmd" "$proj")

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

is_protected() {
  local name="$1" p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ "$name" = "$p" ] && return 0
  done <<EOF
$protected
EOF
  return 1
}

# `git push --delete <remote> <ref>...` はブランチの削除であって「保護ブランチへの直接 push」
# ではない。現在ブランチではなく **削除対象** で判定し、保護ブランチでなければ許可する
# （squash マージ後に残ったリモートブランチを main から片付けられるようにする）。
# 削除対象を特定できない場合は下の従来判定にフォールバックする（安全側）。
if [ "$op" = "push" ]; then
  # 種別はスケルトンで判定済み。ブランチ名の抽出は原文（$cmd）から行う。
  # 後続の連結コマンド（&& / ; / |）は push の引数ではないので切り落とす。
  args="${cmd#*push}"
  args="${args%%&&*}"; args="${args%%;*}"; args="${args%%|*}"
  read -ra _toks <<<"$args"
  is_delete=0
  refs=()
  for t in ${_toks[@]+"${_toks[@]}"}; do
    case "$t" in
      --delete|-d) is_delete=1 ;;
      -*) : ;;               # その他のオプションは対象外
      *) refs+=("$t") ;;     # refs[0] はリモート名、以降が refspec
    esac
  done
  if [ "$is_delete" -eq 1 ] && [ "${#refs[@]}" -ge 2 ]; then
    for r in "${refs[@]:1}"; do
      r="${r%\"}"; r="${r#\"}"; r="${r%\'}"; r="${r#\'}"   # 引用符を剥がす
      r="${r##*:}"                                          # `src:dst` の dst が削除対象
      r="${r#refs/heads/}"
      if is_protected "$r"; then
        {
          echo "保護ブランチ '$r' の削除は禁止です。"
          echo "削除してよいのは作業用ブランチだけです（例: git push origin --delete feat/xxx）。"
        } >&2
        exit 2
      fi
    done
    exit 0   # 削除対象はすべて非保護ブランチ → 現在ブランチが main でも許可
  fi
fi

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
