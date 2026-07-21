# Release Notes v0.1.0

&nbsp; [English](../release_notes_v0.1.0.md)

- Release Date: 2026-03-30
- Branch: `v0.1.0`
- Previous: —（初回リリース）

> English release notes: [en/release_notes_v0.1.0.md](../release_notes_v0.1.0.md)

---

v0.1.0 は AnyResearch の初回公開リリースです。
OpenAlex API を活用した学術論文収集・整形・Excel 出力パイプライン（Layer 0）を完成させ、
フロント入口の分離・パイプライン統合・テスト整備・Phase 6A UX 強化を一括収録します。

本バージョンは **`query=` だけで動く最小構成（Layer 0）** をすべて内包しており、
追加ライセンスなしで MATLAB + OpenAlex API Key（無料）のみで利用可能です。

---

## 主な追加・変更

### 1) パイプライン統合・フロント分離（Phase 3〜5）

- `src/pipeline/run_pipeline.m` を新設。オーケストレーション本体をすべてここに集約
- `main_run_pipeline.m`（単一検索）と `main_run_batch.m`（複数機関バッチ）を完全独立化
  - 両ファイルは「パラメータ設定 + `run_pipeline(...)` 呼び出し 1 行」だけの構成
  - 相互の変数に依存しない完全自己完結設計
- `src/pipeline/run_batch_from_institutions_list.m`：バッチロジックを `run_pipeline` ループに統合
- `src/pipeline/create_run_context.m`：実行ディレクトリ構造の生成を関数化

### 2) Excel 出力 4 シート構成（Phase 2）

- `src/export/export_excel_workbook.m`：エントリポイント（JSONL → xlsx）
- Overview / Detail / Summary / Config の 4 シートを生成
- COM モードと writecell フォールバックの 2 段構成で日本語文字化けを回避
- `src/export/excel_apply_header_style.m`：ヘッダスタイル再利用ヘルパー

### 3) Phase 6A: UX 改善・API 強化

| # | 機能 | 概要 |
|---|---|---|
| L0-1 | ソート順パラメータ `sortBy` | `"cited_by_count:desc"` / `"publication_date:desc"` / `"relevance_score"` に対応 |
| L0-2 | 文献種別フィルタ `filterType` | `"article"`, `"review"`, `"article,review"` 等。カンマ区切りで複数指定可 |
| L0-3 | 検索構文コメント | AND（スペース） / OR（`\|`） / フレーズ（引用符）をフロント .m にコメント記載 |
| R-1 | API リトライ | `fetch_openalex_works.m` に 429/503 時の最大 3 回・exponential backoff リトライを実装 |
| D-1 | ユースケース別ガイド | quickstart に文献レビュー・機関比較・技術動向調査のペルソナ別セクションを追加 |

### 4) API 認証対応（Phase 1）

- OpenAlex 2026 年〜の `api_key` 認証に対応（クエリパラメータ方式）
- `config/settings.json` または環境変数 `ANYRESEARCH_OPENALEX_API_KEY` で管理
- `src/config/load_runtime_config.m`：環境変数 > JSON > デフォルト の優先順位で設定をロード

### 5) テストスイート整備（Phase 3〜6A）

20 本のスモークテストを `test/smoke/` に整備。全 PASS を確認済み。

**新規追加テスト（Phase 6A）:**
- `test_phase6a_params_smoke.m`（7 ケース）：`sortBy` / `filterType` / リトライ関数の存在確認

**テスト品質改善（既存）:**

| ファイル | 改善内容 |
|---|---|
| `test_extract_pdf_text_python.m` | アサーションゼロの中身なしテストを 3 ケース（存在確認・型確認・サンプル実行）に全面書き直し |
| `test_phase5_score_matrix_smoke.m` | 3 個の無メッセージ assert → 4 ケースに再構成。`isfield` ガード・説明文・tmpdir・`onCleanup` を追加 |
| `test_run_batch_smoke.m` | 最終 `assert(passCount >= 5)` を追加。T1〜T5 の無症状失敗を防止 |
| `test_phase6a_params_smoke.m` | Case 6/7 追加：`run_pipeline` 経由の `filterType`・`sortBy` が設定 JSON に正しく書き込まれることを E2E 検証 |

---

## ファイル構成（主要）

```
main_run_pipeline.m        単一検索フロント
main_run_batch.m           バッチ検索フロント
src/
  pipeline/
    run_pipeline.m         オーケストレーション本体
    run_batch_from_institutions_list.m
    create_run_context.m
    fetch_and_normalize_works.m
  openalex/
    fetch_openalex_works.m  (sortBy / retry 対応)
  export/
    export_excel_workbook.m
    excel_write_{overview,detail,summary,config}.m
  config/
    load_runtime_config.m
  util/
    log_{info,warn,error,progress}.m
test/smoke/                20 本のスモークテスト
config/settings.example.json
docs/quickstart.md
```

---

## 既知の制限・注意事項

- **Excel COM 書き込み**: `-batch` モード（非GUIで `actxserver` が利用できない環境）では自動的に `writecell` フォールバックに切り替わります
- **Layer 1（PDF）**: `enablePdfDownload=true` を指定した場合は Python venv の事前構築が必要です（`src/python/requirements.txt` 参照）
- **Layer 2（OpenAI）**: `enableOpenAiSummary=true` を指定した場合は OpenAI API Key（有償）が必要です

---

## 実行方法（最速）

```matlab
% 1. API Key を設定（初回のみ）
% config/settings.json の openalex.api_key に記入

% 2. 単一検索を実行
main_run_pipeline   % query / fromDate / toDate を編集してから実行
```

---

## テスト実行

```matlab
addpath(genpath('src')); addpath('test/smoke');
test_config_precedence_smoke();
test_pdf_validation_smoke();
test_excel_export_smoke();
test_pipeline_e2e_smoke();     % ネットワーク必要
test_phase6a_params_smoke();
```

---

## 破壊的変更

初回リリースのため、破壊的変更はありません。

---

## 移行メモ

- 旧バージョン（複製元プロジェクト v2 系）からの移行: `config/settings.json` の `openalex.api_key` を設定してください
- バッチ実行は必ず `main_run_batch.m` を使用してください（`main_run_pipeline.m` はバッチ未対応）
