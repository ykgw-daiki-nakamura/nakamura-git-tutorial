// 強調（`**...**`）が意図どおり描画されるかを検査する。
//
// 検出するもの:
//   - 開き / 閉じの `**` が CommonMark の flanking 規則を満たさず、強調が成立しない
//     （`**` がそのまま本文に表示される）
//   - 区切り記号が誤ってペアリングされ、意図と違う範囲が太字になる
//
// 日本語では `）` `」` `` ` `` などの Unicode 句読点が `**` に隣接すると起きる。
//
//   変更の**理由（コミットメッセージ）**を後から追える   → 閉じが成立しない
//   いずれも**「出荷した線を…維持する」**ための仕組みです → 開きが成立しない
//
// markdownlint は整形、textlint は文章表現を見るため、いずれもこれを検知しない。
// `docs:build`（VitePress）も強調が壊れたまま正常にビルドされる。判定には実際の
// レンダリング結果が要るので、VitePress と同じ markdown-it に通して突き合わせる。
//
// 使い方:
//   node scripts/check-emphasis.mjs            # docs/**/*.md とルート直下の *.md
//   node scripts/check-emphasis.mjs <file>...  # 対象を明示（PostToolUse フック用）
import { readdirSync, readFileSync, existsSync, statSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve, relative } from 'node:path'
import MarkdownIt from 'markdown-it'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..')
const md = new MarkdownIt()

// `lint:text` と同じ対象（docs 配下と、ルート直下の *.md）
const SKIP_DIRS = new Set(['node_modules', '.vitepress', '.git'])
const walk = (dir, out = []) => {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) {
      if (!SKIP_DIRS.has(e.name) && !e.name.startsWith('.')) walk(resolve(dir, e.name), out)
    } else if (e.name.endsWith('.md')) out.push(resolve(dir, e.name))
  }
  return out
}
const defaultTargets = () => {
  const files = walk(resolve(repoRoot, 'docs'))
  for (const name of readdirSync(repoRoot)) {
    if (name.endsWith('.md') && statSync(resolve(repoRoot, name)).isFile()) {
      files.push(resolve(repoRoot, name))
    }
  }
  return files.sort()
}

// --- CommonMark: left/right-flanking delimiter run -------------------------
// https://spec.commonmark.org/0.31.2/#left-flanking-delimiter-run
// 行頭・行末は空白として扱う（undefined を isWS が true と判定する）。
const isWS = (c) => c === undefined || /\s/.test(c)
const isPunct = (c) => c !== undefined && /[\p{P}\p{S}]/u.test(c)
const leftFlanking = (prev, next) => !isWS(next) && (!isPunct(next) || isWS(prev) || isPunct(prev))
const rightFlanking = (prev, next) => !isWS(prev) && (!isPunct(prev) || isWS(next) || isPunct(next))

// `**` が強調にならない領域のマスク
//   - インラインコードスパン（`` `...` ``）の内側
//   - 画像の記法（`![alt](src)`）— alt は属性値になり <strong> を生まない
const excludedMask = (line) => {
  const mask = new Array(line.length).fill(false)
  let open = -1
  for (let i = 0; i < line.length; i++) {
    if (line[i] !== '`') continue
    if (open < 0) open = i
    else {
      for (let k = open; k <= i; k++) mask[k] = true
      open = -1
    }
  }
  for (const m of line.matchAll(/!\[[^\]]*\]\([^)]*\)/g)) {
    for (let k = m.index; k < m.index + m[0].length; k++) mask[k] = true
  }
  return mask
}

// 強調になりうる `**`（3 連以上のアスタリスクは曖昧なので行ごと見送る）の開始位置
const starRuns = (line) => {
  const mask = excludedMask(line)
  const runs = []
  for (let i = 0; i < line.length; ) {
    if (line[i] !== '*') { i++; continue }
    let j = i
    while (line[j] === '*') j++
    const len = j - i
    if (!mask[i]) {
      if (len > 2) return null // `***` 等は対象外
      if (len === 2) runs.push(i)
    }
    i = j
  }
  return runs
}

const stripTags = (html) => html.replace(/<[^>]+>/g, '')
const plain = (src) => stripTags(md.renderInline(src))
const strongTexts = (src) =>
  [...md.renderInline(src).matchAll(/<strong>([\s\S]*?)<\/strong>/g)].map((m) => stripTags(m[1]))

// 1 行を検査して、違反があれば理由を返す（無ければ null）
const checkLine = (line) => {
  const runs = starRuns(line)
  if (runs === null) return null
  // 奇数個は行をまたぐ強調（CLAUDE.md に実例あり）なので意図を判定できない。見送る。
  if (runs.length < 2 || runs.length % 2 !== 0) return null

  const intended = []
  for (let k = 0; k + 1 < runs.length; k += 2) {
    const [o, c] = [runs[k], runs[k + 1]]
    if (!leftFlanking(line[o - 1], line[o + 2])) {
      return { kind: '開きの ** が強調を開始しません', at: o, hint: `** の直前に半角スペースを入れてください` }
    }
    if (!rightFlanking(line[c - 1], line[c + 2])) {
      return { kind: '閉じの ** が強調を終了しません', at: c, hint: `** の直後に半角スペースを入れてください` }
    }
    intended.push(plain(line.slice(o + 2, c)))
  }

  // flanking を満たしていても、区切り記号の対応がずれて別の範囲が太字になることがある。
  // 実レンダリング結果の <strong> の中身が、原文の素直なペアの中身と一致するかを確かめる。
  const actual = strongTexts(line)
  if (actual.length !== intended.length || actual.some((t, i) => t !== intended[i])) {
    return { kind: '太字になる範囲が原文の ** の対応とずれています', intended, actual }
  }
  return null
}

const targets = process.argv.slice(2)
const files = targets.length ? targets.map((f) => resolve(repoRoot, f)) : defaultTargets()

const violations = []
for (const file of files) {
  if (!existsSync(file)) continue
  let fence = null
  readFileSync(file, 'utf8').split('\n').forEach((line, idx) => {
    const m = line.match(/^\s*(```+|~~~+)/)
    if (m) {
      if (fence === null) fence = m[1][0]
      else if (m[1][0] === fence) fence = null
      return
    }
    if (fence !== null) return
    const v = checkLine(line)
    if (v) violations.push({ file: relative(repoRoot, file), line: idx + 1, text: line.trim(), ...v })
  })
}

if (!violations.length) {
  console.log(`✓ 強調の描画 OK: ${files.length} ファイルの ** はすべて意図どおり太字になります。`)
  process.exit(0)
}

console.error('✗ 描画されない（または範囲がずれる）強調が見つかりました:')
for (const v of violations) {
  console.error(`\n  ${v.file}:${v.line}  ${v.kind}`)
  console.error(`    ${v.text}`)
  if (v.hint) console.error(`    → ${v.hint}`)
  if (v.intended) {
    console.error(`    → 期待: ${JSON.stringify(v.intended)}`)
    console.error(`      実際: ${JSON.stringify(v.actual)}`)
  }
}
console.error('')
console.error('CommonMark では、`）`「」`` ` `` などの句読点が ** に隣接すると強調が成立しません。')
console.error('参考: https://spec.commonmark.org/0.31.2/#emphasis-and-strong-emphasis')
process.exit(1)
