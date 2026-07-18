# 変更履歴

このファイルは、AnyResearch の主要な変更点を英語正本 `CHANGELOG.md` に対応させて日本語で補助説明するためのものです。  
実装メモや詳細な開発履歴は、非公開の開発リポジトリで管理しています。

## 未リリース

## 1.5.0 - 2026-07-18

### 追加
- run 横断の候補台帳: 複数 run にまたがって候補論文を蓄積・重複排除・状態管理する
  - `src/util/append_to_candidates.m` — run（または table）を台帳へ統合。
    `doi_normalized` で重複排除し、無ければ `openalex_id` を使う
  - `src/util/update_candidates_ledger.m` — 指定行の `status` / `note` を更新
  - `src/export/export_candidates_xlsx.m` — 台帳の閲覧用スプレッドシート出力
  - `src/export/export_candidates_md.m` — `status="reviewed"` 行の Markdown テーブル出力
  - `test/smoke/test_candidates_ledger_smoke.m`
- `main_run_pipeline.m` / `main_run_batch.m` の `appendToCandidates` オプション
- `main_run_batch.m` の `ledgerPath` オプション。既定の台帳ではなく
  専用ファイルへ蓄積できる
- DOI・OpenAlex ID の正規化。DOI URL / `doi:` 接頭辞 / 素の DOI、および
  OpenAlex ID の URL 形式・短縮形式が、すべて同一行として解決される

### 変更
- 台帳の追記エンジンをスキーマ非依存化。一致した行に既にある列は再追記でも保持され、
  incoming 側が非空値を持つ場合だけ更新される。
  **利用者が独自のレビュー列を台帳に足しても、後続 run で消えない**
- ドキュメント構成: **英語を正本**とし既定パスに配置
  （`README.md` / `docs/quickstart.md` / `docs/reference.md` / `docs/workflows/`）。
  日本語は `docs/jp/` に同じ木構造でミラーする。
  従来の `docs/en/` ディレクトリと `.ja.md` サフィックス方式を置き換える
- `docs/workflows/repro_discovery.md` を候補台帳ベースの手順に更新

### 削除
- 公開対象として意図していなかった旧パイプラインコード、ヘルパースクリプト、
  および開発用のアドホックファイル

### ドキュメント
- `CHANGELOG.md` を正本として新設
- 日本語補助ページ `docs/jp/CHANGELOG.md` を追加
- 関数・テスト説明をまとめた `docs/reference.md` / `docs/jp/reference.md` を追加
- README / quickstart / workflow 間の主要リンクを点検・修正

## 1.4.0 - 2026-07-17

### 追加
- OpenAlex への `citedByMin` / `citedByMax` サーバ側フィルタ
- Overview への `fwci` / `citation_percentile` 表示
- 再現性シグナル列:
  - `mentions_dataset`
  - `mentions_code`
  - `mentions_library`
  - `mentions_metrics`
  - `repro_signal_score`
- `config/repro_signals.example.json` による辞書差し替え
- seed 論文からの 1-hop 引用探索:
  - `fetch_citing_works.m`
  - `fetch_referenced_works.m`
  - `run_pipeline` の `seedId` / `snowballMode`
- OpenAlex 利用量確認ヘルパー:
  - `src/openalex/get_openalex_rate_limit_status.m`

### 変更
- `citation_velocity.m` が `counts_by_year` を優先して実測ベースで計算
- OpenAlex `429` / `503` 時の network smoke が `SKIP` / `WARN` に寄るよう整理
- EasyMolKit 向け候補探索手順を `fwci` / `repro_signal_score` ベースに更新

### 修正
- OpenAlex 429 時の待機戦略を改善
- pipeline 経由 OpenAlex 呼び出しで API key をより確実に伝播

## 1.3.0 - 2026-07-07

### 追加
- `run_pipeline(...).T`
- `search_results.mat`
- `load_run.m`
- `load_latest_run.m`
- `runDir/raw/` への生 OpenAlex JSON 保存

### 変更
- CSV リレー中心から、MATLAB table 中心の内部経路へ移行
- JSONL を機械処理用の正本に統一
- CSV / XLSX は派生ビュー化

## 1.2.1 - 2026-07-17

### 修正
- OR 検索意味論の修正
- 撤回論文の既定除外
- review 済み institution ID の batch 実行時再解決を防止
- Excel COM 書き込み経路の修正と回帰テスト追加

## 1.2.0 - 2026-06-21

### 追加
- EasyMolKit 連携ワークフロー
- quickstart / README へのケモインフォ探索例
- RP 候補探索導線

## 1.1.1 - 2026-04-03

### 修正
- `maxRowsForValidation` の既定値を無制限へ修正
- PDF 無効時の downstream step を正しく `skipped` に修正
- ゼロ件クエリを空成果物で正常終了
- OpenAlex OR クエリ処理を修正

## 1.1.0 - 2026-04

### 追加
- arXiv 補完取得
- DOI ベース重複排除
- `source_dataset` 列
- `test_arxiv_smoke.m`

## 1.0.0 - 2026-04

### 追加
- Analytics 層:
  - citation velocity
  - topic growth rate
  - institution dominance
- Summary / batch comparison 拡張
- 公開リポジトリ向け整備

## 0.1.0 - 2026-03

### 追加
- `main_run_pipeline.m` / `main_run_batch.m` の分離
- `src/pipeline/run_pipeline.m` への集約
- シート単位の Excel export モジュール化
- smoke test 一括運用
- logging helpers と統一 `run_meta.json`
