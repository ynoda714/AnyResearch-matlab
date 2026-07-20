# AnyResearch

[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=ynoda714/AnyResearch-matlab) &nbsp; [English](../../README.md)

`search_results.jsonl` を使う standalone な後段 example は [docs/examples.md](../examples.md) にまとめています。これらは任意利用であり、コア製品パイプラインには含まれません。

AnyResearch は、OpenAlex API を使って学術論文を収集し、MATLAB 上で構造化し、Excel に出力する検索パイプラインです。  
キーワード検索だけで、研究動向の把握、文献レビュー、機関比較、再現候補探索に使える素材を作ることを目的としています。

> 設計思想: AnyResearch は「分析そのもの」ではなく、「分析しやすい素材」を届ける。
> JSONL を正本とし、Excel は人間向けビューとして出力する。

## できること

| ユースケース | 使い方 |
|---|---|
| 通常の文献探索 | `query=` だけで単一検索 |
| レビュー収集 | `filterType="review"` |
| 新しい動向の確認 | `sortBy="publication_date:desc"` |
| 影響力の高い論文探索 | `sortBy="cited_by_count:desc"` |
| 機関比較 | `main_run_batch.m` + `institutions.csv` |
| EasyMolKit 向け候補探索 | `fwci` / `repro_signal_score` / `seedId` を活用 |

## 4 層構成

| Layer | 内容 | 必須性 |
|---|---|---|
| Layer 0 | OpenAlex 取得、正規化、Excel/JSONL/CSV 出力 | 必須 |
| Layer 1 | 複数機関バッチ | 任意 |
| Layer 2 | citation velocity / topic growth / institution dominance | 任意 |
| Layer 3 | OA PDF 取得、本文抽出、キーワード証拠 | 任意 |

Layer 0 だけで主目的は達成できます。

## クイックスタート

### 1. OpenAlex API Key を設定する

```json
{
  "openalex": {
    "api_key": "YOUR_OPENALEX_API_KEY"
  }
}
```

または:

```powershell
ANYRESEARCH_OPENALEX_API_KEY=YOUR_KEY
```

### 2. 単一検索を実行する

`main_run_pipeline.m` の Section 0 を編集し、Section 1 を実行します。

```matlab
query             = "renewable energy forecasting";
fromDate          = "2023-01-01";
toDate            = "2025-12-31";
sortBy            = "cited_by_count:desc";
filterType        = "";
requireOpenAccess = true;
filterCountryCode = "";
enablePdfDownload = false;
useArxiv          = false;
```

生成物:

```text
result/runs/<YYYYMMDD_HHMMSS>/
  search_results.xlsx
  search_results.jsonl
  search_results.csv
  run_meta.json
```

詳しい手順は [docs/quickstart.md](quickstart.md) を参照。

## Excel 出力

| シート | 内容 |
|---|---|
| Overview | 全件を俯瞰する一覧 |
| Detail | 著者、所属、PDF 状態、拡張列を含む詳細 |
| Summary | 年別件数、被引用、citation velocity、growth rate |
| Config | 実行条件と run metadata |

## EasyMolKit 連携

AnyResearch は、EasyMolKit の再現候補探索に使えます。

推奨設定:

```matlab
query             = "Morgan fingerprint ECFP cheminformatics QSAR";
fromDate          = "2018-01-01";
toDate            = "2025-12-31";
sortBy            = "cited_by_count:desc";
filterType        = "article";
requireOpenAccess = true;
citedByMin        = 20;
```

Phase K 以降の候補探索では、次の列を使って候補を絞ります。

- `fwci`
- `citation_percentile`
- `repro_signal_score`
- `mentions_dataset`
- `mentions_code`
- `mentions_library`
- `mentions_metrics`

推奨の並べ替え順:

1. `repro_signal_score` 降順
2. `fwci` 降順
3. `cited_by_count` 降順
4. `publication_year` 降順

2026年7月17日に `Morgan fingerprint ECFP cheminformatics QSAR` で実行確認し、`repro_signal_score` と `fwci` により再現候補の優先度付けが実データ上で機能することを確認済みです。

### 既知論文 1 本から周辺探索する

```matlab
query        = "";
seedId       = "10.1021/ci034243x";
snowballMode = "citing";   % or "referenced"
sortBy       = "cited_by_count:desc";
citedByMin   = 5;
```

これにより、1-hop の引用探索でも通常検索と同じ `search_results.*` 成果物を生成できます。

詳細は [docs/workflows/repro_discovery.md](workflows/repro_discovery.md) を参照。

Phase L 以降は、`appendToCandidates=true` を有効にすると候補論文を `result/candidates/candidates.jsonl` に run 横断で蓄積できます。
`candidates.xlsx` で目視確認し、`update_candidates_ledger(...)` で `reviewed` を付けると、`repro_candidates.md` に EasyMolKit 転記用の行が出力されます。

## 機関バッチ

複数機関を比較する場合は `main_run_batch.m` を使います。  
`institutions.csv` は旧2列形式と reviewed v2 形式の両方に対応します。

詳しい運用は [docs/workflows/benchmark_institutions.md](workflows/benchmark_institutions.md) を参照。

## テスト

```matlab
addpath("test");
run_smoke_tests
run_smoke_tests("network")
run_smoke_tests("python")
run_smoke_tests("all")
```

K フェーズ関連の主要テスト:

- `test_phase6a_params_smoke()`
- `test_repro_signals_smoke()`
- `test_analytics_smoke()`
- `test_snowball_smoke()`

## 関連ドキュメント

| ファイル | 内容 |
|---|---|
| [docs/quickstart.md](quickstart.md) | 実行手順と FAQ |
| [docs/workflows/repro_discovery.md](workflows/repro_discovery.md) | EasyMolKit 向け候補探索 |
| [docs/workflows/benchmark_institutions.md](workflows/benchmark_institutions.md) | 機関リスト運用 |
| [CHANGELOG.md](../../CHANGELOG.md) | 主要変更履歴（英語正本） |
| [docs/jp/CHANGELOG.md](CHANGELOG.md) | 変更履歴の日本語補助 |
| [docs/reference.md](../reference.md) | 関数・smoke test リファレンス |
| [docs/jp/reference.md](reference.md) | 関数・smoke test リファレンス（日本語補助） |

詳細な開発規約とフェーズ計画は、非公開の開発リポジトリで管理しています。

## ライセンス

MIT License. 詳細は [LICENSE](LICENSE) を参照。
