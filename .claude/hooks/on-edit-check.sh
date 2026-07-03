#!/usr/bin/env bash
# 汎用 PostToolUse フック: .claude/checks.json の宣言に従い、編集ファイルに
# 対応する検査コマンドを実行する。違反があれば exit 2 で Claude にフィードバックする。
#
# 設計:
# - 設定源は .claude/checks.json（onEdit: [{ glob, run, label? }]）。ロジックは本スクリプト、
#   プロジェクト固有の対応表は checks.json、と 2 層に分離する。
# - checks.json が無い / パースできない / 対応 glob が無い → 何もしない（exit 0）。
# - 検査コマンドが見つからない（exit 127）→ fail-open（依存未導入でも作業を止めない）。
# - glob 照合は node があれば完全対応、無ければ jq + 簡易照合にフォールバックする。
set -uo pipefail

input=$(cat)
proj="${CLAUDE_PROJECT_DIR:-.}"
checks="$proj/.claude/checks.json"

[ -f "$checks" ] || exit 0

# tool_input.file_path を抽出（jq 優先・node フォールバック。既存フックの作法を踏襲）
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

# 編集ファイルに一致する run コマンド（{file} 置換済み）を 1 行ずつ出力する
matched_commands() {
  if command -v node >/dev/null 2>&1; then
    CHECKS="$checks" FILE="$file" node -e '
      const fs=require("fs");
      let cfg; try{cfg=JSON.parse(fs.readFileSync(process.env.CHECKS,"utf8"))}catch(e){process.exit(0)}
      const file=process.env.FILE;
      const toRe=(g)=>{
        let out="";
        for(let i=0;i<g.length;i++){
          const c=g[i];
          if(c==="*"){
            if(g[i+1]==="*"){ if(g[i+2]==="/"){ out+="(?:.*/)?"; i+=2; } else { out+=".*"; i+=1; } }
            else { out+="[^/]*"; }
          } else if(c==="?"){ out+="[^/]"; }
          else { out+=c.replace(/[.+^${}()|[\]\\/]/g,"\\$&"); }
        }
        return new RegExp("(^|/)"+out+"$");
      };
      for(const e of (Array.isArray(cfg.onEdit)?cfg.onEdit:[])){
        if(!e||!e.glob||!e.run) continue;
        if(toRe(e.glob).test(file)) console.log(String(e.run).split("{file}").join(file));
      }
    '
    return
  fi
  # node が無い環境: jq でエントリを取り出し、簡易 glob 照合にフォールバックする
  command -v jq >/dev/null 2>&1 || return
  jq -r '.onEdit[]? | select(.glob and .run) | "\(.glob)\t\(.run)"' "$checks" 2>/dev/null |
  while IFS=$'\t' read -r glob run; do
    if simple_match "$file" "$glob"; then printf '%s\n' "${run//\{file\}/$file}"; fi
  done
}

# node 非搭載時の簡易照合。**/*.ext と *.ext と完全一致のみ対応し、
# それ以外の複雑な glob はスキップする（誤ブロックより fail-open を優先）。
simple_match() {
  local path="$1" glob="$2"
  case "$glob" in
    '**/*.'*) [[ "$path" == *".${glob##*.}" ]] ;;
    '*.'*)    [[ "${path##*/}" == "$glob" ]] ;;
    *'*'*|*'?'*) return 1 ;;
    *) [[ "$path" == "$glob" || "$path" == *"/$glob" ]] ;;
  esac
}

fail=0
messages=""
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  out=$(bash -c "$cmd" 2>&1)
  code=$?
  [ "$code" -eq 127 ] && continue   # コマンド不在 → fail-open
  if [ "$code" -ne 0 ]; then
    fail=1
    messages+="\$ ${cmd}"$'\n'"${out}"$'\n'
  fi
done < <(matched_commands)

if [ "$fail" -ne 0 ]; then
  {
    echo "編集後チェック（.claude/checks.json）に違反があります（$file）。CI と同じ検査です。修正してください:"
    printf '%s' "$messages"
  } >&2
  exit 2
fi
exit 0
