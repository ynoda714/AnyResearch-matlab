# Reference

&nbsp; [English](../reference.md)

このドキュメントは、現行ワークフローで参照される主要なユーザー向け関数、helper 関数、smoke test を要約したものです。

MATLAB ファイル内の docstring を置き換えるものではありません。  
目的は、最近のアーキテクチャ変更を markdown から追いやすくすることです。

## Core Entry Points

### `main_run_pipeline.m`
- 単一検索用の front end
- ユーザーが編集するパラメータのみを置く
- `run_pipeline(...)` を呼ぶ

### `main_run_batch.m`
- 複数機関バッチ実行用の front end
- reviewed institution CSV による実行を支える
- `prepareList=true` で候補 CSV の準備もできる

### `src/pipeline/run_pipeline.m`
- メインの pipeline orchestrator
- 主に次を扱う:
  - OpenAlex fetch
  - optional arXiv merge
  - optional PDF processing
  - 最終 table の統合
  - JSONL / CSV / XLSX / MAT 出力
  - optional candidate-ledger append/update
- 次のオプションを支える:
  - `citedByMin`, `citedByMax`
  - `seedId`, `snowballMode`
  - `useArxiv`
  - `saveRawResponses`
  - `appendToCandidates`

## Candidate Ledger Functions

### `src/util/append_to_candidates.m`
- 1 run 分の最終結果を `result/candidates/candidates.jsonl` に追記する
- DOI があれば `doi_normalized`、無ければ `openalex_id` で deduplicate する
- 人手管理の `status` と `note` を保持する
- 既存行を再観測したとき `last_seen_run_id` を更新する

### `src/util/update_candidates_ledger.m`
- 指定した ledger 行の `status` と `note` を更新する
- normalized DOI、DOI URL、`doi:...`、OpenAlex ID を selector として受ける
- 許可 status:
  - `new`
  - `reviewed`
  - `rejected`
  - `registered_RPxx`

### `src/util/normalize_candidate_doi.m`
- ledger 照合用に DOI 文字列を正規化する
- `https://doi.org/` や `doi:` を剥がし、lowercase 化する

## OpenAlex Functions

### `src/openalex/fetch_openalex_works.m`
- filter / sort / pagination / raw-response capture 付きで OpenAlex works を取得する
- typed MATLAB table と metadata を返す
- 429 / 503 retry を含む

### `src/openalex/get_openalex_rate_limit_status.m`
- OpenAlex `/rate-limit` を問い合わせる
- network smoke test と retry 判断で使う
- 続行に十分な残量があるかを返す

### `src/openalex/build_openalex_filter.m`
- OpenAlex の server-side filter 文字列を組み立てる
- 主に次を含む:
  - language
  - open access
  - abstract requirement
  - retraction exclusion
  - institution IDs
  - `cited_by_count` min/max

### `src/openalex/fetch_citing_works.m`
- seed DOI または OpenAlex Work ID を解決する
- seed work を引用する works を取得する

### `src/openalex/fetch_referenced_works.m`
- seed DOI または OpenAlex Work ID を解決する
- seed work の 1-hop referenced works を取得する

### `src/openalex/prepare_institutions_csv.m`
- reviewed-v2 institution candidate CSV を生成する
- `mergeWith` による merge-preserving refresh を支える

### `src/openalex/load_institutions_list.m`
- institution CSV 入力を検証し、機関ごとに group 化する
- CSV の各行ではなく、target account ごとに 1 行返す

## Adapter Functions

### `src/adapters/openalex_to_normalized_works.m`
- OpenAlex raw row を AnyResearch の normalized works table に変換する
- 主に次を追加する:
  - normalized DOI
  - dataset / library / code / metric signals
  - `repro_signal_score`

### `src/adapters/arxiv_to_normalized_works.m`
- arXiv row を OpenAlex と同じ normalized schema に変換する

### `src/adapters/detect_repro_signals.m`
- title + abstract に対して dictionary match を行う
- 主に次を生成する:
  - `mentions_dataset`
  - `mentions_code`
  - `mentions_library`
  - `mentions_metrics`
  - `repro_signal_score`
  - `matlab_mentioned`

## Analytics Functions

### `src/analytics/citation_velocity.m`
- 論文単位の citation velocity を計算する
- 可能なら `counts_by_year` の実測値を優先する
- 必要時だけ age-based approximation に fallback する

### `src/analytics/topic_growth_rate.m`
- 年ごとの論文数を集計する
- year-over-year growth を計算する

### `src/analytics/institution_dominance.m`
- 筆頭著者所属の share と citation share を集計する

### `src/analytics/compute_analytics.m`
- table / JSONL / CSV 入力を受ける analytics の統一入口

## Export Functions

### `src/export/excel_write_overview.m`
- Overview sheet を構築する
- `fwci`, `citation_percentile`, `repro_signal_score` を含む

### `src/export/excel_write_detail.m`
- Detail sheet を構築する
- repro-signal breakdown 列を含む

### `src/export/export_excel_workbook.m`
- Excel export の top-level entry point

### `src/export/export_candidates_xlsx.m`
- ledger を `candidates.xlsx` に出力する
- `status`, `note`, `repro_signal_score`, `fwci` などで実務向けに列順を調整する
- COM write と fallback mode を支える

### `src/export/export_candidates_md.m`
- `status="reviewed"` の行を EasyMolKit 向け Markdown に出力する
- DOI link と `repro_signal_score` ベースの初期 Tier を生成する

## Topicmap Example Functions

これらの関数は `examples/+topicmap/` 配下にあります。`src/` ではなく `examples/` に置かれているのは、プロダクト本体ではなく後段のサンプルだからです。

### `examples/+topicmap/setup.m`
- リポジトリルートと最新の `search_results.jsonl` を解決する
- `result/examples/topicmap/` 配下の出力先を構成する
- standalone pipeline の設定を集約する

### `examples/+topicmap/env_check.m`
- 必須 Toolbox と BERT / UMAP の前提条件を検出する
- pipeline readiness と警告を返す

### `examples/+topicmap/read_search_results.m`
- `search_results.jsonl` を読む
- topic-map pipeline 用 schema に正規化する
- abstract 欠損があっても title-only 行を使えるようにする

### `examples/+topicmap/extract_text.m`
- title / abstract から pipeline 入力 text を組み立てる
- OpenAlex `abstract_inverted_index` への旧依存を持たない

### `examples/+topicmap/clean_text.m`
- tokenization / vectorization 用の軽い text cleanup を行う

### `examples/+topicmap/build_term_matrix.m`
- cluster summary 用の bag-of-words 行列を作る
- `top_terms` 向けの stopword 除去と軽い複数形正規化を支える

### `examples/+topicmap/default_stopwords.m`
- cluster label 用の英語 + 汎用学術語 stopword リストを返す

### `examples/+topicmap/compute_tfidf.m`
- cluster label のスコアリング用 TF-IDF を計算する

### `examples/+topicmap/embed_documents.m`
- topic-map pipeline 用の BERT-Base embedding vector を作る
- support package / GPU availability を共有 config 経路で扱う

### `examples/+topicmap/reduce_layout.m`
- 5 次元 clustering 空間と 2 次元 plotting 空間の両方に次元削減を適用する

### `examples/+topicmap/make_run_dir.m`
- `result/examples/topicmap/` 配下に閉じた出力ディレクトリを作る

### `examples/+topicmap/summarize_clusters.m`
- cluster ごとの `top_terms` と `representative_titles` を作る
- stopword cleanup は label 生成に限定し、embedding には影響させない

### `examples/+topicmap/plot_topic_map.m`
- 次元削減済み座標と cluster ID から 2D topic map PNG を描く

### `examples/+topicmap/write_utf8_csv.m`
- Excel で安全に開ける UTF-8 BOM CSV を書く

## Topicmap Example Entry Point

### `examples/topic_map_pipeline.m`
- Phase Q の single pipeline を end-to-end で実行する
- 実行内容:
  - `search_results.jsonl` 読み込み
  - BERT-Base embedding
  - UMAP による 5 次元削減
  - 5 次元上での `kmeans` clustering
  - UMAP による 2 次元削減
  - CSV / PNG / run-meta 出力

## Runtime Artifact Model

現行アーキテクチャは内部的に table-first です。

1. API response は typed MATLAB table に正規化される
2. 最終の in-memory 結果は `run_pipeline(...).T` として返る
3. `search_results.jsonl` は機械処理用の正本 artifact である
4. `search_results.csv` と `search_results.xlsx` は派生ビューである
5. `search_results.mat` は MATLAB table をそのまま保持する

つまり、CSV は出力の一部ではあるものの、内部実装はもう CSV-first ではありません。

## Smoke Tests

### `test_phase6a_params_smoke.m`
- 検索パラメータ処理
- retry 実装
- OR search regression
- `citedByMin` / `citedByMax`

### `test_repro_signals_smoke.m`
- 既定 repro-signal dictionary
- custom JSON override
- adapter への伝播

### `test_analytics_smoke.m`
- `citation_velocity`
- `topic_growth_rate`
- `institution_dominance`
- `compute_analytics`

### `test_snowball_smoke.m`
- `fetch_citing_works`
- `fetch_referenced_works`
- `run_pipeline` の seed mode E2E

### `test_load_institutions_list_smoke.m`
- legacy / reviewed-v2 institution CSV の検証
- 不正 ID 検出
- duplicate 処理

### `test_run_batch_smoke.m`
- batch 入出力の検証
- multi-ID grouping
- joined-ID の伝播
- dry-run

### `test_candidates_ledger_smoke.m`
- candidate ledger の追加と dedup
- `status` / `note` 更新
- Markdown / XLSX 出力
- DOI / OpenAlex ID 正規化
- `update_candidates_ledger` の status 検証

### `test_topicmap_p0_smoke.m`
- `search_results.jsonl` 読み込みと legacy 依存除去の確認

### `test_topicmap_p2_smoke.m`
- standalone config / 環境検出 / 入力 path 解決の確認

### `test_topicmap_helpers_smoke.m`
- helper 単位の text extraction / cleanup / matrix build を確認する
- `top_terms` 向け stopword 除去と複数形正規化の回帰を含む

### `test_topicmap_p3_smoke.m`
- Phase Q pipeline surface の end-to-end smoke
