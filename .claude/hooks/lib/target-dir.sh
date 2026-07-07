#!/usr/bin/env bash
# guard 群の共通ヘルパ（source して使う）。
#
# コマンド文字列から、commit / push / add が **実際に走る作業ツリーのディレクトリ** を推定する。
# worktree 運用では実際の作業ブランチは対象 worktree 側にあり、$proj（メイン作業ツリー）は
# 常に main のことが多い。$proj 固定で判定すると、作業ブランチ上の正当な操作を「main 上」と
# 誤判定したり（guard-branch）、対象 worktree の index を見ずシークレットを取りこぼす（guard-secrets）。
#
# 解決順: コマンド中の `git -C <dir>` → 先頭付近の `cd <dir>`。相対パスは $proj 起点でも解決を試みる。
# git 作業ツリーとして解決できなければ $proj にフォールバックする（抽出ミスで保護がすり抜けない）。
#
# 使い方: . "<dir>/lib/target-dir.sh"; target=$(resolve_target_dir "$cmd" "$proj")
resolve_target_dir() {
  local cmd="$1" proj="$2" target="$2" cand=""
  if   [[ "$cmd" =~ git[[:space:]]+-C[[:space:]]+\"([^\"]+)\" ]]; then cand="${BASH_REMATCH[1]}"
  elif [[ "$cmd" =~ git[[:space:]]+-C[[:space:]]+\'([^\']+)\' ]]; then cand="${BASH_REMATCH[1]}"
  elif [[ "$cmd" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then cand="${BASH_REMATCH[1]}"
  elif [[ "$cmd" =~ (^|[\;\&\|][[:space:]]*)cd[[:space:]]+\"([^\"]+)\" ]]; then cand="${BASH_REMATCH[2]}"
  elif [[ "$cmd" =~ (^|[\;\&\|][[:space:]]*)cd[[:space:]]+\'([^\']+)\' ]]; then cand="${BASH_REMATCH[2]}"
  elif [[ "$cmd" =~ (^|[\;\&\|][[:space:]]*)cd[[:space:]]+([^[:space:]\;\&\|]+) ]]; then cand="${BASH_REMATCH[2]}"
  fi
  if [ -n "$cand" ]; then
    if   git -C "$cand" rev-parse --is-inside-work-tree >/dev/null 2>&1; then target="$cand"
    elif git -C "$proj/$cand" rev-parse --is-inside-work-tree >/dev/null 2>&1; then target="$proj/$cand"
    fi
  fi
  printf '%s' "$target"
}
