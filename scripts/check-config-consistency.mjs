// 設定駆動ハーネスの「設定↔実体」の整合を検査する。
//
// 検査項目:
//   (a) .claude/checks.json が妥当な JSON で、必須キー（onEdit/commit/protectedBranches/guard）を持つ。
//   (b) .claude/hooks/ のトップレベル *.sh が settings.json に漏れなく配線され、かつ settings.json が
//       参照するフックファイルが実在する（present-but-unwired と dangling-wiring の双方を検出）。
//   (c) checks.json の issueLabels / prLabels が参照するラベル名が実在する（`gh label list`）。
//       gh が無い・未認証の環境では **スキップ（fail-open）**。ネット不要な (a)(b) はローカルでも動く。
//
// 不一致があれば原因を出力して exit 1。CI（ci.yml）とローカル（npm run check:config）から実行する。
import { readFileSync, readdirSync, existsSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const root = resolve(here, '..')
const p = (...s) => resolve(root, ...s)

const errors = []
const notes = []

// ---- (a) checks.json のスキーマ ----
const checksPath = p('.claude/checks.json')
let checks = null
try {
  checks = JSON.parse(readFileSync(checksPath, 'utf8'))
} catch (e) {
  errors.push(`(a) .claude/checks.json が妥当な JSON ではありません: ${e.message}`)
}
if (checks) {
  for (const key of ['onEdit', 'commit', 'protectedBranches', 'guard']) {
    if (!(key in checks)) errors.push(`(a) checks.json に必須キー "${key}" がありません`)
  }
}

// ---- settings.json ----
const settingsPath = p('.claude/settings.json')
let settings = null
try {
  settings = JSON.parse(readFileSync(settingsPath, 'utf8'))
} catch (e) {
  errors.push(`(b) .claude/settings.json が妥当な JSON ではありません: ${e.message}`)
}

// ---- (b) hooks の配線 ----
if (settings) {
  const settingsText = JSON.stringify(settings)
  // トップレベルの *.sh（lib/ 配下や README は除く）
  const hookDir = p('.claude/hooks')
  let hookFiles = []
  try {
    hookFiles = readdirSync(hookDir).filter((f) => f.endsWith('.sh'))
  } catch (e) {
    errors.push(`(b) .claude/hooks を読み取れません（存在しない/読めない）: ${e.message}`)
  }
  for (const f of hookFiles) {
    if (!settingsText.includes(`hooks/${f}`)) {
      errors.push(`(b) フック .claude/hooks/${f} が存在するのに settings.json に配線されていません`)
    }
  }
  // settings.json が参照するフックが実在するか（dangling wiring）
  const referenced = [...settingsText.matchAll(/hooks\/([A-Za-z0-9._-]+\.sh)/g)].map((m) => m[1])
  for (const ref of new Set(referenced)) {
    if (!existsSync(p('.claude/hooks', ref))) {
      errors.push(`(b) settings.json が参照する .claude/hooks/${ref} が存在しません`)
    }
  }
}

// ---- (c) ラベル参照の実在（gh 必須。無ければスキップ） ----
function referencedLabels(cfg) {
  const set = new Set()
  const add = (v) => { if (typeof v === 'string' && v) set.add(v) }
  for (const grp of ['issueLabels', 'prLabels']) {
    const g = cfg?.[grp]
    if (!g) continue
    Object.values(g.types || {}).forEach(add)
    ;(g.areas || []).forEach((a) => add(a?.label))
    ;(g.triage || []).forEach(add)
  }
  return [...set]
}
let ghLabels = null
let ghInstalled = true
try {
  execFileSync('gh', ['--version'], { stdio: 'ignore' })
} catch {
  ghInstalled = false
}
if (!ghInstalled) {
  notes.push('(c) gh 未導入のためラベル実在検査をスキップしました（ローカルでの fail-open）')
} else {
  try {
    const out = execFileSync('gh', ['label', 'list', '--limit', '200', '--json', 'name', '--jq', '.[].name'], {
      encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
    })
    ghLabels = new Set(out.split('\n').map((s) => s.trim()).filter(Boolean))
  } catch (e) {
    // gh は在るのに失敗した場合、CI（GH_TOKEN あり）では権限/API の問題を見逃さないよう **エラー扱い**にする。
    // ローカル（未認証など）はスキップに留める。ci.yml 側で issues: read を付与し gh label list を通す。
    const firstLine = String(e.message || e).split('\n')[0]
    if (process.env.GH_TOKEN || process.env.CI) {
      errors.push(`(c) gh label list に失敗しました（CI ではスキップせず失敗扱い。Issues 読み取り権限や API を確認）: ${firstLine}`)
    } else {
      notes.push(`(c) gh の呼び出しに失敗したためスキップしました（ローカルでの fail-open）: ${firstLine}`)
    }
  }
}
if (checks && ghLabels) {
  for (const label of referencedLabels(checks)) {
    if (!ghLabels.has(label)) {
      errors.push(`(c) checks.json が参照するラベル "${label}" がリポジトリに実在しません（gh label list と不一致）`)
    }
  }
}

// ---- レポート ----
for (const n of notes) console.log(`ℹ ${n}`)
if (errors.length) {
  console.error('✗ 設定↔実体の整合エラー:')
  for (const e of errors) console.error(`    ${e}`)
  console.error('\n設定（checks.json/settings.json）と実体（hooks/ラベル）のズレを解消してください。')
  process.exit(1)
}
console.log('✓ 設定↔実体の整合 OK（checks.json スキーマ・hook 配線' + (ghLabels ? '・ラベル実在' : '') + '）')
process.exit(0)
