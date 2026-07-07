---
name: issue-label
description: >-
  GitHub Issue の内容（タイトル・本文）から適切なラベルを判定して付与する skill。
  タイトルの Conventional Commits の <type>（feat/fix/docs…）を主ラベルへ、本文/対象パスから
  領域ラベル（harness / documentation / dependencies / github_actions 等）を推定し、
  実在するラベルだけを `gh issue edit --add-label` で付ける。対応表は checks.json の `issueLabels`。
  着手中を示す `status: in-progress` は worktree-task 側の責務なので付けない。
  「Issue にラベルを付けて」「#12 に適切なラベルを」「作った Issue を分類して」等で使う。
  Decide and apply appropriate labels to a GitHub Issue from its title/body.
---

# issue-label — Issue の内容からラベルを判定して付ける

GitHub Issue のタイトル・本文を読み、**実在するラベルだけ**を判定して付与する skill。
ラベルの語彙・対応規則は [.claude/checks.json](../../checks.json) の `issueLabels` に集約し、
**ロジック（この skill）と対応表（設定）を分離**する（guard 系・on-edit-check 系と同じ設計）。

## 使いどころ / 使わない場面

- 使う: 起票した（あるいは既存の）Issue に領域・種別ラベルを付けて分類したいとき。
- 付けない: **`status: in-progress`（着手中）は付けない**。着手宣言は `worktree-task` の責務。
- 作らない: **存在しないラベルは自動作成しない**（`gh label create` はしない）。対応表が指すラベルが
  実在しなければスキップし、その旨を報告する。

## 引数

`args` は自由記述。**対象 Issue 番号**を読み取る（例 `12`）。省略時は直近の会話で作成／言及した Issue。

## 手順

### 1. 対象 Issue と実在ラベルを取得

```bash
gh issue view <N> --json number,title,body,labels
gh label list --limit 200 --json name --jq '.[].name'   # 実在ラベル（付与はこの集合内のみ。--limit で全件取得）
```

### 2. 対応表を読む

`checks.json` の `issueLabels` を読む（`jq` があれば利用、無ければ内容から判断＝fail-open）。

```bash
jq -r '.issueLabels' .claude/checks.json
```

- **`types`**: タイトル先頭の Conventional Commits `type`（`feat` / `fix` / `docs` / `chore` /
  `ci` / `build` / `refactor` / `test` / `perf` / `style` / `revert`）→ 種別ラベル（`type: feat` /
  `type: fix` …）。表に無い type があればその type は主ラベルを付けず領域ラベルに委ねる（現状は
  全 type を網羅）。**`type: *` ラベルの実体は [scripts/sync-labels.sh](../../../scripts/sync-labels.sh)
  で用意する**。この skill は実在しないラベルは付けない（対応表が指すラベルが未作成ならスキップ）。
- **タイトルの scope も強い手がかり**: `chore(harness):` の `(harness)` のように、Conventional
  Commits の scope は領域を直接示すことが多い。scope と `areas` の照合を合わせて判断する。
- **`areas`**: 各 `{ label, match }` の `match`（正規表現・**大小無視**）は**判定の手がかり**。
  Issue が**主に扱っている領域**にだけ付ける。判断は**タイトルと目的（冒頭）を最優先**にし、本文は
  補強に使う。**通常は 1〜2 個**。`## 依存 / 参考`・`## スコープ（含まない）`・例示など、**主題でない
  箇所の言及に釣られて付けすぎない**（plan テンプレートはほぼ全 Issue にこれらの節を持つため、
  素朴な全文一致は過剰になる）。手がかりが無ければ領域ラベルは付けなくてよい。
- **`triage`**: `question` / `good first issue` 等は、本文に明確な兆候（質問・初心者向け明記など）が
  あるときだけ付ける。機械的には付けない。

### 3. 付与案を提示して合意

- 付けるラベルと**根拠を1行ずつ**提示する（例: `type: fix ← type=fix`、`harness ← 本文に .claude/ を含む`）。
- **実在しないラベル**（`gh label list` に無い）は候補から除外し、除外したことも報告する。
- 既に付いているラベルは重複させない。外すべきラベルがあれば提案に留める（自動では外さない）。

### 4. 適用

合意後、実在ラベルだけを付ける。

```bash
gh issue edit <N> --add-label "type: fix" --add-label "harness"
```

- 付与結果（付けた／スキップした理由）を報告する。`status: in-progress` は付けない。

## worktree-task との棲み分け

- **issue-label** = Issue を**分類する**（種別・領域ラベル）。内容ベースで、着手状態は扱わない。
- **worktree-task** = 実装に**着手する**際に `status: in-progress` を付与＋アサインする。

対応表（`issueLabels`）を編集するだけでラベル規則を変えられる。skill 側にラベル名をハードコードしない。
