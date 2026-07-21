# リリースノート v1.0.0

&nbsp; [English](../release_notes_v1.0.0.md)

- リリース日: 2026-04-03
- ブランチ: `master`
- 前バージョン: v0.1.0（2026-03-30）

> English release notes: [en/release_notes_v1.0.0.md](../release_notes_v1.0.0.md)

---

## 概要

v1.0.0 は AnyResearch の初の安定版メジャーリリースです。
Layer 0（コア）の品質・信頼性強化に加え、Analytics 分析層（Layer 2）と arXiv 統合を新たに追加。
Layer 1 バッチ機能の拡充、複数のバグ修正、ドキュメント整備を行い、
**エンドユーザーが安心して使える完全版** としてリリースします。

---

## 新機能

### Layer 2: Analytics（自動統合）

追加設定なしで Summary シートと `batch_comparison.xlsx` に分析指標が自動付加されます。

| 指標 | 意味 |
|---|---|
| `avg_citation_velocity` | 論文1件あたりの年次平均引用速度（注目度の代理指標） |
| `growth_rate_pct` | 年次論文数の成長率（%） |
| `institution_dominance` | 機関別の論文シェア × 引用シェアの複合スコア（バッチ時） |

> これらは OpenAlex の収録データにもとづく簡易指標です。最終的な判断はユーザー自身が文脈を踏まえて行ってください。

### arXiv 統合（useArxiv=true）

OpenAlex への収録前のプレプリントを arXiv からも並行取得できます。

```matlab
useArxiv = true;   % arXiv からプレプリントを追加取得（デフォルト: false）
```

- `source_dataset` 列で OpenAlex / arXiv 由来を識別可能
- OpenAlex 収録済み論文との DOI 重複を自動排除
- `filterType = "article"` 指定時は arXiv の `"preprint"` を除外

### 機関フィルタの強化（Layer 0）

`firstAuthorInstitutionId` に OpenAlex の機関 ID を指定することで、API 取得段階から正確に絞り込めます。

```matlab
firstAuthorInstitution   = "The University of Tokyo";   % 名前のみでも動作
firstAuthorInstitutionId = "I26973366";                  % ID 指定で確実（推奨）
```

ID は `lookup_institution_id("機関名")` で調べられます。1機関名に複数の ID 候補が返る場合があるため、`works_count` を参考に本体の ID を選んでください。

### バッチ横断比較の拡充

`batch_comparison.xlsx` に Analytics 指標が追加され、機関間の引用速度・成長率・dominance スコアを横断比較できます。

---

## バグ修正

| # | 現象 | 修正内容 |
|---|---|---|
| ① | 286件ヒットなのに10件しか取得されない | `maxRowsForValidation` デフォルト値を 10 → 0（無制限）に修正 |
| ② | `enablePdfDownload=false` なのに `pdf_text_extraction: error` が記録される | PDF 関連フラグの伝播ロジックを修正（`skipped` に変更） |
| ③ | OR クエリ `"solar\|wind"` が正しく動作しない | `fetch_openalex_works.m` のパイプ文字エスケープ処理を修正 |
| ④ | ゼロ件クエリでエラー終了する | 空結果をグレースフルに処理し、空 xlsx・空 JSONL を生成するよう修正 |

---

## その他の改善

- **MATLAB Online バッジ** を README に追加（クリックで即時実行可能）
- **日英 README の相互リンク** を追加（`README.md` ↔ `README.ja.md`）
- **テストスイート拡充**: 26本のスモークテストを整備（arXiv 統合・Analytics・新6列確認テスト等を追加）
- **ドキュメント整合性**: Layer 表記の誤記修正、存在しないディレクトリ記載の削除
- **レガシーコード削除**: 旧スコアリングパイプライン（`src/scoring/`）および YAML 設定ファイルを除去

---

## アップグレードガイド（v0.1.0 → v1.0.0）

**破壊的変更はありません。** `main_run_pipeline.m` / `main_run_batch.m` の既存のパラメータ設定はそのまま動作します。

新機能を利用する場合は以下を `main_run_pipeline.m` の Section 0 に追記してください:

```matlab
useArxiv = false;   % true で arXiv プレプリントを追加取得
```

---

## 動作要件（変更なし）

| 項目 | Layer | 必須/任意 |
|---|---|---|
| MATLAB R2025b 以降 | 0 | 必須 |
| OpenAlex API Key（無料） | 0 | 必須 |
| institutions.csv | 1 | 任意 |
| Text Analytics Toolbox | 3 | 任意 |
| Python 3.11 + venv | 3 | 任意 |
