// textlint 設定（段階導入）。
// 整形は markdownlint、日本語プロースは textlint、と役割を分ける。
// preset-ja-technical-writing を有効化しつつ、現行ドキュメントで多数発火する
// opinionated なルールは初期は無効化し、既存文書を通しながら残りのルールで表記を整える。
// 将来、文章を直しながら無効化ルールを順次有効化していく。
module.exports = {
  rules: {
    "preset-ja-technical-writing": {
      // 文末が「。」で終わっていない（表・箇条書き断片・リンク終端で多数の誤検知）
      "ja-no-mixed-period": false,
      // 一文に同じ助詞が連続（有用だが初期ノイズが大きい）
      "no-doubled-joshi": false,
      // 「である」調と「ですます」調の混在（表・見出し断片で誤検知）
      "no-mix-dearu-desumasu": false,
      // 一文の長さ上限（行長 MD013 同様に本教材では抑制）
      "sentence-length": false,
      // 「！」「？」の使用（親しみやすい文体・見出しの疑問形で意図的に使用）
      "no-exclamation-question-mark": false,
      // アラビア数字と漢数字の統一
      "arabic-kanji-numbers": false,
      // 弱い表現（〜と思います 等）
      "ja-no-weak-phrase": false,
      // 冗長表現
      "ja-no-redundant-expression": false
    }
  }
};
