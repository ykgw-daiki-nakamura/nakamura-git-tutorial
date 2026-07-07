#!/usr/bin/env bash
# .claude/hooks/lib/*.test.sh（guard フック等の回帰テスト）を順に実行する CI 用ランナー。
# 1 件でも失敗したら exit 1。テストが無ければ no-op（exit 0）。
#
# 実行: npm run test:hooks / bash scripts/test-hooks.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
shopt -s nullglob
tests=("$root"/.claude/hooks/lib/*.test.sh)

if [ "${#tests[@]}" -eq 0 ]; then
  echo "フックテストが見つかりません（.claude/hooks/lib/*.test.sh）。スキップします。"
  exit 0
fi

fail=0
for t in "${tests[@]}"; do
  echo "== $(basename "$t") =="
  if ! bash "$t"; then
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "全フックテスト PASS"
else
  echo "フックテストに失敗があります"
fi
exit "$fail"
