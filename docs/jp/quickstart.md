# クイックスタート — AnyResearch

&nbsp; [English](../quickstart.md)

`search_results.jsonl` を使う standalone example については [Examples](examples.md) を参照してください。これらはコア製品パイプラインのサポート対象外です。

> 最終更新: 2026-09-29

---

## 1. 前提

Layer 0 だけで主目的は達成できる。Layer 1 以降は必要なときだけ有効化する。

| 項目 | Layer | 必須/任意 | 備考 |
|---|---|---|---|
| MATLAB R2026b 以降 | 0 | 必須 | コアパイプラインと `AnyResearchApp.mlapp` の実行に必要 |
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

## 4. 任意: GUI（`AnyResearchApp.mlapp`）

`AnyResearchApp.mlapp` は、`.m` ファイルを編集せずに使いたい方のための代替入口です。`main_run_pipeline.m` と `main_run_batch.m` も、これまでどおり利用できます。

GUI を使うには、[前提](#1-前提)にあるとおり MATLAB R2026b 以降が必要です。

### 4.1 起動

リポジトリ直下の `AnyResearchApp.mlapp` をダブルクリックするか、MATLAB で次を実行します。

```matlab
open("AnyResearchApp.mlapp")
```

### 4.2 タブ

| タブ | 目的 |
|---|---|
| **Search** | 日付、並び順、フィルタを指定して Layer 0 のキーワード検索を実行する。 |
| **Batch** | Layer 1 の4段階（機関候補の生成、レビュー、レビュー済みリストへの昇格、バッチ実行）を進める。 |
| **Analytics & PDF** | Layer 2 の citation velocity、topic growth rate、institution dominance は検索・バッチ結果に自動で含まれる。Layer 3 の PDF ダウンロード、本文抽出、キーワード証拠を設定する。 |
| **Settings** | OpenAlex API Key を入力し、`config/settings.json` に保存する。 |

Search タブは `main_run_pipeline.m` と同じ `result/runs/<timestamp>/` に、Batch タブは `main_run_batch.m` と同じ `result/batch/<timestamp>/` に出力します。出力内容は上記「基本実行」と下記「機関バッチ実行」の出力先を参照してください。

### 4.3 API Key の取り扱い

Settings タブの入力欄は標準のテキスト入力欄のため、入力中の API Key が画面にそのまま表示される。画面共有、録画、スクリーンショットにはキーが映らないようにする。
保存後は入力欄が空になる。キーは `config/settings.json` に平文で保存され、このファイルは Git の追跡対象外である。コミットしない。
アプリ上でキーを表示したくない場合は、代わりに `ANYRESEARCH_OPENALEX_API_KEY` を設定する。環境変数は `config/settings.json` より優先される。

---

## 5. 機関バッチ実行

`main_run_batch.m` を使う。入力 CSV は旧2列形式と reviewed v2 の両方を受け付ける。

### 5.1 旧2列形式

```csv
Account,openalex_institution_id
Example Research University,I1234567890
Example Medical University,I100000001
Example Medical University,I100000002
```

### 5.2 reviewed v2 形式

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

### 5.3 実行

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

## 6. arXiv 統合

OpenAlex に未収載のプレプリントも見たい場合:

```matlab
useArxiv = true;
```

補足:

- DOI 一致時は OpenAlex 側を優先して重複除去する
- arXiv 行は `source_dataset="arxiv"` で識別できる
- `filterType="article"` のときは arXiv の preprint は除外される

---

## 7. EasyMolKit 向け候補探索

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

### 7.1 既知論文 1 本から周辺探索する

```matlab
query        = "";
seedId       = "10.1021/ci034243x";
snowballMode = "citing";   % or "referenced"
sortBy       = "cited_by_count:desc";
citedByMin   = 5;
```

`seedId` を使うと、キーワード検索の代わりに 1-hop の引用探索で同じ成果物一式を生成する。

詳しい手順は [docs/workflows/repro_discovery.md](workflows/repro_discovery.md) を参照。

### 7.2 候補台帳を使う

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

## 8. テスト

```matlab
addpath("test");
run_smoke_tests
run_smoke_tests("network")
run_smoke_tests("python")
run_smoke_tests("all")
```

関連テスト:

- `test_repro_signals_smoke()` — repro signal 辞書 / custom JSON override
- `test_analytics_smoke()` — `citation_velocity` の `counts_by_year` 優先計算
- `test_snowball_smoke()` — `seedId` / `snowballMode`

---

## 9. FAQ

**Q. OpenAI API Key は必要ですか？**  
A. 不要。AnyResearch は OpenAI を使わない。

**Q. OpenAlex API Key なしで動きますか？**  
A. 2026年以降は必要。

**Q. PDF 処理が不要です。**  
A. `enablePdfDownload=false` のままでよい。

**Q. 検索結果が Max records を超えたらどうなりますか？**
A. Run Search は最初にヒット件数を確認する。Max records（既定 1,000 件）を超える場合は、「先頭 N 件」「その回だけ全件」「キャンセル」を選べる。全件を選んでも欄の値は変わらない。OpenAlex の索引は継続的に更新されるため、保存行数が最初の件数と少し異なる場合がある。

**Q. GUI で出力フォルダを開くには？**
A. Search または Batch が正常に完了した後、ウィンドウ下部の **Open output folder** を選ぶ。

**Q. Batch タブで長い機関候補リストをレビューするには？**
A. Step 2 では、今回の検索で返らず現在の機関リストから引き継がれた行が灰色で表示される。**Include all** は OpenAlex institution ID のある全行を含め、**Include none** は全行を外す。その後レビューを保存する。

**Q. 結果が 0 件です。**  
A. `query` の綴り、期間、`requireOpenAccess`、`requireAbstract`、`filterCountryCode` を順に確認する。

---

## 10. 関連ドキュメント

| ファイル | 内容 |
|---|---|
| [docs/workflows/repro_discovery.md](workflows/repro_discovery.md) | EasyMolKit 候補探索 |
| [docs/workflows/benchmark_institutions.md](workflows/benchmark_institutions.md) | 機関バッチ運用 |
| [CHANGELOG.md](../../CHANGELOG.md) | 主要変更履歴（英語正本） |
| [docs/jp/CHANGELOG.md](CHANGELOG.md) | 変更履歴の日本語補助 |
| [docs/reference.md](../reference.md) | 関数・smoke test リファレンス |
| [docs/jp/reference.md](reference.md) | 関数・smoke test リファレンス（日本語補助） |
