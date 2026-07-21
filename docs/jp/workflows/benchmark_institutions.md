# ベンチマーク機関ワークフロー

&nbsp; [English](../../workflows/benchmark_institutions.md)

> 更新日: 2026-07-21

## 目的

`main_run_batch.m` を使った複数機関ベンチマークの現行ワークフローを整理する。
機関CSVの作成、目視レビュー、検証、実行までを 1 本の流れとして扱う。

## 関連関数

- `src/openalex/prepare_institutions_csv.m`
- `src/openalex/load_institutions_list.m`
- `src/openalex/merge_institutions_review_table.m`
- `src/pipeline/run_batch_from_institutions_list.m`

## `institutions.csv` の受け入れ形式

架空プレースホルダ機関のコピー用サンプルを
[`data/sample/institutions_sample.csv`](../../../data/sample/institutions_sample.csv) に用意している。
プレースホルダを自分のターゲットに置き換え、`data/list/institutions.csv` として保存する。

### 1. 旧 2 列形式

後方互換のため読み込み可能。

```csv
Account,openalex_institution_id
Example Research University,I1234567890
Example Medical University,I100000001
Example Medical University,I100000002
```

### 2. reviewed v2 形式

今後の推奨形式。人手レビュー結果をそのままデータとして保持する。

```csv
account,openalex_institution_id,display_name,country_code,works_count,include,role,note,status
Example Medical University,I100000001,Example Medical University,JP,12345,1,main,,found
Example Medical University,I100000002,Example Medical University Hospital,JP,6789,1,hospital,,found
Example Medical University,I9999999999,Old Candidate,JP,50,0,other,excluded after review,found
```

列の意味:
- `account`: ターゲット名。同じ `account` の複数行は 1 ターゲットとして束ねられる
- `openalex_institution_id`: OpenAlex institution ID。形式は `I` + 数字
- `display_name`: OpenAlex の表示名。目視確認用
- `country_code`: 国コード。候補確認の補助情報
- `works_count`: OpenAlex 上の論文数。候補の見分けに使う
- `include`: 実行対象フラグ。`1/0`, `true/false`, `yes/no` を受け入れる
- `role`: `main`, `hospital`, `branch`, `other` などの補助メモ
- `note`: 自由記述メモ。実行では使わない
- `status`: `found` / `not_found` / `api_error`。候補生成時の監査用

## 候補CSVの作成

### 新規作成

```matlab
prepare_institutions_csv(["Example Research University", "Example Technical University", "Example Metropolitan University"], ...
    countryFilter="JP", maxCandidates=3)
```

- 出力先既定値は `data/list/institutions_candidate.csv`
- 出力列は reviewed v2 にそのまま合わせてある
- `rank=1` の候補だけ `include=1` を提案し、それ以外は `0`
- `display_name` に `Hospital` / `病院` を含む候補には `role="hospital"` を提案
- `not_found` / `api_error` は空 ID 行として残るため、探索漏れを監査できる

### 既存レビューの保持つき再生成

```matlab
prepare_institutions_csv(["Example Research University", "Example Technical University"], ...
    countryFilter="JP", ...
    mergeWith="data/list/institutions.csv")
```

`mergeWith` を使うと:
- 既存の `account` × `openalex_institution_id` は `include` / `role` / `note` を保持
- API 由来の `display_name` / `country_code` / `works_count` / `status` は最新化
- 既存 account に新しく現れた ID は `include=0` で追加され、`note` に `new candidate since <date>` を付与
- API に出なくなった既存 ID は削除せず残し、`note` に `not returned by API on <date>` を追記

## 目視レビューと本番CSVへの昇格

`data/list/institutions_candidate.csv` を開き、少なくとも以下を確認する。

- 採用する行の `include` を `1`、除外する行を `0`
- 複数 ID を残す理由があれば `role` に記録
- 判断根拠や保留事項があれば `note` に記録

候補検索では同名別機関の副次ヒットが混じることがある。
例えば `Nagoya University` の検索で、別機関である `Nagoya City University` が候補に出る場合がある。
`display_name` / `country_code` / `works_count` を見て、目的のベンチマーク対象に含める行だけを採用する。

レビュー後、`main_run_batch.m` から候補CSVを本番入力へ昇格する。

```matlab
prepareList = false;
promoteReviewed = true;
```

この状態で Section 0.6 を実行すると、`data/list/institutions_candidate.csv` が
`data/list/institutions.csv` にコピーされる。既存の `institutions.csv` がある場合は、
先に `institutions.csv.bak.<timestamp>` としてバックアップされる。

想定フローは次の 4 ステップ。

1. `prepareList=true` にして Section 0.5 を実行し、`institutions_candidate.csv` を生成する
2. `institutions_candidate.csv` の `include` / `role` / `note` を目視レビューする
3. `promoteReviewed=true` にして Section 0.6 を実行し、`institutions.csv` へ昇格する
4. 両方のフラグを `false` に戻して Section 1 を実行する

列名の変更は不要。

## 実行前検証

`run_batch_from_institutions_list` は内部で `load_institutions_list.m` を呼び、次を検証する。

- 必須列: `Account/account`, `openalex_institution_id`
- ID 形式: `^I\d+$`
- `include` 値: `1/0`, `true/false`, `yes/no`, 数値文字列
- account 内の重複 ID: 自動 dedup
- account 間の重複 ID: warning
- `include=1` が 0 件の account: warning を出して skip

レビュー済みCSV単体の検証だけなら:

```matlab
load_institutions_list("data/list/institutions.csv")
```

## Batch 実行時の挙動

- 同じ `account` の `include=1` 行を 1 ターゲットに束ねる
- ターゲット内の ID は `I1|I2|...` に連結して `run_pipeline` へ渡す
- `resolveInstitutionIds=false` を強制し、レビュー済み ID を再解決しない
- `batch_summary.csv.openalex_institution_id` には連結後の ID が入る
- `result/batch/<timestamp>/runs/` は「CSV 行単位」ではなく「ターゲット単位」の run 構成になる

## テスト

### ネットワーク不要

```matlab
addpath("test");
run_smoke_tests("offline")
```

- `test_load_institutions_list_smoke()`
- `merge_institutions_review_table` の保持ロジックは `test_prepare_institutions_csv_smoke()` 内の offline ケースで検証

### ネットワークあり

- `test_prepare_institutions_csv_smoke()`
  - reviewed v2 列構成
  - `include` 提案値
  - `role="hospital"` 提案
  - `countryFilter` / `maxCandidates`
  - `mergeWith` の roundtrip
- `test_run_batch_smoke()`
  - `load_institutions_list` 経由の入力検証
  - `resolveInstitutionIds=false`
  - 複数 ID ターゲットの `|` 連結
  - `run_meta.json` への伝播
