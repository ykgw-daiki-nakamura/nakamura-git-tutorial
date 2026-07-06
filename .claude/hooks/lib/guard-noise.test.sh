#!/usr/bin/env bash
# 回帰テスト（#116）: guard 群が「ヒアドキュメント本文・引用符内・コメント」に含まれる
# git/rm 等のコマンド文字列を実コマンドと誤判定して過剰ブロックしないこと、
# かつ実際のコマンドは従来どおり検知することを確認する。
#
# 実行: bash .claude/hooks/lib/guard-noise.test.sh
# （全ケース PASS で exit 0、1 件でも FAIL なら exit 1）
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../.claude/hooks/lib
HOOKS="$(dirname "$HERE")"                             # .../.claude/hooks
PROJ="$(cd "$HOOKS/../.." && pwd)"                     # worktree ルート（checks.json を持つ）
export CLAUDE_PROJECT_DIR="$PROJ"

command -v node >/dev/null 2>&1 || { echo "SKIP: node が無いためスケルトン判定不可（fail-open 前提）"; exit 0; }

# 保護ブランチ（main）上の「実コマンド」検証用の一時 git リポジトリ
TD="$(mktemp -d)"
trap 'rm -rf "$TD"' EXIT
git -C "$TD" init -q -b main 2>/dev/null || { git -C "$TD" init -q; git -C "$TD" checkout -q -b main; }
git -C "$TD" config user.email t@example.com
git -C "$TD" config user.name tester
git -C "$TD" commit -q --allow-empty -m init

pass=0; fail=0
run() { # $1 説明  $2 guardファイル名  $3 期待exit  $4 コマンド文字列
  local desc="$1" guard="$2" want="$3" cmd="$4" json got
  json=$(CMD="$cmd" node -e 'process.stdout.write(JSON.stringify({tool_input:{command:process.env.CMD}}))')
  printf '%s' "$json" | bash "$HOOKS/$guard" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$want" ]; then pass=$((pass+1)); printf '  PASS [%s] %s (exit %s)\n' "$guard" "$desc" "$got"
  else fail=$((fail+1)); printf '  FAIL [%s] %s (want %s got %s)\n' "$guard" "$desc" "$want" "$got"; fi
}

# ヒアドキュメントでファイルを書くだけのコマンド（本文に危険/対象コマンド文字列を含む）
HD=$'cat > /tmp/gn_body.md <<\'DOC\'\n本文: git push / git commit / rm -rf / を書く\nDOC'

echo "== guard-branch =="
run "heredoc 本文の git push は素通り"      guard-branch.sh 0 "$HD"
run "引用文字列内の git push は素通り"        guard-branch.sh 0 'echo "git push origin main"'
run "保護ブランチ上の実 commit は阻止"       guard-branch.sh 2 "git -C $TD commit -m x"
run "保護ブランチ上の実 push は阻止"         guard-branch.sh 2 "git -C $TD push origin main"

echo "== guard-commit =="
run "heredoc 本文の git commit は素通り"     guard-commit.sh 0 "$HD"
run "引用内の git commit は素通り"           guard-commit.sh 0 'echo "git commit -m bad"'
run "実コミット・非準拠は阻止"               guard-commit.sh 2 'git commit -m "bad message"'
run "実コミット・準拠は素通り"               guard-commit.sh 0 'git commit -m "feat: ok"'

echo "== guard-dangerous =="
run "heredoc 本文の rm -rf / は素通り"       guard-dangerous.sh 0 "$HD"
run "引用内の rm -rf / は素通り"             guard-dangerous.sh 0 'echo "rm -rf /"'
run "実 rm -rf / は阻止"                     guard-dangerous.sh 2 'rm -rf /'

echo "== guard-secrets =="
run "heredoc 本文の git add は素通り"        guard-secrets.sh 0 "$HD"

echo ""
echo "結果: PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
