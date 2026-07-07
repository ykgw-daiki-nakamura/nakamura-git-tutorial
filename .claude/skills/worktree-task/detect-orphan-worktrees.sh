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
# **未コミット変更がある worktree**・PR が OPEN のもの。
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

  local reason=""
  if [ "$have_gh" = 1 ]; then
    local state num
    state=$(gh pr list --head "$branch" --state all --json state,number --jq '.[0].state // ""' 2>/dev/null || true)
    num=$(gh pr list --head "$branch" --state all --json number --jq '.[0].number // ""' 2>/dev/null || true)
    case "$state" in
      MERGED) reason="PR #${num} が MERGED" ;;
      OPEN)   return 0 ;;                            # 進行中は保護
      CLOSED) reason="PR #${num} が CLOSED（未マージ・要確認）" ;;
    esac
  fi
  if [ -z "$reason" ] && printf '%s\n' "$merged_list" | grep -Fxq "$branch"; then
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
echo "孤立 worktree: ${orphans} 件 / 保護（未コミット変更）: ${protected} 件"
if [ "$orphans" -gt 0 ]; then
  echo "撤去は確認の上で（メイン作業ツリーから）:"
  echo "  git -C \"$proj\" worktree remove <path> && git -C \"$proj\" branch -D <branch>"
fi
exit 0
