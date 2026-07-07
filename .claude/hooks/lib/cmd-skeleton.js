// guard 群の共通ヘルパ。
// stdin: Bash ツールの生コマンド文字列（複数行可）。
// stdout: コマンド種別判定用の「スケルトン」。
//   - ヒアドキュメント本文（<<'EOF' ... EOF / <<EOF / <<-EOF）を丸ごと除去。
//     ヒアドキュメント開始 << は **引用符の外** でのみ検出する（引用符内の "<<EOF" のような
//     文字列を開始と誤認して以降の実コマンド行を捨てないため）。
//   - シングル/ダブルクオートで囲まれた文字列を単一プレースホルダ __STR__ に置換
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
const PRESERVE = ["--force-with-lease", "--no-preserve-root", "--force", "${HOME}", "$HOME", "/", "~"];

let s = "";
process.stdin.on("data", (d) => (s += d)).on("end", () => {
  const lines = s.split("\n");
  const out = [];
  let heredoc = null;
  for (const line of lines) {
    if (heredoc !== null) {
      if (line.trim() === heredoc) heredoc = null;
      continue;
    }
    const res = scrubLine(line);
    out.push(res.text);
    if (res.heredoc) heredoc = res.heredoc;
  }
  process.stdout.write(out.join("\n"));
});

// 引用符内の内容を潰す。--danger 時は危険トークンだけ残す。
function placeholder(content) {
  let out = " __STR__ ";
  if (DANGER) {
    for (const tok of PRESERVE) {
      if (content.includes(tok)) out += tok + " ";
    }
  }
  return out;
}

// 1 行を走査。引用符内を placeholder に、コメントを除去し、引用符の外でのみ heredoc 開始を検出。
function scrubLine(line) {
  let r = "";
  let i = 0;
  const n = line.length;
  let heredoc = null;
  while (i < n) {
    const c = line[i];
    if (c === "'") {
      let j = i + 1;
      while (j < n && line[j] !== "'") j++;
      r += placeholder(line.slice(i + 1, j));
      i = j < n ? j + 1 : n;
      continue;
    }
    if (c === '"') {
      let j = i + 1;
      while (j < n) {
        if (line[j] === "\\") { j += 2; continue; }
        if (line[j] === '"') break;
        j++;
      }
      r += placeholder(line.slice(i + 1, Math.min(j, n)));
      i = j < n ? j + 1 : n;
      continue;
    }
    if (c === "#" && (r === "" || /[\s;&|(]$/.test(r))) break;
    if (c === "<" && line[i + 1] === "<") {
      let k = i + 2;
      if (line[k] === "-") k++;
      while (k < n && /\s/.test(line[k])) k++;
      let q = "";
      if (line[k] === "'" || line[k] === '"') { q = line[k]; k++; }
      let d = "";
      while (k < n && /[A-Za-z0-9_]/.test(line[k])) { d += line[k]; k++; }
      if (q && line[k] === q) k++;
      if (d) { heredoc = d; r += " << "; i = k; continue; }
      r += "<<"; i += 2; continue;
    }
    r += c;
    i++;
  }
  return { text: r, heredoc };
}
