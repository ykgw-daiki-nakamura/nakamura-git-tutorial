#!/usr/bin/env bash
# PreToolUse フック: `git commit -m <msg>` のメッセージが Conventional Commits に
# 準拠しているか検証する。非準拠なら exit 2 で Claude にフィードバックする。
#
# 設計（既存フックの作法を踏襲）:
# - 許可 type 一覧は .claude/checks.json の commit.conventional.types から読む。無ければ既定。
# - リテラルの -m/--message メッセージのみ検証する。コマンド置換（`$(...)` / バッククォート）や
#   -F/--file、エディタ起動（-m 無し）は**内容を静的に判定できない**ため fail-open（スキップ）。
# - jq を優先し node にフォールバック。どちらも無ければ既定 type で検証する。
set -uo pipefail

input=$(cat)
proj="${CLAUDE_PROJECT_DIR:-.}"
checks="$proj/.claude/checks.json"

# tool_input.command を抽出
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
# 本文に書かれた `git commit` 文字列の誤ヒットを防ぐ。メッセージの抽出は後段で原文から行う。
skel="$cmd"
if command -v node >/dev/null 2>&1; then
  _s=$(printf '%s' "$cmd" | node "$(dirname "${BASH_SOURCE[0]}")/lib/cmd-skeleton.js" 2>/dev/null)
  [ -n "$_s" ] && skel="$_s"
fi

# `git commit` 以外は対象外。種別判定はスケルトンに対して行う。
# `git -C <dir> commit` のように git とサブコマンドの間に -C オプションが入る形も対象にする
# （従来の "git commit" 部分一致では -C 付きを取りこぼし、メッセージ検証がスキップされていた）。
gitpfx='git([[:space:]]+-C[[:space:]]+("[^"]*"|'\''[^'\'']*'\''|[^[:space:]]+))?'
[[ "$skel" =~ ${gitpfx}[[:space:]]+commit([[:space:]]|$) ]] || exit 0

# 最初の -m / --message の値を取り出す。-am のような短縮オプション束（末尾が m）も対象にする。
# 無ければ（エディタ起動や -F 等）検証不能 → fail-open。--amend 等は m の直後に区切りが
# 来ないためマッチしない（誤検知しない）。
# 複数行メッセージ（引用符が改行をまたぐ）にも対応するため node を優先で使う（文字クラスは
# 改行にマッチする）。node が無ければ行指向の grep にフォールバックする（1 行目 subject 検証には十分）。
if command -v node >/dev/null 2>&1; then
  msg=$(CMD="$cmd" node -e '
    const s=process.env.CMD||"";
    const m=s.match(/(?:--message|-[A-Za-z]*m)[= ]+("(?:[^"\\]|\\.)*"|\x27[^\x27]*\x27|[^\s]+)/);
    let out="";
    if(m){
      let v=m[1];
      if((v[0]==="\""&&v[v.length-1]==="\"")||(v[0]==="\x27"&&v[v.length-1]==="\x27")) v=v.slice(1,-1);
      out=v;
    }
    process.stdout.write(out);
  ')
else
  msg=$(printf '%s' "$cmd" | grep -oE "(--message|-[A-Za-z]*m)[= ]+('[^']*'|\"[^\"]*\"|[^[:space:]]+)" | head -n1 \
    | sed -E "s/^(--message|-[A-Za-z]*m)[= ]+//; s/^['\"]//; s/['\"]$//")
fi
[ -n "$msg" ] || exit 0

# コマンド置換を含む（= 実行時に生成される）メッセージは静的判定できない → fail-open
case "$msg" in
  *'$('*|*'`'*) exit 0 ;;
esac

# 許可 type 一覧を checks.json から取得（無ければ既定）
default_types="feat|fix|docs|chore|ci|build|refactor|test|perf|style|revert"
types=""
if [ -f "$checks" ]; then
  if command -v jq >/dev/null 2>&1; then
    types=$(jq -r '(.commit.conventional.types // []) | join("|")' "$checks" 2>/dev/null)
  elif command -v node >/dev/null 2>&1; then
    types=$(CHECKS="$checks" node -e 'try{const t=(JSON.parse(require("fs").readFileSync(process.env.CHECKS,"utf8")).commit?.conventional?.types)||[];process.stdout.write(t.join("|"))}catch(e){}')
  fi
fi
[ -n "$types" ] || types="$default_types"

# 1 行目（subject）を Conventional Commits 正規表現で検証
subject=${msg%%$'\n'*}
if printf '%s' "$subject" | grep -Eq "^(${types})(\([^)]+\))?!?: .+"; then
  exit 0
fi

{
  echo "コミットメッセージが Conventional Commits に準拠していません:"
  echo "  \"$subject\""
  echo "形式: type(scope): summary  （type: ${types//|/, }）"
  echo "例: feat(auth): ログイン失敗時のリトライを追加"
} >&2
exit 2
