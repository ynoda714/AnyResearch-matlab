# リファレンス

このドキュメントは、現在の workflow から参照される主要な関数・補助関数・smoke test の役割を markdown 上で横断的に把握するためのものです。

MATLAB ファイル内の docstring を置き換えるものではなく、最近の構成変更をドキュメント側から追いやすくすることが目的です。

## フロント入口

### `main_run_pipeline.m`
- 単一検索用フロント
- ユーザー編集対象のパラメータのみを置く
- 実処理は `run_pipeline(...)`

### `main_run_batch.m`
- 複数機関バッチ用フロント
- review 済み institution CSV を使って実行する
- `prepareList=true` で候補 CSV 作成も可能

### `src/pipeline/run_pipeline.m`
- パイプライン全体のオーケストレーション本体
- 担当:
  - OpenAlex 取得
  - 任意の arXiv マージ
  - 任意の PDF 処理
  - 最終 table 統合
  - JSONL / CSV / XLSX / MAT 出力
  - 任意の候補台帳追記
- 主なオプション:
  - `citedByMin`, `citedByMax`
  - `seedId`, `snowballMode`
  - `useArxiv`
  - `saveRawResponses`
  - `appendToCandidates`

## 候補台帳関数

### `src/util/append_to_candidates.m`
- 1 run 分の最終結果を `result/candidates/candidates.jsonl` に追記
- `doi_normalized`、欠損時は `openalex_id` で重複排除
- 人手管理列 `status` / `note` は保持
- 再観測時は `last_seen_run_id` を更新

### `src/util/update_candidates_ledger.m`
- 候補台帳の `status` / `note` を更新
- DOI 本体、DOI URL、`doi:` 形式、OpenAlex ID を selector に使える
- `status` は `new` / `reviewed` / `rejected` / `registered_RPxx` のみ許可

### `src/util/normalize_candidate_doi.m`
- 候補台帳照合用に DOI 文字列を正規化
- `https://doi.org/` や `doi:` を剥がし、lowercase の DOI 本体に揃える

## OpenAlex 関連関数

### `src/openalex/fetch_openalex_works.m`
- OpenAlex works を filter / sort / pagination 付きで取得
- typed MATLAB table と metadata を返す
- 429 / 503 retry を含む

### `src/openalex/get_openalex_rate_limit_status.m`
- OpenAlex `/rate-limit` を参照
- network smoke の事前判定や retry 判断に使う

### `src/openalex/build_openalex_filter.m`
- OpenAlex 向け filter 文字列を構築
- 以下を含む:
  - language
  - open access
  - abstract requirement
  - retraction exclusion
  - institution IDs
  - `cited_by_count` min/max

### `src/openalex/fetch_citing_works.m`
- seed DOI または OpenAlex Work ID を解決
- その論文を引用している works を取得

### `src/openalex/fetch_referenced_works.m`
- seed DOI または OpenAlex Work ID を解決
- その論文が参照している 1-hop works を取得

### `src/openalex/prepare_institutions_csv.m`
- reviewed-v2 institution candidate CSV を生成
- `mergeWith` による既存レビュー保持更新に対応

### `src/openalex/load_institutions_list.m`
- institution CSV を検証し、ターゲット単位に集約
- CSV の 1 行ではなく、`account` 単位で 1 行を返す

## Adapter 関数

### `src/adapters/openalex_to_normalized_works.m`
- OpenAlex の raw row を AnyResearch 正規化 table に変換
- 以下を追加:
  - DOI 正規化
  - repro signal 列
  - `repro_signal_score`

### `src/adapters/arxiv_to_normalized_works.m`
- arXiv row を OpenAlex と同じ正規化スキーマに変換

### `src/adapters/detect_repro_signals.m`
- title + abstract を辞書マッチ
- 出力列:
  - `mentions_dataset`
  - `mentions_code`
  - `mentions_library`
  - `mentions_metrics`
  - `repro_signal_score`
  - `matlab_mentioned`

## Analytics 関数

### `src/analytics/citation_velocity.m`
- 論文単位 citation velocity を計算
- `counts_by_year` があれば実測値を優先
- なければ論文年齢ベース近似へフォールバック

### `src/analytics/topic_growth_rate.m`
- 年別論文数を集計
- 年次成長率を算出

### `src/analytics/institution_dominance.m`
- 筆頭著者所属の論文シェア / 被引用シェアを集計

### `src/analytics/compute_analytics.m`
- table / JSONL / CSV 入力をまとめて処理する analytics 入口

## Export 関数

### `src/export/excel_write_overview.m`
- Overview シート生成
- `fwci`, `citation_percentile`, `repro_signal_score` を含む

### `src/export/excel_write_detail.m`
- Detail シート生成
- repro signal 内訳列を含む

### `src/export/export_excel_workbook.m`
- Excel 出力全体のエントリポイント

### `src/export/export_candidates_xlsx.m`
- 候補台帳を `candidates.xlsx` に出力
- `status`, `note`, `repro_signal_score`, `fwci` などで見やすい列順に並べる
- COM 書き込みとフォールバックに対応

### `src/export/export_candidates_md.m`
- `status="reviewed"` の行だけを EasyMolKit 向け Markdown に出力
- DOI リンク生成と `repro_signal_score` ベースの初期 Tier 付与を行う

## 実行時アーティファクトの考え方

現在の内部構造は table-first です。

1. API レスポンスを typed MATLAB table に正規化する
2. 最終 in-memory 結果を `run_pipeline(...).T` として返す
3. `search_results.jsonl` が機械処理用の正本
4. `search_results.csv` と `search_results.xlsx` は派生ビュー
5. `search_results.mat` は MATLAB table をそのまま保持する

つまり、内部実装はもう CSV-first ではありません。  
CSV は互換性と閲覧性のために出力している派生物です。

## Smoke Test

### `test_phase6a_params_smoke.m`
- 検索パラメータ
- retry 実装確認
- OR 検索回帰
- `citedByMin` / `citedByMax`

### `test_repro_signals_smoke.m`
- 既定辞書
- custom JSON override
- adapter 伝播

### `test_analytics_smoke.m`
- `citation_velocity`
- `topic_growth_rate`
- `institution_dominance`
- `compute_analytics`

### `test_snowball_smoke.m`
- `fetch_citing_works`
- `fetch_referenced_works`
- `run_pipeline` seed mode E2E

### `test_load_institutions_list_smoke.m`
- 旧2列 / reviewed-v2 institution CSV
- 不正 ID 検出
- duplicate 処理

### `test_run_batch_smoke.m`
- batch 入力読込
- multi-ID grouping
- joined-ID 伝播
- dry-run

### `test_candidates_ledger_smoke.m`
- 候補台帳の追記と重複排除
- `status` / `note` 保持
- Markdown / XLSX 出力
- DOI / OpenAlex ID 正規化
- `update_candidates_ledger` の status 検証

## 関連ドキュメント

- [クイックスタート](quickstart.md)
- [機関ベンチマーク workflow](workflows/benchmark_institutions.md)
- [再現候補探索 workflow](workflows/repro_discovery.md)
- [変更履歴](../../CHANGELOG.md)
