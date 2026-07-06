// guard 群の共通ヘルパ。
// stdin: Bash ツールの生コマンド文字列（複数行可）。
// stdout: コマンド種別判定用の「スケルトン」。
//   - ヒアドキュメント本文（<<'EOF' … EOF / <<EOF / <<-EOF）を丸ごと除去
//   - シングル/ダブルクオートで囲まれた文字列を単一プレースホルダ __STR__ に置換
//   - `#` から行末までのコメントを除去（語境界＝行頭または空白直後の # のみ）
// これにより、docs / skills / Issue 本文に書かれた `git push` 等の文字列
// （＝実行されないコマンド）が種別判定で誤ヒットするのを防ぐ。
// 値（コミットメッセージ・パス・ブランチ名）の抽出は各 guard 側で原文から行う。
let s = "";
process.stdin.on("data", (d) => (s += d)).on("end", () => {
  const lines = s.split("\n");
  const out = [];
  let heredoc = null; // 現在アクティブな終端デリミタ（なければ null）
  for (const line of lines) {
    if (heredoc !== null) {
      // 終端行（<<- はインデント許容）で本文終了。本文・終端行とも出力しない。
      if (line.trim() === heredoc) heredoc = null;
      continue;
    }
    // ヒアドキュメント開始を検出（デリミタは引用の有無いずれも可）
    const hd = line.match(/<<-?\s*(['"]?)([A-Za-z_][A-Za-z0-9_]*)\1/);
    out.push(scrub(line));
    if (hd) heredoc = hd[2];
  }
  process.stdout.write(out.join("\n"));
});

function scrub(line) {
  let r = "";
  let i = 0;
  const n = line.length;
  while (i < n) {
    const c = line[i];
    if (c === "'") {
      // シングルクオート: 次の ' までリテラル
      let j = i + 1;
      while (j < n && line[j] !== "'") j++;
      r += " __STR__ ";
      i = j < n ? j + 1 : n;
      continue;
    }
    if (c === '"') {
      // ダブルクオート: 次の " まで（\" はエスケープ）
      let j = i + 1;
      while (j < n) {
        if (line[j] === "\\") { j += 2; continue; }
        if (line[j] === '"') break;
        j++;
      }
      r += " __STR__ ";
      i = j < n ? j + 1 : n;
      continue;
    }
    if (c === "#" && (r === "" || /\s$/.test(r))) {
      break; // 語境界のコメント → 行末まで捨てる
    }
    r += c;
    i++;
  }
  return r;
}
