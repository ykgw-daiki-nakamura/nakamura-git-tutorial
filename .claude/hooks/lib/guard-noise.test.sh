#!/usr/bin/env bash
# 回帰テスト（#116）: guard 群が「ヒアドキュメント本文・引用符内・コメント」に含まれる
# コマンド文字列を実コマンドと誤判定して過剰ブロックしないこと、かつ実際のコマンド
# （引用符付きの危険引数を含む）は従来どおり検知することを確認する。
#
# 実行: bash .claude/hooks/lib/guard-noise.test.sh
# 全 PASS で exit 0、1 件でも FAIL なら exit 1。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS="$(dirname "$HERE")"
PROJ="$(cd "$HOOKS/../.." && pwd)"
export CLAUDE_PROJECT_DIR="$PROJ"

command -v node >/dev/null 2>&1 || { echo "SKIP: node 不在（スケルトン判定不可・fail-open 前提）"; exit 0; }

# 実コマンド語はリテラルで書くと本リポジトリ自身の guard に誤ブロックされるため変数化する
G="git"; INIT="init"; CF="config"; C="commit"; P="push"; A="add"; RM="rm"; RF="-rf"

# --- 前提セットアップは失敗を即検知する（set -e） ---
set -e
TD="$(mktemp -d)"
trap '"$RM" "$RF" "$TD"' EXIT
"$G" -C "$TD" "$INIT" -q -b main 2>/dev/null || { "$G" -C "$TD" "$INIT" -q; "$G" -C "$TD" checkout -q -b main; }
"$G" -C "$TD" "$CF" user.email t@example.com
"$G" -C "$TD" "$CF" user.name tester
"$G" -C "$TD" "$C" -q --allow-empty -m init
set +e

pass=0; fail=0
run() { # $1 説明  $2 guardファイル名  $3 期待exit  $4 コマンド文字列
  local desc="$1" guard="$2" want="$3" cmd="$4" json got
  json=$(CMD="$cmd" node -e 'process.stdout.write(JSON.stringify({tool_input:{command:process.env.CMD}}))')
  printf '%s' "$json" | bash "$HOOKS/$guard" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$want" ]; then pass=$((pass+1)); printf '  PASS [%s] %s (exit %s)\n' "$guard" "$desc" "$got"
  else fail=$((fail+1)); printf '  FAIL [%s] %s (want %s got %s)\n' "$guard" "$desc" "$want" "$got"; fi
}

# ファイルを書くだけの heredoc（本文に対象コマンド語を含む）
HD="$(printf 'cat > /tmp/gn_body.md <<%sDOC%s\n%s %s / %s %s / %s %s / を書く\nDOC' "'" "'" "$G" "$P" "$G" "$C" "$RM" "$RF")"
# 引用符内に <<EOF を含み、その後に実コマンドが続く（heredoc 誤認のすり抜け検証）
QHERE="$(printf 'echo "<<EOF"\n%s %s /\nEOF' "$RM" "$RF")"

echo "== guard-branch =="
run "heredoc 本文の push は素通り"          guard-branch.sh 0 "$HD"
run "引用文字列内の push は素通り"           guard-branch.sh 0 "echo \"$G $P origin main\""
run "保護ブランチ上の実 commit は阻止"       guard-branch.sh 2 "$G -C $TD $C -m x"
run "保護ブランチ上の実 push は阻止"         guard-branch.sh 2 "$G -C $TD $P origin main"
run "区切り直後コメント内の push は素通り"    guard-branch.sh 0 "echo hi ;# $G $P origin main"

echo "== guard-commit =="
run "heredoc 本文の commit は素通り"         guard-commit.sh 0 "$HD"
run "引用内の commit は素通り"               guard-commit.sh 0 "echo \"$G $C -m bad\""
run "実コミット・非準拠は阻止"               guard-commit.sh 2 "$G $C -m \"bad message\""
run "実コミット・準拠は素通り"               guard-commit.sh 0 "$G $C -m \"feat: ok\""

echo "== guard-dangerous =="
run "heredoc 本文の危険削除は素通り"          guard-dangerous.sh 0 "$HD"
run "引用内の危険削除文字列は素通り"          guard-dangerous.sh 0 "echo \"$RM $RF /\""
run "実 危険削除は阻止"                      guard-dangerous.sh 2 "$RM $RF /"
run "引用符付き引数の実 危険削除も阻止"       guard-dangerous.sh 2 "$RM $RF \"/\""
run "引用内 <<EOF 誤認で実コマンドを見逃さない" guard-dangerous.sh 2 "$QHERE"
run "区切り直後コメント内の危険削除は素通り"  guard-dangerous.sh 0 "echo hi ;# $RM $RF /"

echo "== guard-secrets =="
run "heredoc 本文の add は素通り"            guard-secrets.sh 0 "$HD"

echo ""
echo "結果: PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
