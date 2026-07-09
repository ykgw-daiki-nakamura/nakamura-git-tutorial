// guard 群の共通ヘルパ。
// stdin: Bash ツールの生コマンド文字列（複数行可）。
// stdout: コマンド種別判定用の「スケルトン」。
//   - ヒアドキュメント本文（<<'EOF' ... EOF / <<EOF / <<-EOF）を丸ごと除去。
//     ヒアドキュメント開始 << は **コマンド文脈** でのみ検出する。引用符内の "<<EOF" のような
//     ただの文字列は開始と見なさない（以降の実コマンド行を捨てないため）。ただし二重引用符の
//     内側でも $( ... ) の中はコマンド文脈なので、そこでは検出する
//     （`--body "$(cat <<'BODY' ... BODY)"` の本文を判定対象から外すため）。
//   - シングル/ダブルクオートで囲まれた文字列を単一プレースホルダ __STR__ に置換。
//     **引用符は行をまたいで対応付ける**（1 行ずつ独立に走査すると、複数行にわたる引用符の
//     途中で状態を見失い、本文が生のまま判定対象に漏れる）。
//   - 二重引用符内のバッククォート区間はコマンド置換なので中身を落とす
//     （Markdown のコードフェンスを本文に含めても本文が漏れない）。
//   - # から行末までのコメントを除去（語境界＝行頭・空白直後、またはコマンド区切り ; | & ( 直後の #）
// これにより、docs / skills / Issue 本文に書かれた実行されないコマンド文字列が
// 種別判定で誤ヒットするのを防ぐ。
//
// 引数 --danger: guard-dangerous 用。引用符内でも **危険判定に必要な最小トークン**
//   （/ ・ ~ ・ $HOME ・ --force ・ --force-with-lease ・ --no-preserve-root）は保持する。
//   これにより、危険な引数だけを引用した実コマンド（引数のみ引用符で囲んだ形）を見逃さない。
//   既定（フラグ無し）は純粋な __STR__ 置換で、-C "<path>" を伴う種別判定を壊さない。
//
// 値（メッセージ・パス・ブランチ名）の抽出は各 guard 側で原文から行う。
const DANGER = process.argv.includes("--danger");
// 危険判定に必要なフラグ。引用符内でも保持する。
const PRESERVE_FLAGS = ["--force-with-lease", "--no-preserve-root", "--force"];
// 危険な削除対象。ルート・ホームそのもの（末尾の / や * は許容）だけを保持する。
const DANGER_TARGET = /^(\/|~|\$HOME|\$\{HOME\})\/?\*?$/;

let s = "";
process.stdin.on("data", (d) => (s += d)).on("end", () => {
  process.stdout.write(skeleton(s));
});

// 引用符内の内容を潰す。--danger 時は危険トークンだけ残す。
// 判定は **単独トークンとしての一致** で行う。部分一致にすると `rm -rf "/tmp"` や
// `rm -rf "$HOME/x"` のような安全なサブパスからも `/` や `$HOME` が単独トークンとして漏れ、
// guard-dangerous が誤検知する。
function placeholder(content) {
  let out = " __STR__ ";
  if (DANGER) {
    for (const tok of content.split(/\s+/)) {
      if (!tok) continue;
      if (PRESERVE_FLAGS.includes(tok) || DANGER_TARGET.test(tok)) out += tok + " ";
    }
  }
  return out;
}

// src[from] から ch が現れる位置を返す（見つからなければ src.length）。
function findChar(src, from, ch) {
  let i = from;
  while (i < src.length && src[i] !== ch) i++;
  return i;
}

// src[open] === "(" として、対応する ")" の位置を返す（見つからなければ src.length）。
// 引用符・エスケープの中の括弧は数えない。`$(echo ")")` のように閉じ括弧を含む文字列があると
// 対応括弧を誤認し、コマンド置換のスケルトン化が壊れて検知漏れ・誤検知につながる。
function matchParen(src, open) {
  let depth = 0;
  let i = open;
  const n = src.length;
  while (i < n) {
    const c = src[i];
    if (c === "\\") { i += 2; continue; }
    if (c === "'") { i = findChar(src, i + 1, "'") + 1; continue; }
    if (c === '"') { i = skipDouble(src, i); continue; }
    if (c === "(") depth++;
    else if (c === ")") {
      depth--;
      if (depth === 0) return i;
    }
    i++;
  }
  return n;
}

// src[i] === '"' として、対応する閉じ引用符の **次** の位置を返す。
// 二重引用符の中の $( ... ) はネストしうるので、その中の引用符も追って読み飛ばす。
function skipDouble(src, i) {
  let j = i + 1;
  const n = src.length;
  while (j < n) {
    const c = src[j];
    if (c === "\\") { j += 2; continue; }
    if (c === '"') return j + 1;
    if (c === "$" && src[j + 1] === "(") { j = matchParen(src, j + 1) + 1; continue; }
    j++;
  }
  return n;
}

// コメント開始とみなせる位置か（行頭・空白直後・コマンド区切り直後）。
function atCommentBoundary(out) {
  return out === "" || /[\s;&|(]$/.test(out);
}

// 二重引用符を走査する。リテラル部分は placeholder に潰し、$( ... ) はコマンド文脈として
// 再帰的にスケルトン化する。バッククォート区間は中身を落とす。
function scanDouble(src, i) {
  let j = i + 1;
  let lit = "";
  let pieces = "";
  const n = src.length;
  while (j < n) {
    const c = src[j];
    if (c === "\\") { lit += src[j + 1] ?? ""; j += 2; continue; }
    if (c === '"') { j++; break; }
    if (c === "$" && src[j + 1] === "(") {
      const end = matchParen(src, j + 1);
      pieces += " " + skeleton(src.slice(j + 2, end)) + " ";
      j = end < n ? end + 1 : n;
      continue;
    }
    if (c === "`") { j = findChar(src, j + 1, "`") + 1; continue; }
    lit += c;
    j++;
  }
  return { text: placeholder(lit) + pieces, next: j };
}

// コマンド文脈としてスケルトン化する。引用符・ヒアドキュメントの状態は行をまたいで保つ。
function skeleton(src) {
  const heredocs = [];
  const n = src.length;
  let out = "";
  let i = 0;
  while (i < n) {
    const c = src[i];

    if (c === "\n") {
      out += "\n";
      i++;
      // 行末に達したら、その行で開かれたヒアドキュメントの本文を読み飛ばす。
      while (heredocs.length) {
        const delim = heredocs.shift();
        while (i < n) {
          let e = src.indexOf("\n", i);
          if (e === -1) e = n;
          const line = src.slice(i, e);
          i = e < n ? e + 1 : n;
          if (line.trim() === delim) break;
        }
      }
      continue;
    }

    if (c === "'") {
      const j = findChar(src, i + 1, "'");
      out += placeholder(src.slice(i + 1, j));
      i = j < n ? j + 1 : n;
      continue;
    }

    if (c === '"') {
      const r = scanDouble(src, i);
      out += r.text;
      i = r.next;
      continue;
    }

    if (c === "`") {
      const j = findChar(src, i + 1, "`");
      out += " __STR__ ";
      i = j < n ? j + 1 : n;
      continue;
    }

    if (c === "#" && atCommentBoundary(out)) {
      let e = src.indexOf("\n", i);
      if (e === -1) e = n;
      i = e;
      continue;
    }

    if (c === "<" && src[i + 1] === "<") {
      let k = i + 2;
      if (src[k] === "-") k++;
      while (k < n && /[ \t]/.test(src[k])) k++;
      let q = "";
      if (src[k] === "'" || src[k] === '"') { q = src[k]; k++; }
      let d = "";
      // デリミタは英字か _ で始まる。数字始まりを許すと算術シフト（`$((1<<2))`）を
      // heredoc と誤認し、デリミタ `2` が現れるまで入力を読み飛ばしてしまう。
      // 後続の `rm -rf /` がスケルトンから消え、危険判定を回避できる状態になる。
      if (!q && !/[A-Za-z_]/.test(src[k] ?? "")) { out += "<<"; i += 2; continue; }
      while (k < n && /[A-Za-z0-9_]/.test(src[k])) { d += src[k]; k++; }
      if (q && src[k] === q) k++;
      if (d) { heredocs.push(d); out += " << "; i = k; continue; }
      out += "<<"; i += 2; continue;
    }

    out += c;
    i++;
  }
  return out;
}
