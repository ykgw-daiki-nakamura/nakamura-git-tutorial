#!/usr/bin/env bash
#
# sync-labels.sh — Conventional Commits の type に対応する GitHub ラベルを同期する。
#
# 用途:
#   コミット規約の各 type（feat / fix / docs …）に対応する `type: *` ラベルを、
#   このリポジトリに冪等に作成／更新する。type の一覧は .claude/checks.json の
#   `commit.conventional.types`（guard-commit.sh・pr-title.yml と同一ソース）を読む。
#   ラベル名は pr-label.yml / issue-label skill が参照する `issueLabels.types` の値と
#   一致する（例: feat → "type: feat"）。
#
# 使い方:
#   bash scripts/sync-labels.sh
#
# 冪等性:
#   `gh label create --force` を使うため、無ければ作成・有れば更新となる。
#   何度実行しても結果は同じ（既存の色・説明は上書きされる）。
#
# 依存:
#   gh（GitHub CLI・認証済み） / jq。いずれか無ければ明確なメッセージで終了する。
#
set -euo pipefail

# --- bash バージョン検査 ---------------------------------------------------
# 連想配列（declare -A）と mapfile を使うため bash 4 以上が必要。
# macOS 標準の bash 3.2 などでは即失敗するので、分かりやすく案内して終了する。
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  echo "エラー: このスクリプトは bash 4 以上が必要です（連想配列・mapfile を使用）。" >&2
  echo "  現在のバージョン: ${BASH_VERSION:-unknown}" >&2
  echo "  macOS 標準の bash 3.2 では動きません。'brew install bash' 等で bash 4+ を導入して実行してください。" >&2
  exit 1
fi

checks=".claude/checks.json"

# --- 依存チェック ---------------------------------------------------------
for cmd in gh jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "エラー: '$cmd' が見つかりません（gh CLI と jq が必要）。" >&2
    exit 1
  fi
done
if [ ! -f "$checks" ]; then
  echo "エラー: $checks が見つかりません。リポジトリ直下で実行してください。" >&2
  exit 1
fi

# --- type → 色・説明 の対応表 --------------------------------------------
# ラベル名は "type: <type>"。色は既存ラベル（bug/documentation/status: in-progress/
# harness 等）と被らないよう選んでいる。type 一覧そのものは checks.json を情報源にし、
# ここは各 type の見た目（色）と説明だけを持つ。
declare -A COLOR=(
  [feat]=0e8a16 [fix]=e11d21 [docs]=1d76db [chore]=cccccc [ci]=0e6aad
  [build]=c2a000 [refactor]=006b75 [test]=8250df [perf]=d93f0b
  [style]=d4c5f9 [revert]=b60205
)
declare -A DESC=(
  [feat]="新機能の追加"
  [fix]="バグ修正"
  [docs]="ドキュメントのみの変更"
  [chore]="雑務・補助（機能に影響しない変更）"
  [ci]="CI 設定・スクリプトの変更"
  [build]="ビルドシステム・依存関係の変更"
  [refactor]="挙動を変えないコード改善"
  [test]="テストの追加・修正"
  [perf]="パフォーマンス改善"
  [style]="書式のみの変更（空白・整形など）"
  [revert]="以前のコミットの取り消し"
)

# --- checks.json から type 一覧を読む ------------------------------------
mapfile -t types < <(jq -r '.commit.conventional.types[]?' "$checks")
if [ "${#types[@]}" -eq 0 ]; then
  echo "エラー: checks.json の commit.conventional.types が空です。" >&2
  exit 1
fi

# --- ドリフト検知: 対応表にしか無い type は警告に留める -------------------
for t in "${!COLOR[@]}"; do
  found=0
  for ct in "${types[@]}"; do [ "$t" = "$ct" ] && found=1 && break; done
  if [ "$found" -eq 0 ]; then
    echo "警告: 対応表の type '$t' は checks.json に無い（ラベルは作成しない）。" >&2
  fi
done

# --- ラベルを作成／更新 ---------------------------------------------------
rc=0
created=0
for t in "${types[@]}"; do
  color="${COLOR[$t]:-}"
  desc="${DESC[$t]:-}"
  # checks.json に有るのに対応表に無い type はエラー停止（ラベル取りこぼし防止）。
  if [ -z "$color" ] || [ -z "$desc" ]; then
    echo "エラー: type '$t' の色/説明が対応表にありません。scripts/sync-labels.sh を更新してください。" >&2
    rc=1
    continue
  fi
  label="type: $t"
  echo "同期: '$label' (#$color) — $desc"
  gh label create "$label" --color "$color" --description "$desc" --force
  created=$((created + 1))
done

if [ "$rc" -eq 0 ]; then
  echo "完了: ${created} 個の 'type: *' ラベルを同期しました。"
else
  echo "警告: 同期できなかった type があります（上のエラーを参照）。同期できたのは ${created} 個です。" >&2
fi
exit "$rc"
