// 設定駆動ハーネスの「設定↔実体」の整合を検査する。
//
// 設定ファイルは 3 つある。CI が強制するゲートの語彙は .github/ 側が単一情報源で、
// 規約（許可 type・type→ラベル名）は .github/conventions.json、セキュリティポリシー（npm audit の
// しきい値・期限付き allowlist）は .github/security.json が持つ。Claude ハーネス固有の配線は
// .claude/checks.json が持つ。
//
// 検査項目:
//   (a) 3 つの設定ファイルが妥当な JSON で、必須キーを持つ。conventions.json は許可 type 一覧が非空配列で、
//       type→ラベル名の対応表が type 一覧と過不足なく対応する。security.json は audit.failOn が有効な
//       severity で、audit.allow の各要素が ghsa/reason/expires を持つ。checks.json は
//       onEdit/protectedBranches/guard を持つ。
//   (b) .claude/hooks/ のトップレベル *.sh が settings.json に漏れなく配線され、かつ settings.json が
//       参照するフックファイルが実在する（present-but-unwired と dangling-wiring の双方を検出）。
//   (c) conventions.json の labels.types と checks.json の issueLabels / prLabels が参照するラベル名が
//       実在する（`gh label list`）。gh が無い・未認証の環境では **スキップ（fail-open）**。
//       ネット不要な (a)(b)(d) はローカルでも動く。
//   (d) 検証スクリプトが持つフォールバックの default_types が、conventions.json の
//       commit.conventional.types と順序を含めて一致する。jq / conventions.json を読めない環境でだけ
//       挙動が食い違う「静かなドリフト」を防ぐ。
//   (e) ci.yml の dependency-review-action の fail-on-severity が、security.json の audit.failOn と
//       一致する。同じしきい値を 2 か所で宣言しているため、片方だけ変わると
//       「PR で入る依存」と「既に入っている依存」で基準が食い違う。
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

// ---- (a) conventions.json のスキーマ ----
const conventionsPath = p('.github/conventions.json')
let conventions = null
try {
  conventions = JSON.parse(readFileSync(conventionsPath, 'utf8'))
} catch (e) {
  errors.push(`(a) .github/conventions.json が妥当な JSON ではありません: ${e.message}`)
}
const conventionTypes = conventions?.commit?.conventional?.types
if (conventions) {
  if (!Array.isArray(conventionTypes) || conventionTypes.length === 0) {
    errors.push('(a) conventions.json の commit.conventional.types を非空の type 配列として読めません')
  } else {
    // type 一覧とラベル対応表がずれると、pr-label.yml が「未対応 type」として黙ってスキップする。
    // どちらの向きのずれも検出する。
    const labelTypes = conventions.labels?.types
    if (!labelTypes || typeof labelTypes !== 'object') {
      errors.push('(a) conventions.json に labels.types（type→ラベル名の対応表）がありません')
    } else {
      for (const t of conventionTypes) {
        if (!labelTypes[t]) errors.push(`(a) conventions.json の labels.types に type "${t}" のラベル名がありません`)
      }
      for (const t of Object.keys(labelTypes)) {
        if (!conventionTypes.includes(t)) {
          errors.push(`(a) conventions.json の labels.types にある "${t}" は commit.conventional.types に存在しません`)
        }
      }
    }
  }
}

// ---- (a) security.json のスキーマ ----
// 実際のゲート（advisory 単位の判定・期限切れ検知）は scripts/check-audit.mjs が持つ。
// ここでは「audit ジョブが読めない形になっていないか」だけを、ネット不要な範囲で確かめる。
// allow の各要素の詳細な検証（expires の日付書式など）は check-audit.mjs に一本化し、重複させない。
const SEVERITIES = ['info', 'low', 'moderate', 'high', 'critical']
const securityPath = p('.github/security.json')
let security = null
try {
  security = JSON.parse(readFileSync(securityPath, 'utf8'))
} catch (e) {
  errors.push(`(a) .github/security.json が妥当な JSON ではありません: ${e.message}`)
}
if (security) {
  const audit = security.audit
  if (!audit || typeof audit !== 'object') {
    errors.push('(a) security.json に必須キー "audit" がありません')
  } else {
    if (!SEVERITIES.includes(audit.failOn)) {
      errors.push(`(a) security.json の audit.failOn が不正です: ${JSON.stringify(audit.failOn)}（${SEVERITIES.join(' / ')} のいずれか）`)
    }
    if (!Array.isArray(audit.allow)) {
      errors.push('(a) security.json の audit.allow を配列として読めません（除外が無い場合も [] を置く）')
    } else {
      for (const [i, entry] of audit.allow.entries()) {
        for (const key of ['ghsa', 'reason', 'expires']) {
          if (!entry?.[key]) errors.push(`(a) security.json の audit.allow[${i}] に "${key}" がありません（理由と再評価期限の無い除外を作らない）`)
        }
      }
    }
  }
}

// ---- (a) checks.json のスキーマ ----
// 許可 type とラベル対応表は conventions.json へ移したので、ここでは必須キーに含めない。
const checksPath = p('.claude/checks.json')
let checks = null
try {
  checks = JSON.parse(readFileSync(checksPath, 'utf8'))
} catch (e) {
  errors.push(`(a) .claude/checks.json が妥当な JSON ではありません: ${e.message}`)
}
if (checks) {
  for (const key of ['onEdit', 'protectedBranches', 'guard']) {
    if (!(key in checks)) errors.push(`(a) checks.json に必須キー "${key}" がありません`)
  }
  if ('commit' in checks) {
    errors.push('(a) checks.json に commit キーが残っています（許可 type の情報源は .github/conventions.json に一本化済み）')
  }
  if (checks.issueLabels?.types) {
    errors.push('(a) checks.json に issueLabels.types が残っています（type→ラベル名の情報源は .github/conventions.json に一本化済み）')
  }
  if ('audit' in checks) {
    errors.push('(a) checks.json に audit キーがあります（npm audit のポリシーの情報源は .github/security.json に一本化済み）')
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
// 参照元は 2 ファイル: conventions.json の labels.types（type→種別ラベル）と、
// checks.json の issueLabels / prLabels（領域ラベル・triage ラベル）。
function referencedLabels(conventionsCfg, checksCfg) {
  const set = new Set()
  const add = (v) => { if (typeof v === 'string' && v) set.add(v) }
  Object.values(conventionsCfg?.labels?.types || {}).forEach(add)
  for (const grp of ['issueLabels', 'prLabels']) {
    const g = checksCfg?.[grp]
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
if ((conventions || checks) && ghLabels) {
  for (const label of referencedLabels(conventions, checks)) {
    if (!ghLabels.has(label)) {
      errors.push(`(c) 設定が参照するラベル "${label}" がリポジトリに実在しません（gh label list と不一致。scripts/sync-labels.sh の実行漏れ？）`)
    }
  }
}

// ---- (d) フォールバック default_types のドリフト ----
// conventions.json を読めない環境（jq 不在など）向けに、同じ type 一覧をハードコードで持つスクリプト。
// 増減したらこの表に足す。抽出できなければ「無言の pass」にせず失敗させる。
const FALLBACK_TYPE_SOURCES = [
  { file: '.github/scripts/check-pr-title.sh', varName: 'default_types' },
  { file: '.claude/hooks/guard-commit.sh', varName: 'default_types' },
]
// 一覧そのものが読めない場合は (a) が既に失敗しているので、ここでは黙って飛ばす。
if (Array.isArray(conventionTypes) && conventionTypes.length > 0) {
  for (const { file, varName } of FALLBACK_TYPE_SOURCES) {
    let text = null
    try {
      text = readFileSync(p(file), 'utf8')
    } catch (e) {
      errors.push(`(d) ${file} を読み取れません（対象ファイルが移動/削除された可能性）: ${e.message}`)
      continue
    }
    const m = text.match(new RegExp(`^${varName}="([^"]*)"`, 'm'))
    if (!m) {
      errors.push(`(d) ${file} から ${varName}="..." を抽出できません（書式が変わった可能性。無言の pass にしません）`)
      continue
    }
    if (m[1] !== conventionTypes.join('|')) {
      errors.push(
        `(d) ${file} の ${varName} が conventions.json の commit.conventional.types と一致しません（順序含む）\n` +
          `        conventions.json: ${conventionTypes.join('|')}\n` +
          `        ${file}: ${m[1]}`,
      )
    }
  }
}

// ---- (e) しきい値の二重宣言のドリフト ----
// audit ジョブ（security.json の audit.failOn）と dependency-review ジョブ（ci.yml の
// fail-on-severity）は同じしきい値を別々に宣言する。前者は lockfile 全体、後者は PR が追加・更新した
// 依存が対象で、役割が違うので 1 か所には寄せられない。片方だけ動くのを機械で防ぐ。
if (security?.audit?.failOn) {
  const ciPath = p('.github/workflows/ci.yml')
  let ciText = null
  try {
    ciText = readFileSync(ciPath, 'utf8')
  } catch (e) {
    errors.push(`(e) .github/workflows/ci.yml を読み取れません: ${e.message}`)
  }
  if (ciText !== null) {
    const m = ciText.match(/^\s*fail-on-severity:\s*(\S+)\s*$/m)
    if (!m) {
      // 書式が変わった / ステップが消えたときに「無言の pass」にしない（(d) と同じ方針）。
      errors.push('(e) ci.yml から dependency-review-action の fail-on-severity を抽出できません（書式が変わった可能性）')
    } else if (m[1] !== security.audit.failOn) {
      errors.push(
        '(e) ci.yml の fail-on-severity が security.json の audit.failOn と一致しません\n' +
          `        security.json: ${security.audit.failOn}\n` +
          `        ci.yml: ${m[1]}`,
      )
    }
  }
}

// ---- レポート ----
for (const n of notes) console.log(`ℹ ${n}`)
if (errors.length) {
  console.error('✗ 設定↔実体の整合エラー:')
  for (const e of errors) console.error(`    ${e}`)
  console.error('\n設定（conventions.json/security.json/checks.json/settings.json）と実体（hooks/ラベル）のズレを解消してください。')
  process.exit(1)
}
console.log(
  '✓ 設定↔実体の整合 OK（conventions.json / security.json / checks.json スキーマ・hook 配線' +
    (ghLabels ? '・ラベル実在' : '') +
    '・フォールバック type 一覧・audit しきい値）',
)
process.exit(0)
