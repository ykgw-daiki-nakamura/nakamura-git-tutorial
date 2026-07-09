# CLAUDE.md

このリポジトリで作業するエージェント／コントリビューター向けのガイドです。

## プロジェクト概要

Git / GitHub を**チーム開発で実践的に使いこなす**ための、図解付きチュートリアルサイトです。

- **技術スタック**: [VitePress](https://vitepress.dev/)（静的サイト）、Mermaid（ダイアグラム）、Node.js 20 以上、npm
- **コンテンツ言語**: 日本語
- **公開先**: GitHub Pages（<https://ykgw-daiki-nakamura.github.io/nakamura-git-tutorial/>）
- **性質**: このリポジトリ自体が **GitHub Flow の教材**であり、運用も GitHub Flow に揃えている

## コマンド

```bash
npm install          # 依存をインストール
npm run docs:dev     # 開発サーバー（既定 http://localhost:5173/）
npm run docs:build   # 本番ビルド（内部リンク切れ・Mermaid 構文エラーを検知）
npm run docs:preview # ビルド結果をプレビュー
npm run lint:md      # markdownlint-cli2 による Markdown 整形チェック
npm run lint:emphasis # 強調（**…**）が実際に太字として描画されるか検査
npm run check:anchors # 手書きのページ内アンカーが実 HTML の id と一致するか検査（docs:build の後）
npm run check:audit  # 依存の既知脆弱性を検査（CI の audit ジョブと同一）
```

## ディレクトリ構成

```text
docs/
├─ .vitepress/config.mjs  # サイト設定（nav / sidebar / Mermaid）
├─ guide/                 # チュートリアル本文
├─ standards/             # 開発規約（ブランチ / リリース / バージョン運用など）
├─ public/                # 静的アセット（favicon.svg / logo.svg）
└─ index.md               # トップページ
.github/workflows/        # CI（ci.yml）/ PR タイトル検証（pr-title.yml）/ Pages デプロイ（deploy.yml）/ 外部リンク検査（links.yml）
.github/scripts/          # ワークフローから呼ぶスクリプト（check-pr-title.sh 等）
.github/conventions.json  # コミット/PR 規約の単一情報源（許可 type・type→ラベル名）
.github/dependabot.yml    # 依存更新（npm は cooldown で公開直後のバージョンを寝かせる）
.github/security.json     # セキュリティポリシーの単一情報源（npm audit のしきい値・期限付き allowlist）
.npmrc                    # ignore-scripts=true（インストール時の任意コード実行を止める）
```

規約の語彙（許可 type・ラベル名）やセキュリティポリシー（`npm audit` のしきい値・除外）を `.claude/` ではなく `.github/` に置くのは、**それを強制するゲートが CI** だからです。CI は Claude を使わないコントリビューターにも効き、ハーネスを差し替えても残ります。`.claude/checks.json` に置くのは Claude だけが読む配線（`onEdit` / `guard.*` / `protectedBranches` など）に限り、`.github/` 配下のスクリプトが `.claude/` を読むことはありません。

## コンテンツ執筆の規約

- 本文は日本語で、`docs/guide/` に Markdown で追加する。
- **新規ページを追加したら `docs/.vitepress/config.mjs` の `sidebar` にも登録する**（登録漏れに注意）。
- VitePress の内部リンクは**拡張子なし**で書く（例: `[ブランチ](./branching)`）。実ファイルは `.md`。
- 図は Mermaid のコードフェンス（` ```mermaid `）で記述する。日本語ラベルを含む複雑な図は `"..."` で囲むと崩れにくい。

## Markdown Lint（markdownlint-cli2）

設定は [.markdownlint-cli2.jsonc](.markdownlint-cli2.jsonc)。無効化済みルール以外は既定で有効。ハマりやすい点:

- **MD031**: コードフェンスの前後には空行が必要（過去に CI 失敗の原因になった）。
- 無効化済み: MD013（行長）、MD033（インライン HTML）、MD041（先頭 H1）、MD024 は同一階層のみ重複禁止。
- **Markdown を編集したら push 前に必ず `npm run lint:md` を通すこと**（CI の `lint` ジョブと同一）。

## 日本語プロース Lint（textlint・段階導入）

文章表記の揺れ・冗長表現を検知するため、`textlint` + `textlint-rule-preset-ja-technical-writing` を導入している（`npm run lint:text`、CI の `lint` ジョブでも実行）。整形は markdownlint、**文章は textlint**、と役割を分ける。

- 設定は [.textlintrc.cjs](.textlintrc.cjs)。**段階導入**のため、現行ドキュメントで多数発火する opinionated なルールは初期は無効化し、既存文書を通しつつ残りのルールで表記を整える方針。
- 無効化しているルール（合計 180 件規模で発火するため、ルール単位で文章を直しながら順次有効化する。1 ルール 1 PR を目安）: `ja-no-mixed-period`（文末句点）/ `no-doubled-joshi`（助詞の連続）/ `no-mix-dearu-desumasu`（である・ですます混在）/ `sentence-length`（一文の長さ）。
- 有効化済みの opinionated ルール: `no-exclamation-question-mark`（感嘆符・疑問符の使用）/ `arabic-kanji-numbers`（漢数字とアラビア数字の統一）/ `ja-no-weak-phrase`（弱い表現）/ `ja-no-redundant-expression`（冗長表現）。
- 対象は `docs/**/*.md` とルート直下の `*.md`。`npm run lint:text -- --fix` で自動修正できる指摘もある（`npm run` に引数を渡すため `--` が必要）。

## 強調の描画 Lint（lint:emphasis）

`**…**` が**強調として描画されるか**を検査する（`npm run lint:emphasis`、CI の `lint` ジョブでも実行）。実装は [scripts/check-emphasis.mjs](scripts/check-emphasis.mjs)。

CommonMark の flanking 規則により、`）` `」` `` ` `` などの句読点が `**` に隣接すると開始／終了記号として認識されず、**`**` がそのまま本文に表示される**。日本語では踏みやすい。

```text
変更の**理由（コミットメッセージ）**を後から追える     ← 閉じが成立しない
いずれも**「出荷した線を…維持する」**ための仕組みです   ← 開きが成立しない
```

markdownlint（整形）も textlint（文章表現）もこれを見ず、`docs:build` は壊れたままビルドが通る。判定には実レンダリングが要るため、VitePress と同じ markdown-it に通して **`<strong>` の中身が原文の `**` の対応と一致するか**まで確かめる。`**` の個数だけを数えると、区切り記号が誤ってペアリングされて**意図と違う範囲が太字になる**ケースを取りこぼす。

- 直し方は**閉じ `**` の直後（開きが成立しない場合は直前）に半角スペースを 1 つ入れる**。太字の範囲は変えなくてよい。
- コードフェンス内・インラインコードスパン内・画像の `![alt](src)` は対象外（いずれも `**` が強調にならないため）。
- 行をまたぐ強調は意図を判定できないので見送る（`**` が奇数個の行はスキップ）。

## ページ内アンカーの検査（check:anchors）

Markdown に手で書いたページ内アンカー（`[マージルール](./branching#マージルール)` の fragment）が、ビルド後の HTML に実在する `id` と**バイト列まで一致するか**を検査する（`npm run check:anchors`、CI の `build` ジョブで `docs:build` の後に実行）。実装は [scripts/check-anchors.mjs](scripts/check-anchors.mjs)。

**日本語の見出しは濁点で壊れる。** VitePress が `id` を作る `slugify` は `normalize("NFKD")` で結合文字に分解したあと、`/[̀-ͯ]/`（ラテン文字の結合記号）しか取り除かない。日本語の濁点 `U+3099` / 半濁点 `U+309A` はこの範囲外なので分解されたまま残り、`id` が NFD で出力される。

```text
HTML の id : "導入までの暫定規約" → … 3066 3099 …   （て + 結合濁点 U+3099）
md のリンク: "#導入までの暫定規約" → … 3067 …        （合成済みの で）
```

ブラウザの fragment 照合は Unicode 正規化をしないため、この 2 つは一致せず**リンクを踏んでもスクロールしない**。VitePress 自身が出すリンク（右のアウトライン、見出しの permalink）は同じ `id` から導出されるので一致してしまい、**壊れるのは人間が手で書いたアンカーだけ**。だから見つけにくい。

- 対処は [docs/.vitepress/config.mjs](docs/.vitepress/config.mjs) の `markdown.anchor.slugify` で `id` を **NFC 正規化**すること。アウトラインや permalink も同じ `id` から導出されるため整合する。
- `@mdit-vue/shared` は vitepress にバンドルされていて import できないため、`slugify` の実装を写している。**追随漏れの防波堤がこの検査**で、上流の実装が変わって `id` がずれれば `check:anchors` が落ちる。
- 既存の検査はどれもこれを見ない。**markdownlint（MD051）** は GitHub 方式の別 slugify で fragment を判定するため「有効」と誤判定する。**`docs:build`** のデッドリンク検査はページの存在は見るが、アンカーの存在は見ない。判定には実レンダリング結果が要る（`lint:emphasis` と同じ発想）。
- `dist` が無ければ**明示エラーで落ちる**（fail-open にしない）。検査していないのに緑、を作らないため。この検査だけ `onEdit` フックに載せていないのも、ビルド成果物を要求して 1 回 20 秒以上かかるため。CI が担保する。

## 依存の脆弱性ゲート（check:audit）

`npm audit` の結果を **advisory 単位**で判定し、しきい値以上の未対処があれば CI を落とす（`npm run check:audit`、CI の `audit` ジョブ）。実装は [scripts/check-audit.mjs](scripts/check-audit.mjs)、ポリシーは [.github/security.json](.github/security.json)。

`dependency-review` だけでは足りない。あれは **その PR が追加・更新した依存**しか見ないので、すでに lockfile に載っている依存に後から advisory が生えても、CI は緑のまま素通りする。

- **しきい値** `audit.failOn`（既定 `high`）は `dependency-review-action` の `fail-on-severity` と揃える。両者は対象（lockfile 全体／PR が追加・更新した依存）が違うので 1 か所には寄せられないぶん、`check:config` の (e) が値の一致を機械的に検査する。しきい値未満の advisory は情報として表示するだけで落とさない。
- **除外は期限付きにする**（`audit.allow` の `{ ghsa, reason, expires }`）。上流に修正が無い advisory は必ず出る（例: vitepress が古い vite に固定している）。素朴にゲートすると CI が永久に赤くなり、いずれ `--audit-level` を緩めて検査全体が形骸化する。だから GHSA 単位で理由と再評価期限を書いて除外し、**期限を過ぎたら CI で落とす**。「除外したまま忘れる」を仕組みで防ぐのがこの設計の要点で、`reason` と `expires` の無い除外は設定不正として弾く。
- allowlist にあるのに現在はどの advisory にも該当しないエントリ（依存の更新で解消した等）は**警告のみ**で落とさない。効いていない除外が積もったら消す。
- `npm audit` はレジストリへの問い合わせが要る。結果を解釈できない場合（ネットワーク不通など）は **fail-open**。guard 群と同じ思想で、検査できないことを「悪い」とは扱わない。

## 編集後チェック（checks.json 駆動フック）

「どのファイルを編集したら何を検査するか」を [.claude/checks.json](.claude/checks.json) に宣言的にまとめ、汎用 PostToolUse フック `.claude/hooks/on-edit-check.sh` がそれを読んで該当コマンドを実行する（例: `.md` 編集 → markdownlint、`docs/**/*.md` 編集 → textlint も）。

- `checks.json` の `onEdit` に `{ glob, run, label }` を追加すれば検査を増やせる。`run` 内の `{file}` は編集ファイルのパスに置換され、コマンドはリポジトリ直下で実行される。
- 違反があれば `exit 2` で Claude にフィードバックされる。対応 glob が無いファイルや、検査コマンド未導入（依存なし）の場合は**作業を止めない**（fail-open）。
- 設定を変えるだけで検査を足せるよう、ロジック（フック）とプロジェクト固有の対応表（`checks.json`）を分離している。
- **textlint** も markdownlint と同格で `onEdit` に登録し、docs 編集時に CI（`lint:text`）と同じ検査をローカル即時実行する（on-edit の対象は `docs/**/*.md`。ルート直下の `*.md` は CI の `lint:text` が担保する。textlint 未導入環境ではコマンド不在で fail-open）。
- **強調の描画検査**（`scripts/check-emphasis.mjs`）も同じく `docs/**/*.md` を対象に `onEdit` へ登録し、編集直後に CI（`lint:emphasis`）と同じ検査を走らせる。
- **依存の脆弱性検査**（`scripts/check-audit.mjs`）は `package*.json` を対象に `onEdit` へ登録し、依存を触った直後に CI（`audit`）と同じ検査を走らせる。ここに置くのは「いつ走らせるか」の配線だけで、しきい値と除外そのものは `.github/security.json` にある。
- 構造ファイル（例: `config.mjs`）を編集したら関連ドキュメントの更新を促す `docs-sync-reminder.sh` も同様に checks.json の `docsSync`（`{ glob, remind }`）を読む。こちらは `exit 2`（ブロック）ではなく注意喚起（additionalContext）に留める。

## コミット/PR 衛生・安全ガード（guard フック）

PreToolUse フックで、コミットの衛生と危険操作の抑止を機械的に担保する（設定源は [.claude/checks.json](.claude/checks.json)。
ただし**許可 type だけは CI と共有する規約の語彙**なので [.github/conventions.json](.github/conventions.json) が持つ）。

- **`guard-commit.sh`**: `git commit -m <msg>` のメッセージを Conventional Commits 正規表現で検証。
  非準拠なら `exit 2`。許可 type は `.github/conventions.json` の `commit.conventional.types`。
  コマンド置換（`$(...)`）や `-F`・エディタ起動など**静的判定できない**ケースは fail-open。
- **`guard-branch.sh`**: 保護ブランチ（`checks.json` の `protectedBranches`、既定 `main`）上での
  直接 `commit` / `push` を `exit 2` で阻止し、作業ブランチの作成を促す。
- **`guard-dangerous.sh`**: 明確に破壊的・危険な Bash コマンドを `exit 2` で阻止する。対象は
  ルート/ホーム近傍の再帰削除（`rm -rf /`・`~`・`--no-preserve-root`）、保護ブランチへの
  `git push --force` / `--force-with-lease`、`curl … | bash` 等の未検証スクリプト実行、
  未コミット変更がある状態での `git reset --hard`。誤検知は `checks.json` の
  `guard.dangerous.allow`（正規表現）で通せる。
- **`guard-secrets.sh`**: `git add` / `git commit` 時にシークレット混入を阻止する。ステージ差分の
  追加行と対象ファイル名を走査し、秘密鍵ヘッダ・AWS/GitHub/Slack/Google/Stripe のキー形式・
  `.env` 等の秘匿ファイル（`.env.example` 等のサンプルは除外）を検出したら `exit 2`。
  `git add .` / `-A` のように対象を列挙できない場合は commit 時の走査が最終防波堤になる。
  検出時は **stderr へ値を出さず位置（行番号）のみ**を示す。教材として `.env`・API キーを扱う
  `docs/`（`checks.json` の `guard.secrets.skipPaths`）配下と、`example` 等のプレースホルダ例は
  過剰ブロックを避けるため走査対象外。誤検知は `guard.secrets.allow`（正規表現）で通せる。

- **`guard-diffsize.sh`**: `git push` / `gh pr create` の直前に、`origin/main` との差分行数（追加+削除）を
  測り、`checks.json` の `guard.diffSize.maxLines`（既定 400）を超えたら **Issue/PR 分割の検討を促す**。
  `exit 2` の**ブロックはせず**、`docs-sync-reminder.sh` と同じ非ブロッキングの注意喚起（`additionalContext`）
  に留める。生成物・ロックファイルは `guard.diffSize.skipPaths`（パス接頭辞）で集計から除外。誤検知は
  `guard.diffSize.allow`（正規表現）で対象外にできる。ベース取得不能・依存欠如時は fail-open。

上記 4 つのブロック系ガード（commit/branch/dangerous/secrets）は、コマンド種別の判定前に [.claude/hooks/lib/cmd-skeleton.js](.claude/hooks/lib/cmd-skeleton.js) で
**ヒアドキュメント本文・引用符内・コメントを除去**した「スケルトン」を作り、それに対して判定する。
これにより、docs / skills / Issue 本文に書いた `git push` / `git commit` / `rm -rf /` などの**文字列**
（＝実行されないコマンド）を実コマンドと誤判定して過剰ブロックするのを防ぐ（値・パス・ブランチの抽出は
原文から行う）。走査は**入力全体を 1 本のスキャナで舐める**（行ごとに独立に見ると、複数行にわたる
引用符の途中で状態を見失い、本文が生のまま判定対象に漏れる）。ヒアドキュメント開始 `<<WORD` は
**コマンド文脈でのみ**検出し、`"<<EOF"` のような引用符内の文字列は開始と見なさない。ただし二重引用符の
内側でも `$( ... )` の中はコマンド文脈なので検出する（`--body "$(cat <<'BODY' … BODY)"` の本文を
判定対象から外すため）。二重引用符内のバッククォート区間はコマンド置換なので中身ごと落とす
（本文に Markdown のコードフェンスを含めても漏れない）。

危険判定そのものも**引数の位置**を見る。`guard-dangerous` の再帰削除チェックは、スケルトン全体から
`/` を探すのではなく `rm` の引数だけを走査する。日本語の散文で多用する「A / B」の区切りスラッシュに
反応して、`rm` の記述が同居しただけでブロックするのを防ぐ。

また `guard-branch` / `guard-secrets` は、**実際に操作が走る作業ツリー**を [.claude/hooks/lib/target-dir.sh](.claude/hooks/lib/target-dir.sh)
（コマンド中の `git -C <dir>` / `cd <dir>` を解決）で判定する。これにより `worktree-task` の worktree 上の
作業ブランチでの commit / push を「main 上の直接操作」と誤ブロックせず、guard-secrets も対象 worktree の
index を走査してシークレットを取りこぼさない（`$proj` 固定＝メイン作業ツリー基準による誤判定を防ぐ）。
回帰テストは [.claude/hooks/lib/guard-noise.test.sh](.claude/hooks/lib/guard-noise.test.sh)（worktree ケース含む）。

配線は [.claude/settings.json](.claude/settings.json) の `hooks.PreToolUse`。保護ブランチ名・除外パターンは
`checks.json`、許可 type は `.github/conventions.json` を編集するだけで変えられる（ロジックと設定の分離）。いずれのガードも
依存（`jq`/`node`/`git`）が無い環境では fail-open で作業を止めない。**ガードは正当な理由なく
迂回しない**こと。ステージ差分からのコミット生成は `.claude/skills/commit` を使う。

## 開発フロー（GitHub Flow）

1. **着手前に計画を GitHub Issue にまとめる。** 数行の docs 修正など些細な変更でも例外にしない。目的・スコープ・作業計画（チェックリスト）・完了条件を書く。既存の計画 Issue があればそれを使う。計画立案から Issue 化までは `.claude/skills/plan`（**実装はせず Issue 作成で止める**）を使うと手順を踏み外さない。**着手したら Issue に `status: in-progress` ラベルを付与し自分をアサインする**（`gh issue edit <Issue> --add-label "status: in-progress" --add-assignee @me`）。一覧で着手中を判別でき、複数人／エージェントでの二重着手を防げる。
2. 最新の `main` からブランチを切る。接頭辞は `feat/` `fix/` `docs/` `chore/` `ci/`。
3. 変更してコミットする（下記のコミット規約）。
4. `git push -u origin <branch>` して Pull Request を作成する（テンプレートが自動挿入される）。**PR 本文に `Closes #<Issue>` を記載して連動 Issue にリンクする**（マージ時に GitHub が自動クローズ）。**PR タイトルも Conventional Commits 形式にする**（Squash Merge のためタイトルがそのまま `main` のコミットメッセージになる。`pr-title.yml` が検証）。
5. CI が通り、レビューで承認されたらマージする。

Issue / PR には GitHub テンプレートが用意されている。Issue は [.github/ISSUE_TEMPLATE/](.github/ISSUE_TEMPLATE/)（計画 Issue: `plan.md` ／ バグ報告: `bug.md`）から選ぶと、上記の「目的・スコープ・作業計画・完了条件」が雛形として入る。PR は [.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md) が自動挿入され、`Closes #<Issue>` 欄と提出前チェックリスト（`docs:build` / `lint:md`）が最初から並ぶ。

> **エージェント補足**: コミットを伴う作業は原則 `.claude/skills/worktree-task` を既定経路にすると、この「Issue 化 → ブランチ → PR リンク」を手順として踏み外さない。行き当たりばったりで素手編集を始めない。

### コミットメッセージ（Conventional Commits）

`type(scope): summary` 形式に従う。`type` は `feat` `fix` `docs` `chore` `ci` など。要約は簡潔に。

```text
docs(guide): ブランチ命名規則の例を追加
```

### 提出前チェック

- [ ] `npm run docs:build` が通る（CI と同じ検証）
- [ ] `npm run lint:md` が通る
- [ ] `npm run lint:text` が通る（日本語プロース・CI と同一）
- [ ] `npm run lint:emphasis` が通る（強調の描画・CI と同一）
- [ ] `npm run check:anchors` が通る（ページ内アンカー・`docs:build` の後に実行）
- [ ] 依存を変えたなら `npm run check:audit` が通る（脆弱性・CI と同一）
- [ ] 追加・変更ページのリンクが切れていない
- [ ] Mermaid 図がプレビューで正しく描画される

## CI / CD とセキュリティ方針

- **ci.yml**（PR 時）: `build`（VitePress ビルド + ページ内アンカー検査）/ `lint`（markdownlint + textlint + 強調の描画）/ `config-check`（設定↔実体の整合）/ `test-hooks`（guard フック回帰テスト）/ `dependency-review`（PR が追加・更新する依存の脆弱性検査）/ `audit`（lockfile 全体の脆弱性検査）。
  - **build**: `docs:build` の後に `check:anchors` を走らせる。手書きのページ内アンカーが実 HTML の `id` と一致するかは、ビルド成果物が無いと判定できない（上記「ページ内アンカーの検査」）。
  - **audit**: `scripts/check-audit.mjs`（`npm run check:audit`）が `npm audit` を advisory 単位で判定する。`dependency-review` は **その PR が追加・更新した依存**しか見ないため、既に lockfile に載っている依存に後から advisory が生えても検知できない。その穴を塞ぐジョブ。しきい値と除外は `.github/security.json`（下記「依存の脆弱性ゲート」）。`npm audit` は lockfile とレジストリだけで動くので `npm ci` は不要。
  - **test-hooks**: `scripts/test-hooks.sh`（`npm run test:hooks`）が `.claude/hooks/lib/*.test.sh` を一括実行する。`guard-noise.test.sh` は guard 群のノイズ誤検知・worktree 対応・secrets 走査を、`orphan-detect.test.sh` は `detect-orphan-worktrees.sh` が切りたてブランチを撤去候補にしないことを検証する。1 件でも失敗すれば CI が落ちる。
  - **config-check**: `scripts/check-config-consistency.mjs`（`npm run check:config`）が (a) `conventions.json` / `security.json` / `checks.json` のスキーマ（必須キー・type 一覧とラベル対応表の過不足・audit の除外に理由と期限があるか）・(b) `.claude/hooks/*.sh` の `settings.json` 配線（未配線/宙づり参照）・(c) `conventions.json` の `labels.types` と `checks.json` の `issueLabels`/`prLabels` が参照するラベルの実在（`gh label list`）・(d) 検証スクリプトのフォールバック `default_types`（`check-pr-title.sh` / `guard-commit.sh`）が `conventions.json` の `commit.conventional.types` と順序含めて一致すること・(e) `ci.yml` の `fail-on-severity` が `security.json` の `audit.failOn` と一致することを検査。ネット/トークンが無い環境では (c) をスキップ（fail-open）。
- **pr-title.yml**（PR 時）: **PR タイトルが Conventional Commits 準拠か検証**する。Squash Merge では PR タイトルがマージコミットメッセージになるため。許可 type は `.github/conventions.json` の `commit.conventional.types`（`guard-commit.sh` と同一ソース）を `.github/scripts/check-pr-title.sh` が読む。
- **pr-label.yml**（PR 時）: **PR タイトルの type に応じてラベルを自動付与**する（`feat`→`type: feat` 等）。対応表は `.github/conventions.json` の `labels.types`（`issue-label` skill と同一ソース）を `.github/scripts/label-pr-by-type.sh` が読む。対応表に無い type はスキップ。`type: *` ラベルの実体は [scripts/sync-labels.sh](scripts/sync-labels.sh) で用意する（同じ `conventions.json` を情報源に冪等作成）。`pull-requests: write` が要るため pr-title と同じく base 側で評価する（`pull_request_target`）。
- **workflow-lint.yml**（`.github/workflows/**`・`.github/actions/**` 変更 PR 時）: ワークフロー自体を検査。**actionlint**（YAML/式/埋め込みシェルの静的解析）は blocking、**zizmor**（Actions セキュリティ監査＝`pull_request_target` 誤用・インジェクション・過剰権限）は**段階導入で非ブロッキング**（`continue-on-error`）。意図的に安全な `pull_request_target`（base 評価）の findings を整理後、`continue-on-error` を外して blocking 化する。Action は SHA ピン（Dependabot 更新）。
- **deploy.yml**: `main` への push で GitHub Pages へ自動デプロイ。
- **links.yml**: 週次で外部リンクの死活を検査（`--scheme http/https` で内部リンクは対象外）。
- **pr-links.yml**（`.md` 変更 PR 時）: lychee で **PR 時に外部リンク切れを可視化**（`docs/**/*.md`＋ルート `*.md`、外部スキームのみ）。週次 `links.yml` と同じ lychee-action・`.lycheeignore` を共有。外部リンク検査は flaky なため **`fail: false` の非ブロッキング**（PR ゲートにはしない方針を links.yml と共通化）。結果はジョブサマリに出て早期フィードバックになる。内部/相対リンクは `docs:build` が担保。
- **issue-label-cleanup.yml**: Issue クローズ時に `status: in-progress` ラベルを自動除去（`issues: write`）。
- **GitHub Actions は必ず commit SHA でピン留めし、`# vX.Y.Z` のバージョンコメントを添える**（Dependabot が更新）。
- ワークフローは**最小権限**（`permissions: contents: read` を既定）とし、`persist-credentials: false`、job には `timeout-minutes` を設定する。

## サプライチェーン対策（cooldown / ignore-scripts）

脆弱性の**検知**（`dependency-review`）と、悪性パッケージの**取り込み・実行の抑止**は別の話。後者は 2 層で受ける。

**1. Dependabot の cooldown**（[.github/dependabot.yml](.github/dependabot.yml)）。npm のサプライチェーン攻撃は「悪性バージョンを公開し、気付かれるまでの数時間〜数日で拡散する」形をとる。数日寝かせるだけで大半を回避できる。**cooldown は version update にのみ効き、security update は素通しする**ため、脆弱性修正が遅れる副作用は無い。既定は `default-days: 7` / `semver-major-days: 14`。

- **`github-actions` には付けない。** このエコシステムの cooldown はリリース公開日ではなくタグのコミット日で判定し（[dependabot-core#13078](https://github.com/dependabot/dependabot-core/issues/13078)）、頻繁にリリースされる Action の更新が事実上止まる報告がある（[#13691](https://github.com/dependabot/dependabot-core/issues/13691) / [#14645](https://github.com/dependabot/dependabot-core/issues/14645)）。SHA ピンの鮮度をこの更新に依存している以上、止まる方が危ない。タグ再付与による Action 改竄には SHA ピン自体が効いている。
- **cooldown は推移的依存に効かない**（[#14683](https://github.com/dependabot/dependabot-core/issues/14683)）。lockfile に引き込まれる依存は公開直後でも入りうる。だから 2 層目が要る。
- npm 自体の `min-release-age` は**採用しない**。Dependabot が上げた新しめのバージョンを lockfile が指したまま `npm ci` に拒否され、CI が通らなくなる衝突が報告されている。

**2. `ignore-scripts`**（[.npmrc](.npmrc)）。インストール時のライフサイクルスクリプト（`preinstall` / `install` / `postinstall` / `prepare`）を実行しない。悪性パッケージが任意コードを走らせる主要な経路がここなので、取り込んでしまってもインストール段階では実行されない。cooldown が取りこぼす推移的依存に対しては、この層が防波堤になる。

- 本リポジトリの依存で install スクリプトを持つ（lockfile の `hasInstallScript`）のは **esbuild と fsevents の 2 つ**。esbuild（`postinstall: node install.js`）はバイナリを `optionalDependencies` の `@esbuild/<platform>` から入れるため飛ばしても `docs:build` は通る。fsevents は darwin 限定の optional で、macOS の dev サーバーのファイル監視を速くするだけ（入らなければポーリングにフォールバックし、CI の linux ではそもそも入らない）。
- 明示的に呼ぶ `npm run <script>` は影響を受けない。一時的に必要なら `npm install --ignore-scripts=false` か `npm rebuild <pkg>`。
- 将来 `postinstall` が本当に要る依存を入れると**ビルドが目に見えて壊れる**ので、黙って通り過ぎることはない。

## 対話・確認の作法

- **ユーザーの判断が要る分岐では、勝手に進めず `AskUserQuestion` ツールで選択肢を提示して確認する。** 対象は、スコープの取捨／設計方針の選択／削除・クローズの可否／トレードオフのある選択など、「答えがユーザーのもの」でコードや文脈からは一意に決められない分岐。推奨案があるときは選択肢の先頭に置き、ラベル末尾に「（推奨）」を付ける。
- ただし次は、いちいち聞かず最善案で進めてよい（進めた旨は一言添える）: 自明な既定・慣例があるもの／コード・ドキュメント・Git 履歴から検証できる事実／すでに合意済みの方針。
- 破壊的・不可逆・外向きの操作（削除・マージ・外部送信など）は、恒久的な許可がない限り事前確認する。

## エージェント向けメモ

- ファイルを編集したら、対応するチェック（`lint:md` / `docs:build`）をローカルで実行してから push する。
- 破壊的・外向きの操作（push、PR 作成、マージ、Issue 操作）は方針に沿って慎重に行う。
- `.claude/skills/` に補助 skill がある。**正典の一覧・役割・棲み分けは [.claude/skills/README.md](.claude/skills/README.md) を参照**（ここで個別に列挙するとドリフトするため一本化）。
