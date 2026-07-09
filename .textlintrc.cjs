// textlint 設定（段階導入）。
// 整形は markdownlint、日本語プロースは textlint、と役割を分ける。
// preset-ja-technical-writing を有効化しつつ、現行ドキュメントで多数発火する
// opinionated なルールは無効化し、既存文書を通しながら残りのルールで表記を整える。
//
// 発火の少ない no-exclamation-question-mark / arabic-kanji-numbers /
// ja-no-weak-phrase / ja-no-redundant-expression は文面を直して有効化済み（#257）。
// 下に残る 4 ルールは合計 180 件規模で発火するため、ルール単位で文章を直しながら
// 順次有効化していく（1 ルール 1 PR を目安）。
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
      "sentence-length": false
    }
  }
};
