// docs の sidebar（config.mjs）と実ファイルの双方向整合を検査する。
//
// 検出するもの:
//   - 死にリンク: sidebar が指すのに対応ファイルが無い（`docs:build` でも拾えるが明示する）
//   - オーファン: ファイルはあるが sidebar 未登録（`docs:build` は通ってしまい検知できない）
//
// CLAUDE.md の人力ルール「新規ページを追加したら sidebar に登録する（登録漏れに注意）」を
// 機械的な検査に置き換える。config.mjs は動的 import して解決済みの sidebar を走査する
// （正規表現パースではなく実データを見るため堅牢）。
import { readdirSync, existsSync } from 'node:fs'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { dirname, resolve } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const repoRoot = resolve(here, '..')
const docsDir = resolve(repoRoot, 'docs')

// sidebar 登録の対象とするコンテンツ領域は docs/ 直下のサブディレクトリから動的に導出する
// （`.vitepress` や `public` などの非コンテンツは除外）。新領域を足しても検査対象に入る。
const NON_CONTENT = new Set(['public'])
const SECTIONS = readdirSync(docsDir, { withFileTypes: true })
  .filter((d) => d.isDirectory() && !d.name.startsWith('.') && !NON_CONTENT.has(d.name))
  .map((d) => d.name)

// 1) config.mjs を解決して sidebar のリンクを集める
// 動的 import には file:// URL を渡す（絶対パス文字列は Windows で無効な specifier になるため）
const mod = await import(pathToFileURL(resolve(docsDir, '.vitepress/config.mjs')).href)
const config = await mod.default // withMermaid の戻り（オブジェクト/Promise 両対応）
const sidebar = config?.themeConfig?.sidebar ?? {}

const links = new Set()
const collect = (node) => {
  if (Array.isArray(node)) return node.forEach(collect)
  if (node && typeof node === 'object') {
    if (typeof node.link === 'string') links.add(node.link)
    if (node.items) collect(node.items)
  }
}
Object.values(sidebar).forEach(collect)

// リンク → 期待するファイルパス（リポジトリ相対）。外部リンク等は null。
const linkToFile = (link) => {
  if (/^https?:\/\//.test(link)) return null
  let p = link.split('#')[0].split('?')[0]
  if (!p.startsWith('/')) return null
  if (p.endsWith('/')) p += 'index' // ディレクトリリンクは index.md を指す
  return `docs${p}.md`
}

const sectionOf = (file) => file.split('/')[1] // docs/<section>/...

// 2) 死にリンク（sidebar → ファイル欠落）を検出しつつ、参照済みファイル集合を作る
const referenced = new Set()
const deadLinks = []
for (const link of links) {
  const file = linkToFile(link)
  if (!file || !SECTIONS.includes(sectionOf(file))) continue
  referenced.add(file)
  if (!existsSync(resolve(repoRoot, file))) deadLinks.push({ link, file })
}

// 3) オーファン（実ファイル → sidebar 未登録）を検出
const orphans = []
for (const section of SECTIONS) {
  const dir = resolve(docsDir, section)
  if (!existsSync(dir)) continue
  for (const name of readdirSync(dir)) {
    if (!name.endsWith('.md')) continue
    const file = `docs/${section}/${name}`
    if (!referenced.has(file)) orphans.push(file)
  }
}

// 4) レポート（出力順を安定させるためソートしてから表示する）
deadLinks.sort((a, b) => a.file.localeCompare(b.file))
orphans.sort((a, b) => a.localeCompare(b))

let ok = true
if (deadLinks.length) {
  ok = false
  console.error('✗ 死にリンク（sidebar が指すのにファイルが無い）:')
  for (const d of deadLinks) console.error(`    ${d.link}  ->  ${d.file}`)
}
if (orphans.length) {
  ok = false
  console.error('✗ オーファン（ファイルはあるが sidebar 未登録）:')
  for (const f of orphans) console.error(`    ${f}`)
  console.error('  → docs/.vitepress/config.mjs の sidebar に登録してください。')
}

if (ok) {
  console.log('✓ nav 整合 OK: sidebar と docs/{guide,hands-on,practice} の *.md は一致しています。')
  process.exit(0)
}
console.error('')
console.error('nav 整合エラー: 上記を解消してください（sidebar 登録漏れ／リンク切れ）。')
process.exit(1)
