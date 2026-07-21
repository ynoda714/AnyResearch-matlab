# 変更履歴

&nbsp; [English](../../CHANGELOG.md)

このファイルは [CHANGELOG.md](../../CHANGELOG.md) の日本語ミラーです。
詳細な実装履歴や開発メモは private な dev リポジトリ側で管理します。

## Unreleased

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
