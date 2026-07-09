#!/usr/bin/env bash
# 回帰テスト（#311）: detect-orphan-worktrees.sh が
#   - origin/main から切ったばかりのブランチを ORPHAN と誤判定しないこと
#   - squash マージ済み（ahead > 0・PR が MERGED）は従来どおり ORPHAN として拾えること
#   - 未コミット変更がある worktree を保護すること
#   - gh が使えない環境では ahead=0 のブランチを ORPHAN にしないこと（安全側）
# を確認する。
#
# 実行: bash .claude/hooks/lib/orphan-detect.test.sh
# 全 PASS で exit 0、1 件でも FAIL なら exit 1。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
SCRIPT="$REPO/.claude/skills/worktree-task/detect-orphan-worktrees.sh"

command -v git >/dev/null 2>&1 || { echo "SKIP: git 不在"; exit 0; }
command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq 不在（gh スタブの解釈に使う）"; exit 0; }

pass=0; fail=0
check() { # $1 説明  $2 出力に現れるべき正規表現  $3 実際の出力
  if printf '%s' "$3" | grep -Eq "$2"; then
    pass=$((pass+1)); printf '  PASS %s\n' "$1"
  else
    fail=$((fail+1)); printf '  FAIL %s\n    期待（一致）: %s\n    実際:\n%s\n' "$1" "$2" "$3"
  fi
}
refute() { # $1 説明  $2 出力に現れてはならない正規表現  $3 実際の出力
  if printf '%s' "$3" | grep -Eq "$2"; then
    fail=$((fail+1)); printf '  FAIL %s\n    期待（不一致）: %s\n    実際:\n%s\n' "$1" "$2" "$3"
  else
    pass=$((pass+1)); printf '  PASS %s\n' "$1"
  fi
}

set -e
TD="$(mktemp -d)"
trap 'chmod -R u+w "$TD" 2>/dev/null; command rm -rf "$TD"' EXIT

# --- upstream（origin 役）と作業リポジトリを用意 ---
UP="$TD/upstream.git"
git init -q --bare -b main "$UP"
WORK="$TD/work"
git clone -q "$UP" "$WORK" 2>/dev/null
git -C "$WORK" config user.email t@example.com
git -C "$WORK" config user.name tester
printf 'x\n' > "$WORK/a.txt"
git -C "$WORK" add a.txt
git -C "$WORK" commit -q -m "chore: init"
git -C "$WORK" push -q origin main
git -C "$WORK" fetch -q origin

# (a) 切りたてブランチ（ahead=0・コミット無し）
git -C "$WORK" worktree add -q -b feat/fresh "$TD/wt-fresh" origin/main

# (b) squash マージ済み相当（ahead>0・origin/main の祖先ではない）
git -C "$WORK" worktree add -q -b feat/merged "$TD/wt-merged" origin/main
printf 'y\n' > "$TD/wt-merged/b.txt"
git -C "$TD/wt-merged" add b.txt
git -C "$TD/wt-merged" commit -q -m "feat: work"

# (c) 未コミット変更あり（ahead>0）
git -C "$WORK" worktree add -q -b feat/dirty "$TD/wt-dirty" origin/main
printf 'z\n' > "$TD/wt-dirty/c.txt"
git -C "$TD/wt-dirty" add c.txt
git -C "$TD/wt-dirty" commit -q -m "feat: work"
printf 'dirty\n' >> "$TD/wt-dirty/c.txt"
set +e

# --- gh スタブ: feat/merged だけ MERGED な PR を返す ---
BIN="$TD/bin"; mkdir -p "$BIN"
cat > "$BIN/gh" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  auth) exit 0 ;;
  pr)
    for a in "$@"; do [ "$prev" = "--head" ] && head="$a"; prev="$a"; done
    if [ "${head:-}" = "feat/merged" ]; then echo '{"state":"MERGED","number":42}'
    else echo '{}'; fi
    exit 0 ;;
esac
exit 0
STUB
chmod +x "$BIN/gh"

echo "== gh あり（PR シグナルが取れる） =="
out=$(cd "$WORK" && PATH="$BIN:$PATH" CLAUDE_PROJECT_DIR="$WORK" bash "$SCRIPT" 2>&1)
check "切りたてブランチは PROTECT（作りたて）"    'PROTECT.*feat/fresh.*作りたて'                "$out"
check "squash マージ済みは ORPHAN"                'ORPHAN.*feat/merged.*PR #42 が MERGED'       "$out"
check "未コミット変更ありは PROTECT"              'PROTECT.*feat/dirty.*未コミット変更あり'      "$out"
refute "切りたてを ORPHAN として出さない"        'ORPHAN.*feat/fresh'                           "$out"

echo "== gh なし（PR シグナルが取れない → 安全側） =="
# gh だけを欠いた PATH を作る（スクリプト自身が使う実行ファイルは揃える）
NOGH="$TD/nogh"; mkdir -p "$NOGH"
for c in bash git jq grep sed cat env; do
  p=$(command -v "$c" 2>/dev/null) && ln -sf "$p" "$NOGH/$c" 2>/dev/null
done
out2=$(cd "$WORK" && PATH="$NOGH" CLAUDE_PROJECT_DIR="$WORK" bash "$SCRIPT" 2>&1)
check  "gh 不在でも切りたては PROTECT"            'PROTECT.*feat/fresh.*作りたて'                "$out2"
refute "gh 不在で切りたてを ORPHAN にしない"     'ORPHAN.*feat/fresh'                           "$out2"

echo ""
echo "結果: PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
