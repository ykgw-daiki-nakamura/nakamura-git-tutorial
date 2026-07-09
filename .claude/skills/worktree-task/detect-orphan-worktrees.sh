#!/usr/bin/env bash
# マージ済み PR に対応する「孤立 worktree」を検出して列挙する（読み取り専用・削除はしない）。
#
# squash / rebase マージは PR ブランチの tip が origin/main の祖先にならないため、
# `git branch --merged` だけでは取りこぼす。複数シグナルで保守的に判定する:
#   1) 対応 PR が MERGED（gh pr list --head <branch> --state all）… 最も強いシグナル
#   2) origin/main にマージ済み（git branch --merged origin/main）… fast-forward/通常マージ
#   3) 対応 PR が CLOSED（未マージ）… 破棄済みの可能性。候補として提示（要確認）
#
# 保護（孤立扱いにしない）: 現在チェックアウト中の main ワークツリー・保護ブランチ（main）・
# **未コミット変更がある worktree**・PR が OPEN のもの・**origin/main から切ったばかりのブランチ**。
#
# 最後のものが要るのは、`git branch --merged origin/main` が「tip が origin/main の祖先」の
# ブランチをすべて列挙するため。切りたてのブランチは tip が origin/main そのものなので、
# 何もしていないのに「マージ済み」に見える。origin/main に対する ahead が 0 で、かつ MERGED な
# PR も無いブランチは撤去候補にしない（着手直後の worktree を消す方が痛い）。
#
# 依存（git/gh）が無い、または判定不能なときは fail-open（対象に含めない）。
set -uo pipefail

command -v git >/dev/null 2>&1 || exit 0
proj="${CLAUDE_PROJECT_DIR:-}"
[ -n "$proj" ] || proj="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

have_gh=0
command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && have_gh=1

# origin/main のマージ済みブランチ集合（fast-forward/通常マージ用）
merged_list=$(git -C "$proj" branch --merged origin/main --format '%(refname:short)' 2>/dev/null || true)

orphans=0
protected=0

# worktree list を解析（worktree <path> … branch refs/heads/<name>）
wt=""; br=""
emit() { # $1 path, $2 branch
  local path="$1" branch="$2"
  [ -n "$branch" ] || return 0                      # detached はスキップ
  case "$branch" in main|master) return 0 ;; esac   # 保護ブランチ
  [ "$path" = "$proj" ] && return 0                 # メイン作業ツリー本体

  # 未コミット変更がある worktree は保護（削除候補にしない）
  if [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then
    printf 'PROTECT\t%s\t%s\t未コミット変更あり（退避してから手動対応）\n' "$path" "$branch"
    protected=$((protected+1)); return 0
  fi

  # origin/main に対する独自コミット数。`git branch --merged origin/main` は
  # 「tip が origin/main の祖先」のブランチを列挙するので、**origin/main から切ったばかりで
  # まだ 1 コミットも積んでいないブランチも無条件に「マージ済み」に見える**。ahead で切り分ける。
  local ahead
  ahead=$(git -C "$proj" rev-list --count "origin/main..$branch" 2>/dev/null || true)

  local reason="" state="" num=""
  if [ "$have_gh" = 1 ]; then
    # state と number は 1 回の gh 呼び出しから取り出す（API 回数削減・両者の整合を担保）
    local pr_json
    pr_json=$(gh pr list --head "$branch" --state all --json state,number --jq '.[0] // {}' 2>/dev/null || true)
    state=$(printf '%s' "$pr_json" | jq -r '.state // ""' 2>/dev/null || true)
    num=$(printf '%s' "$pr_json" | jq -r '.number // ""' 2>/dev/null || true)
    [ "$state" = "OPEN" ] && return 0                # 進行中は保護
  fi

  # MERGED な PR は最も強いシグナルなので ahead に関わらず孤立と判定する
  # （squash / rebase マージ済みブランチは ahead > 0 のまま残るため、ここで従来どおり拾える）。
  if [ "$state" = "MERGED" ]; then
    reason="PR #${num} が MERGED"
  elif [ "$ahead" = "0" ]; then
    # ahead=0 かつ MERGED な PR が無い。「切ったばかり」なのか「通常マージで取り込まれた」のかを
    # この情報だけでは区別できない。着手直後の worktree を消す方が痛いので保護側に倒す。
    # gh が無い・未認証の環境も PR シグナルを取れないためここに落ちる（安全側）。
    printf 'PROTECT\t%s\t%s\t作りたて（origin/main と同一・マージ済み PR 無し）\n' "$path" "$branch"
    protected=$((protected+1)); return 0
  elif [ "$state" = "CLOSED" ]; then
    reason="PR #${num} が CLOSED（未マージ・要確認）"
  elif printf '%s\n' "$merged_list" | grep -Fxq "$branch"; then
    reason="origin/main にマージ済み"
  fi

  [ -n "$reason" ] || return 0                       # マージ判定できなければ残す（fail-open）
  printf 'ORPHAN\t%s\t%s\t%s\n' "$path" "$branch" "$reason"
  orphans=$((orphans+1))
}

while IFS= read -r line; do
  case "$line" in
    "worktree "*) wt="${line#worktree }"; br="" ;;
    "branch refs/heads/"*) br="${line#branch refs/heads/}" ;;
    "detached") br="" ;;
    "") emit "$wt" "$br"; wt=""; br="" ;;
  esac
done < <(git -C "$proj" worktree list --porcelain 2>/dev/null; printf '\n')

echo "---"
echo "孤立 worktree: ${orphans} 件 / 保護: ${protected} 件（未コミット変更あり・作りたて）"
if [ "$orphans" -gt 0 ]; then
  echo "撤去は確認の上で（メイン作業ツリーから）:"
  echo "  git -C \"$proj\" worktree remove <path> && git -C \"$proj\" branch -D <branch>"
fi
exit 0
