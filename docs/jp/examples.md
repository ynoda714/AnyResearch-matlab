# Examples

`examples/` は、AnyResearch の通常実行後に `search_results.jsonl` を使って追加分析を行う standalone サンプル群です。

これは Layer 0 の本体機能ではなく、`main_run_pipeline.m` / `main_run_batch.m` / `src/` にも参加しません。
現在の主サンプルは Phase Q の topic-map pipeline です。

## 利用境界

- `examples/` は本体パイプラインの一部ではない
- 正式な主成果物は `result/runs/<timestamp>/` 配下の標準 artifact 群のまま
- `examples/` は追加 Toolbox / support package を要求することがある
- 大量件数での topic mapping は example 側の裁量であり、本体機能化を意味しない

## 入力 artifact

topic-map pipeline は次を読むだけです。

```text
result/runs/<YYYYMMDD_HHMMSS>/search_results.jsonl
```

`raw/openalex_page_*.json` は使いません。
明示パスを渡さない場合、`topicmap.setup()` が最新の `search_results.jsonl` を自動解決します。

## 現在の pipeline

```text
search_results.jsonl
  -> title + abstract の整形
  -> BERT-Base 768 次元埋め込み
  -> UMAP 5 次元
  -> 5 次元上で k-means
  -> UMAP 2 次元
  -> topic_map.png + topic_map_clusters.csv
```

入口スクリプト:

```text
examples/topic_map_pipeline.m
```

スクリプト冒頭に主要パラメータを集約しています。

- `K`
- `nDim5`
- `batchSize`
- `maxChars`
- `seed`

## 必要条件

- Statistics and Machine Learning Toolbox
- Text Analytics Toolbox
- Deep Learning Toolbox
- Text Analytics Toolbox Model for BERT-Base Network support package
- MATLAB R2026a 以降の組み込み `umap()`

BERT-Base support package が未導入のときは、`topicmap.embed_documents()` が明示エラーで止まります。
Add-On Explorer で `Text Analytics Toolbox Model for BERT-Base Network` を検索して導入してください。

## サンプル JSONL の作り方

1. `main_run_pipeline.m` を開く
2. Section 0 に小さめの query を設定する
3. Section 0 と Section 1 を実行する
4. run folder に `search_results.jsonl` があることを確認する
5. `examples/topic_map_pipeline.m` を実行する

## 出力

出力先:

```text
result/examples/topicmap/<runId>/
```

主な出力:

- `topic_map.png`
- `topic_map_points.csv`
- `topic_map_clusters.csv`
- `topic_map_run_meta.json`

`topic_map_clusters.csv` には次の列が入ります。

- `cluster`
- `n_docs`
- `top_terms`
- `representative_titles`

`top_terms` には、英語の機能語と汎用的な学術語を含む組み込み stopword リストと、軽い複数形正規化を適用します。小規模またはノイズの多いコーパスでも、ラベルの読みやすさを優先します。

`topic_map_points.csv` には、クラスタリングに使った 5 次元座標（`umap5_1`..`umap5_5`）と、描画用の 2 次元座標（`umap_x`, `umap_y`）の両方が入ります。

`topic_map_clusters.csv` には次の列が入ります。
- `cluster`
- `n_docs`
- `top_terms`
- `representative_titles`
- `silhouette_5d`
- `silhouette_2d`
- `lexical_coherence`
- `top_terms_overlap`
- `dominant_type`
- `type_purity`
- `duplicate_title_rate`

`top_terms` には、英語の機能語と汎用的な学術語を含む組み込み stopword リストと、軽い複数形正規化を適用します。小規模またはノイズの多いコーパスでも、ラベルの読みやすさを優先します。
クラスタは研究分野だけでなく、文書種別や投稿慣習を反映することがあります。
`silhouette_5d` はクラスタリングを行った 5 次元 UMAP 空間での主指標です。
`silhouette_2d` は散布図の読みやすさを見る補助指標であり、クラスタ品質そのものではありません。
シルエット値は絶対評価ではなく、同一埋め込み条件の中での相対比較に使います。

## Helper Functions

### `examples/+topicmap/setup.m`
- standalone 設定を作る
- 最新 `search_results.jsonl` を解決する

### `examples/+topicmap/env_check.m`
- Phase Q pipeline の前提条件を検出する
- `pipelineReady` と不足要件を返す

### `examples/+topicmap/read_search_results.m`
- `search_results.jsonl` を読み込む
- example 用の安定 schema に正規化する

### `examples/+topicmap/extract_text.m`
- `title` / `abstract` から BERT 入力 text を組み立てる
- 文字数上限を適用できる

### `examples/+topicmap/embed_documents.m`
- BERT-Base による 768 次元埋め込みを作る

### `examples/+topicmap/reduce_layout.m`
- `umap`, `pca`, `tsne` による次元削減を行う
- 5 次元と 2 次元の両方に使う

### `examples/+topicmap/summarize_clusters.m`
- `top_terms` と `representative_titles` を持つ cluster summary を作る

### `examples/+topicmap/plot_topic_map.m`
- 2 次元 topic map を描いて PNG に保存する

### `examples/+topicmap/write_utf8_csv.m`
- Excel で開きやすい UTF-8 BOM 付き CSV を書く

## Smoke Tests

- `test_topicmap_p0_smoke.m`
- `test_topicmap_p2_smoke.m`
- `test_topicmap_helpers_smoke.m`
- `test_topicmap_p3_smoke.m`

```matlab
addpath("test");
run_smoke_tests("offline");
```
