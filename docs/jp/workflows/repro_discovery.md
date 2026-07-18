# ワークフロー: EasyMolKit 向け再現候補論文探索

> AnyResearch の Layer 0 検索を使って、EasyMolKit の RP 候補を効率よく絞り込む手順。
> 目的は「候補探索の高速化」であり、分野クラスタリングやネットワーク可視化は行わない。

---

## 0. 前提

- OpenAlex API Key が設定済みであること
- `main_run_pipeline.m` を使って単一検索を実行すること
- EasyMolKit 側で確認したいテーマが、キーワードで表現できること

推奨の基本設定:

```matlab
query             = "Morgan fingerprint ECFP cheminformatics QSAR";
fromDate          = "2018-01-01";
toDate            = "2025-12-31";
sortBy            = "cited_by_count:desc";
filterType        = "article";
requireOpenAccess = true;
filterCountryCode = "";
enablePdfDownload = false;
useArxiv          = false;
```

候補を絞る追加設定:

```matlab
citedByMin = 20;     % ノイズ削減
citedByMax = 0;      % 必要なら古典の上限をかける
```

---

## 1. キーワード検索で候補母集団を作る

まず通常の `query=` 検索で母集団を作る。

代表的なクエリ例:

| テーマ | 例 |
|---|---|
| ESOL | `"ESOL aqueous solubility prediction"` |
| BBBP | `"BBBP blood brain barrier permeability"` |
| 指紋ベース QSAR | `"Morgan fingerprint ECFP cheminformatics QSAR"` |
| GNN | `"graph neural network molecular property prediction"` |
| 分子言語モデル | `"SMILES transformer cheminformatics"` |
| 解釈性 | `"SHAP feature importance molecular descriptor"` |

出力先:

```text
result/runs/<YYYYMMDD_HHMMSS>/
  search_results.xlsx
  search_results.jsonl
  search_results.csv
  run_meta.json
```

---

## 1.5. 良い論文 1 本からスノーボール探索する

候補が 1 本見つかったら、その周辺論文を `seedId` で 1 ホップ取得できる。

### その論文を引用している後続論文を探す

```matlab
query         = "";
seedId        = "10.1021/ci034243x";
snowballMode  = "citing";
sortBy        = "cited_by_count:desc";
citedByMin    = 5;
requireOpenAccess = true;
```

### その論文の参考文献を辿る

```matlab
query         = "";
seedId        = "10.1021/ci034243x";
snowballMode  = "referenced";
sortBy        = "cited_by_count:desc";
citedByMin    = 5;
requireOpenAccess = false;
```

用途:

- 既知ベンチマーク論文の後続改良系を拾う
- 高被引用論文の reference から古典を押さえる
- キーワードだけでは漏れる関連論文を補完する

---

## 2. Excel で候補を機械的に絞る

K フェーズ以降は、目視だけに頼らず `fwci` と `repro_signal_score` を主軸に並べ替える。

### Overview シートで見る列

| 列 | 見方 |
|---|---|
| `cited_by_count` | 絶対的な影響力。まず全体の強さを見る |
| `fwci` | 分野・年齢を補正した強さ。新しめの有望論文を拾う |
| `citation_percentile` | 同分野・同年代内での相対順位 |
| `repro_signal_score` | 再現しやすさのヒント。0〜4 |
| `is_oa` | PDF 到達性の最低条件 |

### Detail シートで見る列

| 列 | 見方 |
|---|---|
| `mentions_dataset` | ESOL / BBBP / MoleculeNet など既知データセットの言及 |
| `mentions_code` | GitHub / code available などの言及 |
| `mentions_library` | RDKit / scikit-learn / PyTorch / DeepChem / MATLAB など |
| `mentions_metrics` | RMSE / ROC-AUC / MAE / cross-validation など |
| `repro_signal_score` | 上記 4 カテゴリの合計 |

### 実務上の並べ替え順

1. `repro_signal_score` 降順
2. `fwci` 降順
3. `cited_by_count` 降順
4. `publication_year` 降順

この順にすると、

- データセット・コード・主要ライブラリ・評価指標を明示した論文
- 単なる古典ではなく、今も相対的に強い論文
- 比較的最近で追試価値のある論文

が上位に集まりやすい。

---

## 3. EasyMolKit の Tier 判断

目安:

| Tier | 条件の目安 |
|---|---|
| A | `repro_signal_score >= 3` かつ `fwci` が高い。既知データセットまたはコード言及あり |
| B | `repro_signal_score >= 2`。手法は魅力的だが、実装やデータの補完調査が必要 |
| C | `repro_signal_score <= 1`。面白いが再現コストが読みにくい |

補足:

- `cited_by_count` が高くても `repro_signal_score=0` の論文は、再現着手コストが高いことがある
- `fwci` が高い新規論文は、被引用絶対数がまだ小さくても候補価値がある

---

## 4. Candidate Ledger に登録する

Phase L 以降は、目視で残したい候補を run 単位ではなく台帳に蓄積する。

### 4.1 検索直後に自動追記する

`main_run_pipeline.m` で以下を有効化する:

```matlab
appendToCandidates = true;
```

これにより実行後に以下が更新される:

```text
result/candidates/candidates.jsonl
result/candidates/candidates.xlsx
result/candidates/repro_candidates.md
```

- `candidates.jsonl` が正本
- `doi_normalized`（空なら `openalex_id`）で重複排除される
- 既存行の `status` / `note` は保持され、再観測時は `last_seen_run_id` だけ更新される

### 4.2 目視後に状態を更新する

`candidates.xlsx` または `candidates.jsonl` を見て、少なくとも以下を更新する:

- `status = reviewed` : EasyMolKit へ渡す候補
- `status = rejected` : 今回は見送る候補
- `note` : Tier 判断や補足メモ

`registered_RPxx` は EasyMolKit 側へ登録した後の状態管理に使う。

コードで更新する場合は `update_candidates_ledger` を使える:

```matlab
update_candidates_ledger( ...
    ledgerPath="result/candidates/candidates.jsonl", ...
    doiNormalized="10.1000/example", ...
    status="reviewed", ...
    note="Tier A candidate");
```

### 4.3 EasyMolKit 向け Markdown を使う

`export_candidates_md` は `status="reviewed"` の行だけを、EasyMolKit `docs/repro_candidates.md` と同じ列構成で出力する。

出力列:

| 列 | 用途 |
|---|---|
| `RP番号` | EasyMolKit 側で採番 |
| `論文` | 候補論文名 |
| `DOI` | 原典リンク |
| `Tier` | `repro_signal_score` からの初期推定 |
| `状態` | `reviewed` / `registered_RPxx` など |
| `特記` | 台帳の `note` |

EasyMolKit 側へ貼り付けた後、正式な Tier と RP 番号を確定する。

---

## 5. 2026-07-17 時点の確認メモ

2026-07-17 に AnyResearch 上で以下を確認済み:

- `citedByMin` / `citedByMax` は OpenAlex filter に反映される
- `fwci` / `citation_percentile` / `repro_signal_score` は Excel 出力列に載る
- `test_repro_signals_smoke`, `test_analytics_smoke`, `test_snowball_smoke` は PASS
- クエリ `Morgan fingerprint ECFP cheminformatics QSAR` で、`repro_signal_score` と `fwci` を使った候補上位化が実データで機能する

---

## 関連

- `main_run_pipeline.m`
- `src/pipeline/run_pipeline.m`
- `config/repro_signals.example.json`
- `docs/quickstart.md`
- EasyMolKit `repro/TEMPLATE.md`
