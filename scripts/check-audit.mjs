// 依存の既知脆弱性（npm audit）を advisory 単位でゲートする。
//
// なぜ要るか:
//   `actions/dependency-review-action` は PR で **新規追加・更新された依存** しか見ない。
//   すでに lockfile に載っている依存に後から advisory が生えても CI は緑のままになる。
//   このスクリプトはロックファイル全体を対象に、しきい値以上の advisory を CI で落とす。
//
// 「期限付き allowlist」が肝:
//   上流に修正が無い advisory は必ず出る（例: vitepress が古い vite に固定している）。
//   素朴にゲートすると CI が永久に赤くなり、いずれ --audit-level を緩めて検査全体が形骸化する。
//   そこで GHSA 単位で「理由」と「再評価期限」を .github/security.json に書いて除外し、
//   **期限を過ぎたら CI で落とす**。除外したまま忘れる、という失敗を仕組みで防ぐ。
//
// 判定:
//   - failOn 以上の severity で allowlist に無い     -> エラー（exit 1）
//   - failOn 以上の severity で allowlist にあるが期限切れ -> エラー（exit 1）
//   - failOn 以上の severity で allowlist にあり有効   -> 許容（ℹ で理由と期限を表示）
//   - failOn 未満の severity                        -> 情報表示のみ（落とさない）
//   - allowlist にあるが現在は該当しない（stale）     -> 警告のみ（落とさない）
//
// `npm audit` はレジストリへの問い合わせが要る。ネットワーク不通などで結果を解釈できない場合は
// **fail-open**（作業を止めない）。guard 群・check-config-consistency.mjs と同じ思想。
//
// 実行: `npm run check:audit`（CI の audit ジョブとローカルで同一）。
// `npm audit` は package-lock.json だけで動くため node_modules は不要。
import { readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const root = resolve(here, '..')

// npm audit の severity 語彙。左ほど軽い。
const SEVERITIES = ['info', 'low', 'moderate', 'high', 'critical']
const rank = (s) => SEVERITIES.indexOf(s)

const errors = []
const warnings = []
const notes = []

// ---- 設定（.github/security.json の audit キー） ----
// ポリシーの語彙は CI 側（.github/）が持つ。Claude を使わないコントリビューターにも同じゲートが効く。
let audit
try {
  audit = JSON.parse(readFileSync(resolve(root, '.github/security.json'), 'utf8')).audit
} catch (e) {
  console.error(`✗ .github/security.json を読めません: ${e.message}`)
  process.exit(1)
}
if (!audit || typeof audit !== 'object') {
  console.error('✗ .github/security.json に "audit" キーがありません。')
  process.exit(1)
}

const failOn = audit.failOn ?? 'high'
if (rank(failOn) < 0) {
  console.error(`✗ audit.failOn が不正です: "${failOn}"（${SEVERITIES.join(' / ')} のいずれか）`)
  process.exit(1)
}

// allowlist を GHSA -> エントリ の Map にする。書式の誤りはここで落とす
// （理由・期限の無い除外を作らせない。これが無いと allowlist が単なる無効化に堕ちる）。
const allow = new Map()
for (const [i, entry] of (audit.allow ?? []).entries()) {
  const where = `audit.allow[${i}]`
  if (!entry?.ghsa) { errors.push(`${where}: "ghsa" がありません`); continue }
  if (!entry.reason) { errors.push(`${where} (${entry.ghsa}): "reason" がありません（なぜ除外してよいかを書く）`); continue }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(entry.expires ?? '')) {
    errors.push(`${where} (${entry.ghsa}): "expires" が YYYY-MM-DD 形式ではありません（再評価期限は必須）`)
    continue
  }
  allow.set(entry.ghsa, entry)
}
if (errors.length) {
  console.error('✗ audit の allowlist 設定が不正です:')
  for (const e of errors) console.error(`    ${e}`)
  process.exit(1)
}

// 期限は日付単位で比較する（時刻は持たせない）。今日を含む日は「まだ有効」。
const today = new Date().toISOString().slice(0, 10)

// ---- npm audit の実行 ----
// 脆弱性が見つかると npm は非ゼロで終了するが、stdout には JSON が出る。
// 終了コードでは「脆弱性あり」と「実行失敗」を区別できないので、常に stdout を解釈する。
const res = spawnSync('npm', ['audit', '--json'], {
  cwd: root,
  encoding: 'utf8',
  maxBuffer: 32 * 1024 * 1024,
  shell: process.platform === 'win32', // Windows では npm がシェル経由でしか解決されない
})

let report = null
try {
  report = JSON.parse(res.stdout)
} catch {
  // JSON にならない = レジストリ不通・npm の異常終了など。検査できないだけで、悪いとは限らない。
  const detail = (res.stderr || res.error?.message || '').split('\n')[0]
  console.log(`ℹ npm audit の結果を解釈できないためスキップしました（fail-open）: ${detail || '出力なし'}`)
  process.exit(0)
}
// npm 自身がエラーを JSON で返すことがある（`{"error": {...}}`）。これも検査不能として fail-open。
if (report?.error || !report?.vulnerabilities) {
  const detail = report?.error?.summary || report?.error?.detail || 'vulnerabilities フィールドがありません'
  console.log(`ℹ npm audit が結果を返しませんでした（fail-open）: ${String(detail).split('\n')[0]}`)
  process.exit(0)
}

// ---- advisory 単位に正規化 ----
// npm audit --json (v2) は「パッケージ単位」で報告する。1 パッケージが複数 advisory を持ち、
// 逆に 1 advisory が推移的に複数パッケージへ波及する。判定は advisory 単位でないと重複・取りこぼす。
// vulnerabilities[pkg].via[] のうち **オブジェクト要素** が advisory 本体
// （文字列要素は「このパッケージ経由で影響している他パッケージ名」への参照なので除外する）。
const advisories = new Map() // GHSA -> { id, severity, package, title, range }
for (const vuln of Object.values(report.vulnerabilities)) {
  for (const via of vuln.via ?? []) {
    if (typeof via !== 'object' || !via.url) continue
    const id = via.url.split('/').pop() // https://github.com/advisories/GHSA-xxxx-xxxx-xxxx
    if (!advisories.has(id)) {
      advisories.set(id, { id, severity: via.severity, package: via.name, title: via.title, range: via.range })
    }
  }
}

// ---- 判定 ----
const sorted = [...advisories.values()].sort(
  (a, b) => rank(b.severity) - rank(a.severity) || a.id.localeCompare(b.id),
)
const blocked = []
const allowed = []
const below = []

for (const a of sorted) {
  if (rank(a.severity) < rank(failOn)) { below.push(a); continue }
  const entry = allow.get(a.id)
  if (!entry) { blocked.push({ ...a, why: `allowlist に無い（severity: ${a.severity} >= ${failOn}）` }); continue }
  if (entry.expires < today) {
    blocked.push({ ...a, why: `allowlist の再評価期限 ${entry.expires} を過ぎています（今日: ${today}）` })
    continue
  }
  allowed.push({ ...a, entry })
}

// allowlist にあるのに現在は該当しない = 依存が更新されて解消した、または ID の書き間違い。
// 落とすほどではないが、放置すると「効いていない除外」が積もるので警告する。
for (const [ghsa, entry] of allow) {
  if (!advisories.has(ghsa)) {
    warnings.push(`allowlist の ${ghsa} は現在どの advisory にも該当しません（解消済みなら .github/security.json から削除してください / 理由: ${entry.reason}）`)
  }
}

// ---- レポート ----
if (below.length) {
  notes.push(`しきい値（${failOn}）未満の advisory が ${below.length} 件あります（情報表示のみ）:`)
  for (const a of below) notes.push(`    ${a.severity.padEnd(8)} ${a.id}  ${a.package}  ${a.title}`)
}
if (allowed.length) {
  notes.push(`allowlist で許容中の advisory が ${allowed.length} 件あります:`)
  for (const a of allowed) {
    notes.push(`    ${a.severity.padEnd(8)} ${a.id}  ${a.package}  （再評価期限: ${a.entry.expires}）`)
    notes.push(`        理由: ${a.entry.reason}`)
  }
}
for (const n of notes) console.log(n.startsWith('    ') ? n : `ℹ ${n}`)
for (const w of warnings) console.log(`⚠ ${w}`)

if (blocked.length) {
  console.error('')
  console.error(`✗ 対処が必要な advisory が ${blocked.length} 件あります:`)
  for (const a of blocked) {
    console.error(`    ${a.severity.padEnd(8)} ${a.id}  ${a.package} ${a.range}`)
    console.error(`        ${a.title}`)
    console.error(`        https://github.com/advisories/${a.id}`)
    console.error(`        → ${a.why}`)
  }
  console.error('')
  console.error('対処: `npm audit fix` で解消するか、上流に修正が無いなら .github/security.json の')
  console.error('      audit.allow に { ghsa, reason, expires } を追加してください（期限を切ること）。')
  process.exit(1)
}

console.log(`✓ 依存の脆弱性 OK: ${failOn} 以上の未対処 advisory はありません（検査 ${advisories.size} 件 / 許容 ${allowed.length} 件）。`)
process.exit(0)
