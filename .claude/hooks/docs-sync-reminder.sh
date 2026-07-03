#!/usr/bin/env bash
# PostToolUse フック: 構造ファイル（config.mjs 等）を編集したら、関連ドキュメントの
# 更新を促す注意喚起をモデルへ注入する（非ブロッキング。additionalContext を返す）。
#
# 設計（既存フックの作法を踏襲）:
# - 対応表は .claude/checks.json の docsSync（[{ glob, remind, label? }]）から読む。
# - 編集ファイルが glob に一致したら remind の文言を additionalContext として出力する。
# - 一致が無ければ何もしない。checks.json が無い / node も jq も無い → fail-open（exit 0）。
# - lint のような exit 2（ブロック）ではなく、あくまで「促し」に留める。
set -uo pipefail

input=$(cat)
proj="${CLAUDE_PROJECT_DIR:-.}"
checks="$proj/.claude/checks.json"

[ -f "$checks" ] || exit 0

extract_file_path() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null
    return 0
  fi
  if command -v node >/dev/null 2>&1; then
    printf '%s' "$input" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(String(JSON.parse(s).tool_input?.file_path||""))}catch(e){}})'
  fi
}
file=$(extract_file_path)
[ -n "$file" ] || exit 0

cd "$proj" || exit 0
# $proj プレフィックスを長さベースで安全に除去する（パラメータ展開の #pattern は
# $proj に glob 文字（* [ ] ?）が含まれると誤マッチするため使わない）。
# 境界が "/" のとき（= "$proj/..."）または file が $proj と完全一致のときだけ除去する。
# 例: proj="/tmp/proj" が file="/tmp/proj2/a" を誤って剥がさないようにする。
rel="$file"
plen=${#proj}
if [ "${file:0:plen}" = "$proj" ] && { [ "${#file}" -eq "$plen" ] || [ "${file:plen:1}" = "/" ]; }; then
  rel="${file:plen}"
fi
rel="${rel#/}"; rel="${rel#./}"

# 一致した docsSync エントリの remind 文言を集める（glob 照合は node があれば完全対応）
reminders() {
  if command -v node >/dev/null 2>&1; then
    CHECKS="$checks" FILE="$rel" node -e '
      const fs=require("fs");
      let cfg; try{cfg=JSON.parse(fs.readFileSync(process.env.CHECKS,"utf8"))}catch(e){process.exit(0)}
      const file=process.env.FILE;
      const toRe=(g)=>{let out="";for(let i=0;i<g.length;i++){const c=g[i];
        if(c==="*"){ if(g[i+1]==="*"){ if(g[i+2]==="/"){out+="(?:.*/)?";i+=2;}else{out+=".*";i+=1;} } else {out+="[^/]*";} }
        else if(c==="?"){out+="[^/]";}
        else {out+=c.replace(/[.+^${}()|[\]\\/]/g,"\\$&");}}
        return new RegExp("(^|/)"+out+"$");};
      for(const e of (Array.isArray(cfg.docsSync)?cfg.docsSync:[])){
        if(!e||!e.glob||!e.remind) continue;
        if(toRe(e.glob).test(file)) console.log(String(e.remind));
      }
    '
    return
  fi
  # node が無い環境: jq でエントリを取り出し、完全一致／末尾一致のみ照合する。
  # ワイルドカード（* ?）を含む glob は case で * が / も跨いで誤検知するため、
  # 保守的にスキップする（fail-open 優先。node があれば上の完全な glob 照合を使う）。
  command -v jq >/dev/null 2>&1 || return
  jq -r '.docsSync[]? | select(.glob and .remind) | "\(.glob)\t\(.remind)"' "$checks" 2>/dev/null |
  while IFS=$'\t' read -r glob remind; do
    case "$glob" in
      *'*'*|*'?'*) continue ;;
    esac
    case "$rel" in
      "$glob"|*"/$glob") printf '%s\n' "$remind" ;;
    esac
  done
}

msg=$(reminders)
[ -n "$msg" ] || exit 0

ctx="ドキュメント同期の確認: $msg"
if command -v jq >/dev/null 2>&1; then
  jq -cn --arg ctx "$ctx" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
elif command -v node >/dev/null 2>&1; then
  CTX="$ctx" node -e 'process.stdout.write(JSON.stringify({hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:process.env.CTX}}))'
fi
exit 0
