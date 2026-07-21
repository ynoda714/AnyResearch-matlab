# 変更履歴

&nbsp; [English](../../CHANGELOG.md)

このファイルは [CHANGELOG.md](../../CHANGELOG.md) の日本語ミラーです。
詳細な実装履歴や開発メモは private な dev リポジトリ側で管理します。

## Unreleased

## 1.10.1 - 2026-07-21

### 修正
- **not_found 行を含む昇格済み `institutions.csv` で Section 1 がクラッシュする不具合。**
  `prepare_institutions_csv` は機関を照合できないと `openalex_institution_id` が空の行を
  書き出す。空の CSV セルは `<missing>` として読まれ、`"<missing>" ~= ""` が true になるため、
  これらの行が行フィルタを通過して ID 検証に到達し、include フィルタより前に
  「`<missing>` の string 要素」という分かりにくいエラーで停止していた。
  `load_institutions_list` は missing 値を正規化し、実際に使用する行（include=1）のみ
  ID を検証するようにして、未照合・除外行で実行を止めないようにした。

## 1.10.0 - 2026-07-21

### 追加
- `main_run_batch.m` に Section 0.6 を追加。レビュー済みの
  `data/list/institutions_candidate.csv` を `data/list/institutions.csv` へ
  昇格できるようにした。既存の本番リストは上書き前に
  `institutions.csv.bak.<timestamp>` としてバックアップされる。
- `promote_reviewed_institutions_csv.m` と、コピー元欠落・新規コピー・
  バックアップ（既存ファイルが空の場合を含む）・同一パス拒否を確認する
  offline smoke test を追加。

### 変更
- `prepare_institutions_csv` の完了メッセージで、候補レビュー後に
  Section 0.6 で昇格する導線を案内するようにした。
- ベンチマーク機関ワークフローに、候補レビュー→昇格→本実行の流れと、
  同名別機関の副次ヒットに対する注意を追記。

## 1.9.2 - 2026-07-21

### 修正
- **候補生成が `mergeWith` ファイルでハードエラーになる不具合。**
  `main_run_batch` は `data/list/institutions.csv` を「過去のレビュー結果をマージする
  入力」として `prepare_institutions_csv` に渡すが、新規セットアップではこのファイルが
  無い、または手書きリストにレビュー用の列が無いため、`MergeInputNotFound` /
  `MergeMissingColumn` で処理全体が止まっていた。マージを best-effort 化し、
  ファイルが無い／不正な場合はログ／警告を出して新規候補を生成して継続するよう修正。

## 1.9.1 - 2026-07-21

### 修正
- **example からコピーした `settings.json` で API キーが読めない不具合。**
  `jsondecode` は先頭が `_` の JSON キーを `x_`（例: `_comment` → `x_comment`）へ
  改名するが、config ローダは `_` 始まりしかスキップしていなかったため、
  `settings.example.json` 同梱のメタキーが config に混入し、環境変数オーバーライド
  処理で例外になっていた。結果、キーが入っていても「未設定」に見えていた。
  改名後のメタキーをスキップし、非構造体セクションを防御的に無視するよう修正。
  `config/settings.example.json` をコピーして `settings.json` を作った全ユーザーが対象。
- **「Run Section」で `main_run_batch` / `main_run_pipeline` が失敗する不具合。**
  セクション単独実行（Ctrl+Enter）や未保存バッファ実行では `mfilename('fullpath')`
  が temp フォルダを指し、`src/` や `config/settings.json` を見つけられなかった。
  Current Folder にフォールバックし、リポルートでない場合は明確なメッセージを出すよう修正。

## 1.9.0 - 2026-07-21

### 追加
- 公開面ゲートに、MATLAB 依存閉包と公開ドキュメントのリンク健全性
  （EN↔JP ヘッダ相互リンクを含む）の検査を追加。
- `data/sample/institutions_sample.csv` — Layer 1 バッチ入力のコピー用サンプル
  （架空プレースホルダ機関）。「CSV は非追跡」方針に対する**唯一の意図的な例外**
  （`.gitignore` と AGENTS.md を参照）。

### 変更
- 公開 docs の機関例を、実在大学名ではなく架空プレースホルダへ統一。
- フロントの既定ターゲットリストと smoke テストのフィクスチャを、実在機関・実 ID
  から架空プレースホルダへ置換。公開ソースに実ターゲットが現れないようにした。

## 1.8.0 - 2026-07-21

### 修正
- ドキュメントの相互リンク。公開している英語ページとその日本語ミラーの間に
  欠けていた EN↔JP ヘッダリンクを追加した（reference / examples / changelog /
  両ワークフロー / v0.1.0・v1.0.0 リリースノート）。従来は README と quickstart
  だけが相互リンクを持っていた。
- `README.md` / `docs/jp/README.md` / `docs/quickstart.md` の壊れた `LICENSE`
  リンクを修正した（リポジトリのルートより上を指していた）。

## 1.7.0 - 2026-07-20

### 修正
- OpenAlex の abstract 復元が、別論文の abstract を取り込むことがあった不具合を修正。
  生 abstract を切り出す正規表現が LaTeX（例: `\frac{1}{2}`）を含む abstract で
  途切れ、かつ結果を位置で対応付けていたため、1 件の失敗以降のすべてのレコードが
  1 つ前の論文の abstract にずれていた。切り出しを波括弧の深さで判定し、
  OpenAlex work id をキーに対応付けるよう変更したため、1 件の失敗が波及しなくなった。
  - **推奨対応:** 過去のクエリを再実行すること。本修正より前に生成した
    `search_results.jsonl` は abstract がずれている / アンダースコア化している
    可能性があるため、再生成を推奨する。

### 追加
- Phase Q topic-map pipeline 入口:
  - `examples/topic_map_pipeline.m`
- cluster summary / plot / UTF-8 CSV helper:
  - `examples/+topicmap/summarize_clusters.m`
  - `examples/+topicmap/plot_topic_map.m`
  - `examples/+topicmap/write_utf8_csv.m`
- `topic_map_run_meta.json`

### 変更
- chapter ベースの topic-map examples を、単一の Phase Q pipeline に置き換え
- `embed_documents.m` を `documentEmbedding` から `bert(Model="base")` ベースへ変更
- `reduce_layout.m` を 5 次元 / 2 次元の両方に使える形へ変更
- `docs/examples.md` / `docs/jp/examples.md` / `examples/README.md` を pipeline 構成へ更新
- topic-map smoke test を chapter 前提から pipeline 前提へ更新

### 削除
- `examples/topic_map_ch00.m` 〜 `examples/topic_map_ch05.m`
- `examples/+topicmap/project_map.m`
- `examples/+topicmap/require_chapter.m`
- `examples/+topicmap/run_hdbscan_cluster.m`
- `examples/+topicmap/select_methods.m`

## 1.6.0 - 2026-07-20

### 追加
- `search_results.jsonl` を入力に使う `examples/` topic-map sample surface
  - `examples/+topicmap/` helper 群
  - `examples/topic_map_ch00.m` から `examples/topic_map_ch05.m`
  - `examples/README.md`
- topic-map 向け smoke test
  - `test_topicmap_p0_smoke.m`
  - `test_topicmap_p2_smoke.m`
  - `test_topicmap_helpers_smoke.m`
  - `test_topicmap_p3_smoke.m`
- `docs/examples.md` / `docs/jp/examples.md`

### 変更
- public surface manifest に standalone topic-map example と smoke test を追加
- `THIRD_PARTY_NOTICES.md` に UMAP / HDBSCAN など example 依存の notice を追加
- README / quickstart から examples guide へのリンクを追加

### 修正
- 日本語 examples ページの公開リンク整合
- examples 公開面に対する sync dry-run 検証
