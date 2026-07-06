#!/usr/bin/env bash
# PreToolUse フック: 明確に破壊的・危険なコマンドを exit 2 で阻止する。
# 誤検知で通常作業を止めないよう、高確度パターンに限定する。
#
# 対象:
# - ルート/ホーム近傍の再帰削除（rm -rf / , ~ , $HOME , --no-preserve-root）
# - 保護ブランチへの force push（--force / --force-with-lease）
# - 未検証スクリプトの実行（curl|wget ... | bash|sh）
# - git reset --hard（未コミット変更が存在して失われる場合のみ）
# 除外パターンは checks.json の guard.dangerous.allow（正規表現）で調整できる。
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

# 種別判定用スケルトン（ヒアドキュメント本文・引用符内・コメントを除去した文字列）。
# docs / skills / Issue 本文に書かれた危険コマンド文字列の誤ヒットを防ぐ。危険判定は skel に、
# ブランチ抽出・allowlist 照合は原文に対して行う。得られない場合は原文にフォールバック（安全側）。
skel=$(printf '%s' "$cmd" | node "$(dirname "${BASH_SOURCE[0]}")/lib/cmd-skeleton.js" 2>/dev/null)
[ -n "$skel" ] || skel="$cmd"

# ERE メタ文字をエスケープ（checks.json 由来のブランチ名を正規表現に埋める前に使う）
ere_escape() { printf '%s' "$1" | sed 's/[][(){}.^$*+?|\\]/\\&/g'; }

# 除外（allowlist）に一致したら通す
allow_res=""
if [ -f "$checks" ]; then
  if command -v jq >/dev/null 2>&1; then
    allow_res=$(jq -r '(.guard.dangerous.allow // []) | .[]' "$checks" 2>/dev/null)
  elif command -v node >/dev/null 2>&1; then
    allow_res=$(CHECKS="$checks" node -e 'try{((JSON.parse(require("fs").readFileSync(process.env.CHECKS,"utf8")).guard?.dangerous?.allow)||[]).forEach(p=>console.log(p))}catch(e){}')
  fi
fi
while IFS= read -r re; do
  [ -n "$re" ] || continue
  # `--` で `-` 始まりの正規表現がオプション扱いされるのを防ぐ
  printf '%s' "$cmd" | grep -Eq -- "$re" && exit 0
done <<EOF
$allow_res
EOF

block() { # $1 理由, $2 代替
  {
    echo "危険なコマンドを阻止しました: $1"
    [ -n "${2:-}" ] && echo "代替: $2"
    echo "（意図が正当なら、対象を限定した形に書き換えてください）"
  } >&2
  exit 2
}

# 1) ルート/ホーム近傍の再帰削除
# フラグは大小無視（-R は -r と等価、-F も同様）。末尾スラッシュ（/, ~/, $HOME/）も対象にする。
if printf '%s' "$skel" | grep -Eqi '\brm\b[^|;&]*(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|-r[a-z]*[[:space:]]+-f|-f[a-z]*[[:space:]]+-r)'; then
  if printf '%s' "$skel" | grep -Eq '(^|[[:space:]])(/|~|\$HOME|\$\{HOME\})/?(\*)?([[:space:]]|$)' \
     || printf '%s' "$skel" | grep -Eq -- '--no-preserve-root'; then
    block "ルート/ホーム近傍の再帰削除" "対象を具体的なサブディレクトリに限定する（例: rm -rf ./build）"
  fi
fi

# 2) 保護ブランチへの force push
if printf '%s' "$skel" | grep -Eq '\bgit[[:space:]]+push\b' \
   && printf '%s' "$skel" | grep -Eq -- '(--force([[:space:]]|=|$)|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
  # 保護ブランチ一覧（checks.json、無ければ main）
  protected=""
  if [ -f "$checks" ]; then
    if command -v jq >/dev/null 2>&1; then
      protected=$(jq -r '(.protectedBranches // ["main"]) | .[]' "$checks" 2>/dev/null)
    elif command -v node >/dev/null 2>&1; then
      protected=$(CHECKS="$checks" node -e 'try{((JSON.parse(require("fs").readFileSync(process.env.CHECKS,"utf8")).protectedBranches)||["main"]).forEach(b=>console.log(b))}catch(e){}')
    fi
  fi
  [ -n "$protected" ] || protected="main"
  cur=$(git -C "$proj" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  # `git push` 以降の明示ブランチ引数を抽出（先頭の非フラグ = リモート名は除く）。
  # 明示ブランチがある場合はそれが push 先。無い（bare push）場合のみ現在ブランチが push 先。
  push_args=$(printf '%s' "$cmd" | sed -E 's/.*\bgit[[:space:]]+push\b//')
  branch_args=""; remote_seen=0
  for tok in $push_args; do
    case "$tok" in -*) continue ;; esac        # フラグは除外
    if [ "$remote_seen" -eq 0 ]; then remote_seen=1; continue; fi  # 先頭非フラグ = リモート
    branch_args="$branch_args $tok"
  done
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    esc=$(ere_escape "$p")
    hit=0
    if [ -n "$branch_args" ]; then
      # 明示ブランチ（refspec の +src:dst や src:dst も考慮）に保護ブランチが現れるか
      printf '%s' "$branch_args" | grep -Eq "(^|[[:space:]:+/])${esc}([[:space:]:]|$)" && hit=1
    elif [ "$cur" = "$p" ]; then
      hit=1   # bare push（対象未指定）で現在ブランチが保護対象
    fi
    if [ "$hit" -eq 1 ]; then
      block "保護ブランチ '$p' への force push" "共有履歴を壊す恐れがあります。通常の push か、対象ブランチを見直してください"
    fi
  done <<EOF
$protected
EOF
fi

# 3) 未検証スクリプトのパイプ実行（curl|wget ... | bash|sh）
if printf '%s' "$skel" | grep -Eq '\b(curl|wget)\b[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh|zsh|dash)\b'; then
  block "ダウンロードしたスクリプトの直接実行（curl/wget | shell）" "一度ファイルに保存し内容を確認してから実行してください"
fi

# 4) git reset --hard（未コミット変更があり失われる場合のみ）
if printf '%s' "$skel" | grep -Eq '\bgit[[:space:]]+reset\b[^|;&]*--hard\b'; then
  if [ -n "$(git -C "$proj" status --porcelain 2>/dev/null)" ]; then
    block "未コミット変更がある状態での git reset --hard（変更が失われます）" "必要な変更を git stash / commit で退避してから実行してください"
  fi
fi

exit 0
