// Markdown に手で書いたページ内アンカー（`](./page#見出し)` の fragment）が、
// ビルド後の HTML に実在する id と **バイト列まで一致するか** を検査する。
//
// なぜ要るか:
//   VitePress の slugify は見出しから id を作るが、日本語の濁点・半濁点は結合文字のまま残りうる。
//   ブラウザの fragment 照合は Unicode 正規化をしないため、「見た目は同じなのに飛ばない」
//   リンクが生まれる。既存の検査はどれもこれを見ない。
//     - markdownlint（MD051）は GitHub 方式の別 slugify で判定するため「有効」と誤判定する。
//     - `docs:build` のデッドリンク検査はページの存在は見るが、アンカーの存在は見ない。
//   判定には実レンダリング結果が要る。lint:emphasis と同じ発想で、ビルド成果物と突き合わせる。
//
// 実行: `npm run check:anchors`（`docs:build` の後。CI の build ジョブと同一）。
// dist が無ければ **明示エラー**にする（検査していないのに緑、を作らない）。
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve, relative, join } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const root = resolve(here, '..')
const docsDir = resolve(root, 'docs')
const distDir = resolve(docsDir, '.vitepress/dist')

if (!existsSync(distDir)) {
  console.error('✗ ビルド成果物がありません: docs/.vitepress/dist')
  console.error('  先に `npm run docs:build` を実行してください（実 HTML と突き合わせる検査のため）。')
  process.exit(1)
}

// ---- 収集 ----
function walk(dir, ext, out = []) {
  for (const name of readdirSync(dir)) {
    if (name === '.vitepress' || name === 'node_modules') continue
    const p = join(dir, name)
    if (statSync(p).isDirectory()) walk(p, ext, out)
    else if (name.endsWith(ext)) out.push(p)
  }
  return out
}

// Markdown ソース（docs/ 配下、.vitepress は除く）
const mdFiles = walk(docsDir, '.md')

// dist の HTML から id を集める
const idsOf = new Map() // dist 相対の html パス -> Set<id>
function collectHtml(dir) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name)
    if (statSync(p).isDirectory()) { collectHtml(p); continue }
    if (!name.endsWith('.html')) continue
    const html = readFileSync(p, 'utf8')
    // 属性名がちょうど `id` のものだけを拾う。`\bid="` だと `data-id="…"` にも当たり
    // （`-` と `i` の間に word 境界が立つ）、実在しないアンカーが偽の id と一致して
    // **黙って検査を通ってしまう**。`\sid="` では `<a href="x"id="y">` を取りこぼすので後読みで書く。
    const ids = new Set([...html.matchAll(/(?<![-\w:])id="([^"]*)"/g)].map((m) => m[1]))
    // キーは `/` 区切りに正規化する（Windows の `\` 区切りだと mdToHtml() の結果と噛み合わない）
    idsOf.set(relative(distDir, p).replace(/\\/g, '/'), ids)
  }
}
collectHtml(distDir)

// ---- Markdown からリンクを拾う ----
// コードフェンス・インラインコードは対象外（リンクとして描画されないため）。
// フェンスは行頭に限らない（リスト内では字下げされる）。開きの字下げ幅は問わず、
// 同じ記号で閉じるまでを落とす。
//
// 落とすときは **改行だけ残す**。空文字に置換すると後続の行が詰め上がり、
// エラーに出す行番号が原文とずれる（指摘箇所を示すのがこの検査の役目なので致命的）。
const keepNewlines = (block) => block.replace(/[^\n]/g, '')
function stripCode(src) {
  return src
    .replace(/^[ \t]*(```+|~~~+)[\s\S]*?^[ \t]*\1[ \t]*$/gm, keepNewlines)
    .replace(/`[^`\n]*`/g, '')
}

// docs 相対の md パス -> dist 相対の html パス
function mdToHtml(mdPath) {
  const rel = relative(docsDir, mdPath).replace(/\\/g, '/')
  return rel.replace(/\.md$/, '.html')
}

const errors = []
let checked = 0

for (const file of mdFiles) {
  const src = stripCode(readFileSync(file, 'utf8'))
  const lines = src.split('\n')
  lines.forEach((line, idx) => {
    for (const m of line.matchAll(/\]\(([^)\s]+)\)/g)) {
      const href = m[1]
      if (/^(https?:|mailto:|#!)/.test(href)) continue
      const hash = href.indexOf('#')
      if (hash === -1) continue
      const pathPart = href.slice(0, hash)
      const rawFrag = href.slice(hash + 1)
      if (!rawFrag) continue
      // 不正な % エンコード（`#%ZZ` 等）で decodeURIComponent は URIError を投げる。
      // スクリプトごと落とすと他のリンクを検査しないまま終わるので、その 1 件だけを
      // 「検査不能」として記録し、走査を続ける（黙って飛ばさない）。
      let frag
      try {
        frag = decodeURIComponent(rawFrag)
      } catch {
        errors.push({ file, line: idx + 1, href, why: 'fragment の % エンコードが不正で復号できません' })
        continue
      }

      // 対象ページの md パスを解決する。
      // `/standards/versioning` のようなサイトルート相対は docs/ が起点。
      // これを dirname(file) から resolve するとファイルシステムの絶対パスになり、
      // existsSync が false になって **黙って検査対象から外れる**（取りこぼしになる）。
      let targetMd
      if (pathPart === '') {
        targetMd = file // 同一ページ内
      } else {
        const base = pathPart.startsWith('/') ? docsDir : dirname(file)
        let p = resolve(base, pathPart.replace(/^\//, ''))
        if (pathPart.endsWith('/')) p = join(p, 'index.md')
        else if (!p.endsWith('.md')) p += '.md'
        targetMd = p
      }
      if (!existsSync(targetMd)) continue // ページ自体の欠落は docs:build が見る

      const htmlRel = mdToHtml(targetMd)
      const ids = idsOf.get(htmlRel)
      if (!ids) {
        errors.push({ file, line: idx + 1, href, why: `ビルド成果物 ${htmlRel} が見つかりません` })
        continue
      }
      checked++
      if (ids.has(frag)) continue

      // 診断: 正規化すれば一致するなら、それが原因だと明示する
      const nfcHit = [...ids].find((id) => id.normalize('NFC') === frag.normalize('NFC'))
      const why = nfcHit
        ? `id は "${nfcHit}" として出力されています。見た目は同じですが Unicode の正規化形が違い、`
          + `ブラウザの fragment 照合（正規化しない）では一致しません`
        : `${htmlRel} に id="${frag}" がありません`
      errors.push({ file, line: idx + 1, href, why })
    }
  })
}

// ---- レポート ----
if (errors.length) {
  console.error(`✗ 実在しないページ内アンカーが ${errors.length} 件あります:`)
  for (const e of errors) {
    console.error(`    ${relative(root, e.file)}:${e.line}  ${e.href}`)
    console.error(`        → ${e.why}`)
  }
  console.error('')
  console.error('見出しの id は docs/.vitepress/config.mjs の slugify（NFC 正規化）で決まります。')
  console.error('リンク側の綴りが見出しと一致しているか確認してください。')
  process.exit(1)
}

console.log(`✓ ページ内アンカー OK: ${checked} 件の fragment がすべて実 HTML の id に一致します。`)
process.exit(0)
