# クイックスタート — AnyResearch

&nbsp; [English](../quickstart.md)

`search_results.jsonl` を使う standalone example については [Examples](examples.md) を参照してください。これらはコア製品パイプラインのサポート対象外です。

> 最終更新: 2026-07-17

---

## 1. 前提

Layer 0 だけで主目的は達成できる。Layer 1 以降は必要なときだけ有効化する。

| 項目 | Layer | 必須/任意 | 備考 |
|---|---|---|---|
| MATLAB R2025b 以降 | 0 | 必須 | |
| OpenAlex API Key | 0 | 必須 | [openalex.org/settings/api](https://openalex.org/settings/api) で無料取得 |
| `institutions.csv` | 1 | 任意 | 機関バッチ実行時のみ |
| Text Analytics Toolbox | 3 | 任意 | PDF本文抽出 |
| Python 3.11 + `venv/` | 3 | 任意 | PDFフォールバックのみ |

---

## 2. セットアップ

### 2.1 API Key を設定する

`config/settings.example.json` を `config/settings.json` にコピーし、`openalex.api_key` を設定する。

```json
{
  "openalex": {
    "api_key": "YOUR_OPENALEX_API_KEY"
  }
}
```

または環境変数でもよい。

```powershell
ANYRESEARCH_OPENALEX_API_KEY=YOUR_KEY
```

### 2.2 PDF処理を使う場合のみ Python を入れる

```powershell
python -m venv venv
venv\Scripts\activate
pip install -r src/python/requirements.txt
```

---

## 3. 基本実行: 単一キーワード検索

`main_run_pipeline.m` の Section 0 を編集し、Section 1 を実行する。

```matlab
query             = "renewable energy forecasting";
fromDate          = "2023-01-01";
toDate            = "2025-12-31";
sortBy            = "cited_by_count:desc";
filterType        = "";
language          = "en";
requireOpenAccess = true;
requireAbstract   = true;
filterCountryCode = "";
enablePdfDownload = false;
useArxiv          = false;
```

検索構文:

- AND: スペース区切り
- OR: `|`
- フレーズ: 引用符

例:

```matlab
query = "solar|wind energy";
query = '"deep learning"';
```

`sortBy` の主な候補:

- `"cited_by_count:desc"`
- `"publication_date:desc"`
- `"relevance_score"`

`filterType` の主な候補:

- `""`
- `"article"`
- `"review"`
- `"article,review"`

撤回論文は既定で除外される。

出力先:

```text
result/runs/<YYYYMMDD_HHMMSS>/
  search_results.xlsx
  search_results.jsonl
  search_results.csv
  run_meta.json
```

---

## 4. 機関バッチ実行

`main_run_batch.m` を使う。入力 CSV は旧2列形式と reviewed v2 の両方を受け付ける。

### 4.1 旧2列形式

```csv
Account,openalex_institution_id
Example Research University,I1234567890
Example Medical University,I100000001
Example Medical University,I100000002
```

### 4.2 reviewed v2 形式

```csv
account,openalex_institution_id,display_name,include,role,note
Example Medical University,I100000001,Example Medical University,1,main,
Example Medical University,I100000002,Example Medical University Hospital,1,hospital,
Example Medical University,I9999999999,Old Candidate,0,other,excluded after review
```

ルール:

- 同じ `account` の複数行は 1 ターゲットとして扱う
- `include=1` の行だけ実行される
- `include=0` の行は監査用に残してよい
- 複数 ID は `I1|I2|...` として記録される

### 4.3 実行

```matlab
query           = "renewable energy forecasting";
fromDate        = "2023-01-01";
toDate          = "2025-12-31";
institutionsCsv = "data/list/institutions.csv";
```

出力先:

```text
result/batch/<YYYYMMDD_HHMMSS>/
  runs/<institution>/search_results.xlsx
  batch_summary.csv
  batch_search_results.xlsx
  batch_comparison.xlsx
```

---

## 5. arXiv 統合

OpenAlex に未収載のプレプリントも見たい場合:

```matlab
useArxiv = true;
```

補足:

- DOI 一致時は OpenAlex 側を優先して重複除去する
- arXiv 行は `source_dataset="arxiv"` で識別できる
- `filterType="article"` のときは arXiv の preprint は除外される

---

## 6. EasyMolKit 向け候補探索（Phase K）

再現候補探索では、`cited_by_count` だけでなく `fwci` と `repro_signal_score` を使う。

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

見る列:

- `fwci`: 分野・年齢補正後の相対的な強さ
- `citation_percentile`: 同分野・同年代での相対順位
- `repro_signal_score`: データセット / コード / ライブラリ / 評価指標の言及数
- `mentions_dataset`, `mentions_code`, `mentions_library`, `mentions_metrics`: スコアの根拠

推奨の並べ替え順:

1. `repro_signal_score` 降順
2. `fwci` 降順
3. `cited_by_count` 降順
4. `publication_year` 降順

2026-07-17 に `Morgan fingerprint ECFP cheminformatics QSAR` で実行確認し、`repro_signal_score` と `fwci` の併用で候補上位化が機能することを確認済み。

### 6.1 既知論文 1 本から周辺探索する

```matlab
query        = "";
seedId       = "10.1021/ci034243x";
snowballMode = "citing";   % or "referenced"
sortBy       = "cited_by_count:desc";
citedByMin   = 5;
```

`seedId` を使うと、キーワード検索の代わりに 1-hop の引用探索で同じ成果物一式を生成する。

詳しい手順は [docs/workflows/repro_discovery.md](workflows/repro_discovery.md) を参照。

### 6.2 候補台帳を使う（Phase L）

候補を run 横断で蓄積したい場合:

```matlab
appendToCandidates = true;
```

これにより以下が更新される:

```text
result/candidates/candidates.jsonl
result/candidates/candidates.xlsx
result/candidates/repro_candidates.md
```

`reviewed` 化をコードで行う場合:

```matlab
update_candidates_ledger( ...
    ledgerPath="result/candidates/candidates.jsonl", ...
    doiNormalized="10.1000/example", ...
    status="reviewed", ...
    note="Tier A candidate");
```

## 7. テスト

```matlab
addpath("test");
run_smoke_tests
run_smoke_tests("network")
run_smoke_tests("python")
run_smoke_tests("all")
```

K フェーズ関連:

- `test_phase6a_params_smoke()` — `citedByMin` / `citedByMax` / retry / OR 検索
- `test_repro_signals_smoke()` — repro signal 辞書 / custom JSON override
- `test_analytics_smoke()` — `citation_velocity` の `counts_by_year` 優先計算
- `test_snowball_smoke()` — `seedId` / `snowballMode`

---

## 8. FAQ

**Q. OpenAI API Key は必要ですか？**  
A. 不要。AnyResearch は OpenAI を使わない。

**Q. OpenAlex API Key なしで動きますか？**  
A. 2026年以降は必要。

**Q. PDF 処理が不要です。**  
A. `enablePdfDownload=false` のままでよい。

**Q. 結果が 0 件です。**  
A. `query` の綴り、期間、`requireOpenAccess`、`requireAbstract`、`filterCountryCode` を順に確認する。

---

## 9. 関連ドキュメント

| ファイル | 内容 |
|---|---|
| [docs/workflows/repro_discovery.md](workflows/repro_discovery.md) | EasyMolKit 候補探索 |
| [docs/workflows/benchmark_institutions.md](workflows/benchmark_institutions.md) | 機関バッチ運用 |
| [CHANGELOG.md](../../CHANGELOG.md) | 主要変更履歴（英語正本） |
| [docs/jp/CHANGELOG.md](CHANGELOG.md) | 変更履歴の日本語補助 |
| [docs/reference.md](../reference.md) | 関数・smoke test リファレンス |
| [docs/jp/reference.md](reference.md) | 関数・smoke test リファレンス（日本語補助） |

詳細な開発規約とフェーズ計画は、非公開の開発リポジトリで管理しています。
