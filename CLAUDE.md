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
```

## ディレクトリ構成

```text
docs/
├─ .vitepress/config.mjs  # サイト設定（nav / sidebar / Mermaid）
├─ guide/                 # チュートリアル本文
├─ hands-on/              # 実習（ハンズオン）コンテンツ
├─ practice/              # 実習で編集する練習用ページ（サンドボックス）
└─ index.md               # トップページ
.github/workflows/        # CI（ci.yml）/ PR タイトル検証（pr-title.yml）/ Pages デプロイ（deploy.yml）/ 外部リンク検査（links.yml）
.github/scripts/          # ワークフローから呼ぶスクリプト（check-pr-title.sh 等）
```

## コンテンツ執筆の規約

- 本文は日本語で、`docs/guide/` または `docs/hands-on/` に Markdown で追加する。
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
- 初期に無効化しているルール（将来、文章を直しながら順次有効化する）: `ja-no-mixed-period`（文末句点）/ `no-doubled-joshi`（助詞の連続）/ `no-mix-dearu-desumasu`（である・ですます混在）/ `sentence-length`（一文の長さ）/ `no-exclamation-question-mark`（！？の使用）/ `arabic-kanji-numbers` / `ja-no-weak-phrase` / `ja-no-redundant-expression`。
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

## 編集後チェック（checks.json 駆動フック）

「どのファイルを編集したら何を検査するか」を [.claude/checks.json](.claude/checks.json) に宣言的にまとめ、汎用 PostToolUse フック `.claude/hooks/on-edit-check.sh` がそれを読んで該当コマンドを実行する（例: `.md` 編集 → markdownlint、`docs/**/*.md` 編集 → textlint も）。

- `checks.json` の `onEdit` に `{ glob, run, label }` を追加すれば検査を増やせる。`run` 内の `{file}` は編集ファイルのパスに置換され、コマンドはリポジトリ直下で実行される。
- 違反があれば `exit 2` で Claude にフィードバックされる。対応 glob が無いファイルや、検査コマンド未導入（依存なし）の場合は**作業を止めない**（fail-open）。
- 設定を変えるだけで検査を足せるよう、ロジック（フック）とプロジェクト固有の対応表（`checks.json`）を分離している。
- **textlint** も markdownlint と同格で `onEdit` に登録し、docs 編集時に CI（`lint:text`）と同じ検査をローカル即時実行する（on-edit の対象は `docs/**/*.md`。ルート直下の `*.md` は CI の `lint:text` が担保する。textlint 未導入環境ではコマンド不在で fail-open）。
- **強調の描画検査**（`scripts/check-emphasis.mjs`）も同じく `docs/**/*.md` を対象に `onEdit` へ登録し、編集直後に CI（`lint:emphasis`）と同じ検査を走らせる。
- 構造ファイル（例: `config.mjs`）を編集したら関連ドキュメントの更新を促す `docs-sync-reminder.sh` も同様に checks.json の `docsSync`（`{ glob, remind }`）を読む。こちらは `exit 2`（ブロック）ではなく注意喚起（additionalContext）に留める。

## コミット/PR 衛生・安全ガード（guard フック）

PreToolUse フックで、コミットの衛生と危険操作の抑止を機械的に担保する（設定源は [.claude/checks.json](.claude/checks.json)）。

- **`guard-commit.sh`**: `git commit -m <msg>` のメッセージを Conventional Commits 正規表現で検証。
  非準拠なら `exit 2`。許可 type は `checks.json` の `commit.conventional.types`。
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
原文から行う）。

また `guard-branch` / `guard-secrets` は、**実際に操作が走る作業ツリー**を [.claude/hooks/lib/target-dir.sh](.claude/hooks/lib/target-dir.sh)
（コマンド中の `git -C <dir>` / `cd <dir>` を解決）で判定する。これにより `worktree-task` の worktree 上の
作業ブランチでの commit / push を「main 上の直接操作」と誤ブロックせず、guard-secrets も対象 worktree の
index を走査してシークレットを取りこぼさない（`$proj` 固定＝メイン作業ツリー基準による誤判定を防ぐ）。
回帰テストは [.claude/hooks/lib/guard-noise.test.sh](.claude/hooks/lib/guard-noise.test.sh)（worktree ケース含む）。

配線は [.claude/settings.json](.claude/settings.json) の `hooks.PreToolUse`。type 一覧・保護ブランチ名・
除外パターンは `checks.json` を編集するだけで変えられる（ロジックと設定の分離）。いずれのガードも
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
- [ ] 追加・変更ページのリンクが切れていない
- [ ] Mermaid 図がプレビューで正しく描画される

## CI / CD とセキュリティ方針

- **ci.yml**（PR 時）: `build`（VitePress ビルド）/ `lint`（markdownlint + textlint + 強調の描画）/ `config-check`（設定↔実体の整合）/ `test-hooks`（guard フック回帰テスト）/ `dependency-review`（依存の脆弱性検査）。
  - **test-hooks**: `scripts/test-hooks.sh`（`npm run test:hooks`）が `.claude/hooks/lib/*.test.sh`（例: `guard-noise.test.sh`）を一括実行し、guard 群のノイズ誤検知・worktree 対応・secrets 走査などのデグレを検知する。1 件でも失敗すれば CI が落ちる。
  - **config-check**: `scripts/check-config-consistency.mjs`（`npm run check:config`）が (a) `checks.json` のスキーマ（必須キー）・(b) `.claude/hooks/*.sh` の `settings.json` 配線（未配線/宙づり参照）・(c) `checks.json` の `issueLabels`/`prLabels` が参照するラベルの実在（`gh label list`）を検査。ネット/トークンが無い環境では (c) をスキップ（fail-open）。
- **pr-title.yml**（PR 時）: **PR タイトルが Conventional Commits 準拠か検証**する。Squash Merge では PR タイトルがマージコミットメッセージになるため。許可 type は `checks.json` の `commit.conventional.types`（`guard-commit.sh` と同一ソース）を `.github/scripts/check-pr-title.sh` が読む。
- **pr-label.yml**（PR 時）: **PR タイトルの type に応じてラベルを自動付与**する（`feat`→`type: feat` 等）。対応表は `checks.json` の `issueLabels.types`（`issue-label` skill と同一ソース）を `.github/scripts/label-pr-by-type.sh` が読む。対応表に無い type はスキップ。`type: *` ラベルの実体は [scripts/sync-labels.sh](scripts/sync-labels.sh) で用意する（`checks.json` の `commit.conventional.types` を情報源に冪等作成）。`pull-requests: write` が要るため pr-title と同じく base 側で評価する（`pull_request_target`）。
- **workflow-lint.yml**（`.github/workflows/**`・`.github/actions/**` 変更 PR 時）: ワークフロー自体を検査。**actionlint**（YAML/式/埋め込みシェルの静的解析）は blocking、**zizmor**（Actions セキュリティ監査＝`pull_request_target` 誤用・インジェクション・過剰権限）は**段階導入で非ブロッキング**（`continue-on-error`）。意図的に安全な `pull_request_target`（base 評価）の findings を整理後、`continue-on-error` を外して blocking 化する。Action は SHA ピン（Dependabot 更新）。
- **deploy.yml**: `main` への push で GitHub Pages へ自動デプロイ。
- **links.yml**: 週次で外部リンクの死活を検査（`--scheme http/https` で内部リンクは対象外）。
- **pr-links.yml**（`.md` 変更 PR 時）: lychee で **PR 時に外部リンク切れを可視化**（`docs/**/*.md`＋ルート `*.md`、外部スキームのみ）。週次 `links.yml` と同じ lychee-action・`.lycheeignore` を共有。外部リンク検査は flaky なため **`fail: false` の非ブロッキング**（PR ゲートにはしない方針を links.yml と共通化）。結果はジョブサマリに出て早期フィードバックになる。内部/相対リンクは `docs:build` が担保。
- **issue-label-cleanup.yml**: Issue クローズ時に `status: in-progress` ラベルを自動除去（`issues: write`）。
- **GitHub Actions は必ず commit SHA でピン留めし、`# vX.Y.Z` のバージョンコメントを添える**（Dependabot が更新）。
- ワークフローは**最小権限**（`permissions: contents: read` を既定）とし、`persist-credentials: false`、job には `timeout-minutes` を設定する。

## 対話・確認の作法

- **ユーザーの判断が要る分岐では、勝手に進めず `AskUserQuestion` ツールで選択肢を提示して確認する。** 対象は、スコープの取捨／設計方針の選択／削除・クローズの可否／トレードオフのある選択など、「答えがユーザーのもの」でコードや文脈からは一意に決められない分岐。推奨案があるときは選択肢の先頭に置き、ラベル末尾に「（推奨）」を付ける。
- ただし次は、いちいち聞かず最善案で進めてよい（進めた旨は一言添える）: 自明な既定・慣例があるもの／コード・ドキュメント・Git 履歴から検証できる事実／すでに合意済みの方針。
- 破壊的・不可逆・外向きの操作（削除・マージ・外部送信など）は、恒久的な許可がない限り事前確認する。

## エージェント向けメモ

- ファイルを編集したら、対応するチェック（`lint:md` / `docs:build`）をローカルで実行してから push する。
- 破壊的・外向きの操作（push、PR 作成、マージ、Issue 操作）は方針に沿って慎重に行う。
- `.claude/skills/` に補助 skill がある。**正典の一覧・役割・棲み分けは [.claude/skills/README.md](.claude/skills/README.md) を参照**（ここで個別に列挙するとドリフトするため一本化）。
