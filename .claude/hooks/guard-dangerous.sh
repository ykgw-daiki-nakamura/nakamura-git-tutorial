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
  printf '%s' "$cmd" | grep -Eq "$re" && exit 0
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
if printf '%s' "$cmd" | grep -Eq '\brm\b[^|;&]*(-[[:alnum:]]*r[[:alnum:]]*f|-[[:alnum:]]*f[[:alnum:]]*r|-r[[:alnum:]]*[[:space:]]+-f|-f[[:alnum:]]*[[:space:]]+-r)'; then
  if printf '%s' "$cmd" | grep -Eq '(^|[[:space:]])(/|~|\$HOME|\$\{HOME\})(/?\*)?([[:space:]]|$)' \
     || printf '%s' "$cmd" | grep -Eq -- '--no-preserve-root'; then
    block "ルート/ホーム近傍の再帰削除" "対象を具体的なサブディレクトリに限定する（例: rm -rf ./build）"
  fi
fi

# 2) 保護ブランチへの force push
if printf '%s' "$cmd" | grep -Eq '\bgit[[:space:]]+push\b' \
   && printf '%s' "$cmd" | grep -Eq -- '(--force([[:space:]]|=|$)|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
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
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    # コマンドに保護ブランチ名が現れる、または現在が保護ブランチ
    if printf '%s' "$cmd" | grep -Eq "(^|[[:space:]/])${p}([[:space:]]|:|$)" || [ "$cur" = "$p" ]; then
      block "保護ブランチ '$p' への force push" "共有履歴を壊す恐れがあります。通常の push か、対象ブランチを見直してください"
    fi
  done <<EOF
$protected
EOF
fi

# 3) 未検証スクリプトのパイプ実行（curl|wget ... | bash|sh）
if printf '%s' "$cmd" | grep -Eq '\b(curl|wget)\b[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh|zsh|dash)\b'; then
  block "ダウンロードしたスクリプトの直接実行（curl/wget | shell）" "一度ファイルに保存し内容を確認してから実行してください"
fi

# 4) git reset --hard（未コミット変更があり失われる場合のみ）
if printf '%s' "$cmd" | grep -Eq '\bgit[[:space:]]+reset\b[^|;&]*--hard\b'; then
  if [ -n "$(git -C "$proj" status --porcelain 2>/dev/null)" ]; then
    block "未コミット変更がある状態での git reset --hard（変更が失われます）" "必要な変更を git stash / commit で退避してから実行してください"
  fi
fi

exit 0
