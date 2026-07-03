#!/usr/bin/env bash
# PreToolUse フック: シークレット（API キー・秘密鍵・.env 等）のコミット混入を阻止する。
# `git add` / `git commit` を対象に、ステージ内容とファイル名を走査して exit 2 で止める。
#
# 設計（既存 guard フックの作法を踏襲）:
# - `git commit`: ステージ差分（git diff --cached）の追加行とステージ済みファイル名を走査。
# - `git add <path...>`: コマンドで明示された既存ファイルを走査（内容＋ファイル名）。
#   `git add .` / `-A` のように対象を列挙できない場合は、commit 時の走査が最終防波堤になる。
# - 検出は高確度パターンに限定し、除外は checks.json の guard.secrets.allow（正規表現）で調整。
# - jq を優先し node にフォールバック。git 不在・入力なし等は fail-open（作業を止めない）。
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
[ -n "$cmd" ] || exit 0

# git add / git commit 以外は対象外
case "$cmd" in
  *"git add"*|*"git commit"*) ;;
  *) exit 0 ;;
esac

# 除外（allowlist）正規表現を checks.json から取得
allow_res=""
if [ -f "$checks" ]; then
  if command -v jq >/dev/null 2>&1; then
    allow_res=$(jq -r '(.guard.secrets.allow // []) | .[]' "$checks" 2>/dev/null)
  elif command -v node >/dev/null 2>&1; then
    allow_res=$(CHECKS="$checks" node -e 'try{((JSON.parse(require("fs").readFileSync(process.env.CHECKS,"utf8")).guard?.secrets?.allow)||[]).forEach(p=>console.log(p))}catch(e){}')
  fi
fi
is_allowed() { # $1 検査対象文字列 → allowlist に一致すれば 0
  local line="$1"
  while IFS= read -r re; do
    [ -n "$re" ] || continue
    printf '%s' "$line" | grep -Eq "$re" && return 0
  done <<EOF
$allow_res
EOF
  return 1
}

block() { # $1 種別, $2 該当箇所
  {
    echo "シークレットの混入を阻止しました: $1"
    [ -n "${2:-}" ] && echo "  該当: $2"
    echo "対応: 値を環境変数や Secrets Manager に移し、コミット対象から除外してください"
    echo "（.gitignore へ追加。既にステージ済みなら git restore --staged <file>）"
    echo "誤検知の場合は .claude/checks.json の guard.secrets.allow に正規表現を追加できます。"
  } >&2
  exit 2
}

# 秘匿ファイル名パターン（.env.example 等のサンプルは除外）
sensitive_name() { # $1 パス → 秘匿ファイル名なら 0
  local f="$1"
  case "$f" in
    *.env.example|*.env.sample|*.env.template|*.env.dist) return 1 ;;
  esac
  printf '%s' "$f" | grep -Eq \
    '(^|/)\.env(\.[A-Za-z0-9_]+)?$|(^|/)(id_rsa|id_dsa|id_ecdsa|id_ed25519)$|\.(pem|pfx|p12|key|keystore|jks)$|(^|/)(credentials|\.pgpass|\.netrc|\.npmrc)$'
}

# 追加行内の高確度シークレットパターン。マッチした行を返す（無ければ空）。
scan_secret_lines() { # $1: 走査テキスト → マッチ行を出力
  # ERE は (?i) 非対応のため grep -i で全体を大小無視にする（鍵接頭辞は実物が固定大小で FP 増は軽微）
  printf '%s\n' "$1" | grep -EnIi \
    -e '-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----' \
    -e 'AKIA[0-9A-Z]{16}' \
    -e 'gh[pousr]_[A-Za-z0-9]{36,}' \
    -e 'github_pat_[A-Za-z0-9_]{22,}' \
    -e 'xox[baprs]-[0-9A-Za-z-]{10,}' \
    -e 'AIza[0-9A-Za-z_-]{35}' \
    -e '(sk|rk)_live_[0-9A-Za-z]{20,}' \
    -e '(api[_-]?key|secret|token|password|passwd|access[_-]?key)["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9+/_-]{20,}' \
    2>/dev/null
}

report_content() { # $1 ソース表示名, $2 走査テキスト
  local src="$1" hit
  hit=$(scan_secret_lines "$2") || true
  [ -n "$hit" ] || return 0
  # パイプではなく here-doc で回すことで block の exit 2 が本体プロセスに効く
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    is_allowed "$line" && continue
    block "高エントロピー文字列/鍵らしき値（$src）" "$line"
  done <<EOF
$hit
EOF
}

if printf '%s' "$cmd" | grep -Eq '\bgit[[:space:]]+commit\b'; then
  # ステージ済みファイル名
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if sensitive_name "$f" && ! is_allowed "$f"; then
      block "秘匿ファイルのコミット" "$f"
    fi
  done < <(git -C "$proj" diff --cached --name-only 2>/dev/null)
  # ステージ済み追加行の内容
  staged_added=$(git -C "$proj" diff --cached -U0 2>/dev/null | grep -E '^\+' | grep -Ev '^\+\+\+')
  report_content "ステージ差分" "$staged_added"
fi

if printf '%s' "$cmd" | grep -Eq '\bgit[[:space:]]+add\b'; then
  # `git add` の後ろのパス引数（フラグ・オプションは除外）を走査
  args=$(printf '%s' "$cmd" | sed -E 's/.*\bgit[[:space:]]+add\b//')
  for tok in $args; do
    case "$tok" in
      -*) continue ;;        # フラグ
      .|--all|-A) continue ;; # 列挙不能（commit 時に走査）
    esac
    path="$proj/$tok"
    [ -f "$path" ] || path="$tok"
    [ -f "$path" ] || continue
    if sensitive_name "$tok" && ! is_allowed "$tok"; then
      block "秘匿ファイルの追加" "$tok"
    fi
    filecontent=$(cat "$path" 2>/dev/null)
    report_content "$tok" "$filecontent"
  done
fi

exit 0
