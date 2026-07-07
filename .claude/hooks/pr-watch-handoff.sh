#!/usr/bin/env bash
# PostToolUse フック: `gh pr create` の成功を検知したら、エージェントに
# pr-watch skill への移行を促す（additionalContext をモデルへ注入する）。
#
# - `gh pr create` 以外の Bash 実行では何もしない
# - 出力に PR URL が無い（作成失敗・ドライラン等）ときは何もしない
# - jq を優先し、無ければ node にフォールバック（jq 未導入で黙って無効化されるのを防ぐ）
set -uo pipefail

input=$(cat)

# tool_input.command を抽出
extract_command() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null
    return 0
  fi
  if command -v node >/dev/null 2>&1; then
    printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(String(JSON.parse(s).tool_input?.command||""))}catch(e){}})'
  fi
}

# tool_response を文字列化して抽出（PR URL 探索用）
extract_response() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r '.tool_response | if type=="string" then . else tojson end' 2>/dev/null
    return 0
  fi
  if command -v node >/dev/null 2>&1; then
    printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const r=JSON.parse(s).tool_response;process.stdout.write(typeof r==="string"?r:JSON.stringify(r||""))}catch(e){}})'
  fi
}

cmd=$(extract_command)

# `gh pr create` を含むコマンドのみ対象
case "$cmd" in
  *"gh pr create"*) ;;
  *) exit 0 ;;
esac

# 出力から作成された PR の URL を拾う。無ければ作成に至っていないので何もしない。
resp=$(extract_response)
url=$(printf '%s' "$resp" | grep -oE 'https://github\.com/[^ "]+/pull/[0-9]+' | head -n1)
[ -n "$url" ] || exit 0

ctx="PR ($url) を作成しました。【最優先の必須アクション】**いま直ちに pr-watch skill を起動し、この PR の監視を開始してください**（ScheduleWakeup で自走監視。レビュー指摘への対応＝インライン指摘は各スレッドへ個別返信、マージ後は連動 Issue の自動クローズ検証と worktree 片付けまで）。これは他の作業・要約・報告・ターン終了よりも優先します。**pr-watch を起動せずにこのターンを終えないこと。** 移行にユーザー確認は不要です。"
msg="PR を検知しました。最優先で pr-watch へ移行し監視を開始します。"

# JSON は必ずエスケープして組み立てる。jq を優先し、無ければ node の
# JSON.stringify にフォールバックする（printf の生埋め込みは " や改行で壊れるため使わない）。
# ここに到達する時点でコマンド抽出に成功している＝jq か node のいずれかは利用可能。
if command -v jq >/dev/null 2>&1; then
  jq -cn --arg ctx "$ctx" --arg msg "$msg" \
    '{systemMessage:$msg,hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
elif command -v node >/dev/null 2>&1; then
  MSG="$msg" CTX="$ctx" node -e 'process.stdout.write(JSON.stringify({systemMessage:process.env.MSG,hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:process.env.CTX}}))'
fi
exit 0
