# 変更履歴

&nbsp; [English](../../CHANGELOG.md)

このファイルは [CHANGELOG.md](../../CHANGELOG.md) の日本語ミラーです。
詳細な実装履歴や開発メモは private な dev リポジトリ側で管理します。

## Unreleased

## 1.14.0 - 2026-10-02

### 追加
- **Query**・**Country code**・PDF のキーワード証跡で、同じ検索構文を使えるようにした。
  スペース＝AND、`|`＝OR、`"..."`＝フレーズ、`( )`＝グループ化。大文字の `AND` / `OR` も同じ意味で使える。
- **Country code** で複数の国を指定できるようにした。`JP|US`（いずれか）と `JP+US`（列挙した全ての国の著者を含む論文。
  国際共著の抽出など）。`,` と `;` も OR の区切りとして使え、コードは自動で大文字になる。
- Search タブに **Search in** を追加した（スクリプトでは `searchField`）。`all`（既定。従来どおり）はタイトル・abstract・
  全文を対象にし、`title_and_abstract` はタイトルと abstract だけを対象にする（結果表に見える範囲）。
  選択は `run_meta.json` に記録される。
- Query・Country code・Search in のツールチップで構文を説明するようにした。

### 変更
- 検索を始める前に Query と Country code を検証するようにした。不正な入力は、OpenAlex 側でのエラーや想定外の結果
  ではなく、「Check your input」と修正方法を示すメッセージで止まる。Batch の Query も同様に検証する。
- 1 つの Query で AND と OR を括弧なしで混ぜられなくなった。`a b | c` は受け付けず、`a (b | c)` または
  `(a b) | c` と書く。
- ダウンロードした PDF のキーワード証跡（Layer 3）が Query の構文に従うようにした。PDF 本文が式全体を満たせば
  該当とし、`MATLAB Simulink` や `a | b` も見つかる。以前はクエリ全体を 1 つの連続したフレーズとして検索していた。

### 修正
- Country code の `JP,US` が OpenAlex の HTTP 400 エラーになっていた。`JP|US` として扱うようにした。

## 1.13.0 - 2026-10-02

### 追加
- Search タブに **Max records** 欄（既定 1,000 件）を追加。キーワード検索の前に一致件数を 1 回確認し、
  上限を超えるときだけ「先頭 N 件」「その回だけ全件」「キャンセル」を選べる。上限で止まった完了文言には
  取得件数と一致件数を表示し、第一著者機関を指定した検索ではその件数が追加の絞り込み前であることも説明する。
  全件を選んでも欄の値は変わらず、スクリプトからも検索ごとの上限を指定できる。スノーボール検索ではこの確認を行わない。
- 検索またはバッチが成功した後、ウィンドウ下部の **Open output folder** ボタンから出力先を開けるようになった。
- Seed が空のまま Search の Query に DOI または OpenAlex Work ID を入力すると、Seed 欄へ移す／キーワードとして
  検索する／キャンセルする、のいずれかを選べるようになった。
- Batch Step 2 で、前回の機関リストから引き継いだ行を灰色で表示するようになった。**Include all** は機関 ID の
  ある行だけを選択し、**Include none** はすべての選択を外す。
- Batch Step 2 で新規行数と引き継ぎ行数を表示し、レビュー保存後に確認を表示するようになった。既存の確認済み
  リストを置き換えるときは、新旧の対象行数を示して確認し、旧リストをバックアップする。
- Batch のサマリーに、専用の filter 列を追加した。
- Country／Language／Minimum citations／Sort／Top N／First-author institution／Institution ID／Seed に
  ツールチップを追加した。

### 変更
- Search と Batch の既定日付を、固定の日付ではなく今日までの 1 年間に変更した。
- Batch の候補レビュー表で、新規に見つかった行を先頭にし、status 列を account の隣へ移動した。Institution ID
  欄を広げ、Step 3 には include=1 の行だけを検索すること、既存のリストを置き換えるには確認が必要で旧リストは
  バックアップされることを表示するようにした。
- 実行中は Search／Generate／Save review／Promote／Run batch／Save API key／Back を無効化し、完了後に戻すようにした。
- 入力の誤りと実行の失敗を、アラートとステータスで区別するようにした。たとえば入力の誤りには
  **Check your input** と表示する。

### 修正
- 旧形式の 2 列の機関リストを新規候補と合流するとき、既存の行が黙って対象外にならず、対象のまま維持されるようになった。
- Batch のドライランでフィルタがエラーとして表示されなくなり、Batch のサマリーに別項目として記録されるようになった。
- 0 件の検索でも、通常の検索と同じ構成の結果ファイルを出力するようになった。ヘッダのみの CSV と空の結果ファイルを含む。
- パイプラインの警告メッセージで、矢印が文字化けしなくなった。

### セキュリティ
- 候補生成、機関検索、Seed 解決、参考文献の解決、API 利用状況の確認で表示される OpenAlex リクエストエラーからも、
  API key を取り除くようになった。

### ドキュメント
- README と Quickstart FAQ（英日）に、Max records と件数確認、出力フォルダを開くボタン、灰色の引き継ぎ
  Batch 行と **Include all**／**Include none** を追加した。

## 1.12.4 - 2026-10-02

### 修正
- relevance でソートする検索が、OpenAlex の HTTP 400 エラーで失敗しなくなった。
- Minimum と Maximum citations のフィルタが境界値を含むようになった。Minimum 5 では引用数が 5 以上の論文、
  Maximum 5 では 5 以下の論文を返す。
- OpenAlex API key を設定せずに検索を開始したとき、無関係な配列サイズのエラーではなく、
  意図した「API Key is not configured」メッセージを表示するようになった。

### セキュリティ
- OpenAlex API key を実行フォルダのログへ書き出さず、アラートとログ内の OpenAlex リクエストエラーメッセージにも
  表示しないようになった。以前のバージョンで作成した実行フォルダには引き続き
  `logs/settings_front_override.json` にキーが含まれるため、そのフォルダを共有する前にこのファイルを削除すること。

### ドキュメント
- README と Quickstart FAQ: 1 回の検索で既定では最大 1,000 件を取得すること、さらに取得するには
  `run_pipeline` に `maxPages` を渡すことを明記。検索のページを取得している間に OpenAlex の総件数が変わる場合があるため、
  保存された行数は最初のヒット件数とわずかに異なることがある。

## 1.12.3 - 2026-09-30

### 変更
- 短い入力欄（日付、引用数、言語、国コード、Top N、PDF の上限、snowball mode）を、ウィンドウ半分まで
  広げず、狭く左寄せにした。ラベルと右端の値の間で視線が左右に振れなくなる。
  長い自由入力（Query、Seed ID、機関名）は従来どおり全幅。Batch では、実行ボタンを入力欄の下に置いた

## 1.12.2 - 2026-09-30

### 変更
- 起動時のステータス表示を「Ready. Configure Search and select Run Search.」から、全タブ共通のバーにふさわしい
  中立的な「Ready.」に変更した

### ドキュメント
- Quickstart: Settings タブの API Key は入力中に画面へ表示される（標準のテキスト入力欄でマスクなし）こと、
  Git の追跡対象外の `config/settings.json` に平文で保存されること、`ANYRESEARCH_OPENALEX_API_KEY` を使えば
  アプリ上に表示されないことを追記した

### アクセシビリティ
- 各入力欄を、対応する表示ラベルに関連付けた。スクリーンリーダーがラベルの文言を読み上げられる
  （見た目の変更なし）

## 1.12.1 - 2026-09-30

### 変更
- Batch: 例示の既定値（対象機関名・Query）を Search と同様に Placeholder 表示にし、入力済みの値と見分けられるようにした
- PDF の上限ラベルを「PDF check limit (first N results)」に変更。オプションの実挙動（結果の先頭 N 件を対象にする）に合わせた

### 修正
- **Batch: Step 1 から Step 2 へ進めない不具合。** 候補テーブルが候補 CSV を受け付けていなかった
  （文字列セル、および表に表示しない `works_count` 列が原因）。候補が読み込めるようになり、
  レビューの保存でも全 CSV 列（`works_count` を含む）と空欄がそのまま保たれる
- `config/settings.json` が読めない・保存先フォルダが無い場合に、API key の保存が生のエラーを出さなくなった。
  ステータスとアラートで理由を示し、入力したキーは保持される
- 矛盾する入力を分かりやすいメッセージで拒否: From が To より後の日付（Search・Batch）、
  Minimum citations が Maximum citations を超える場合。Batch の日付を空にすると Search と同様に「制限なし」になる
- Batch の dry run が「0/N institutions succeeded」ではなく dry run として表示されるようになった
- **Search: Seed の DOI / OpenAlex work ID だけで snowball 検索を開始できるようになった。**
  パイプラインは Query 空 + Seed ID を受け付けるのに、Run Search のガードが Query を必須にしていた
- **Batch が MATLAB のカレントフォルダに依存しなくなった。** 候補・確定済み機関リストと Batch の出力先を
  プロジェクトルート基準で解決する。従来はカレントがプロジェクトルート以外だと、出力が
  カレント直下（例: `src/app/result/`）に作られることがあった

## 1.12.0 - 2026-09-29

### 変更
- **GUI の視認性改善（4タブすべて）。** ラベルを入力欄の左ではなく真上に配置し、
  ラベルと入力欄の間で視線が左右に振れないようにした
  - **Search:** 16項目を **Basic** / **Filters** / **Advanced** の3パネルに分割。
    From/To の日付と Minimum/Maximum citations は横並び。小さい窓では縦スクロールし、
    **Run Search** は常に見える
  - **Batch:** Step 1・Step 4 を同じラベル上配置に変更
  - **Analytics & PDF:** PDF オプションを1列に縦積みし、Analytics パネルの大きな空白を解消
  - **Settings:** API key 入力欄と **Save API key** ボタンを同じ行に配置
- 書式例（Search の Query など）を Placeholder 表示にし、入力済みの値と見分けられるようにした。
  言語`en`・国コード`JP`のような実用上の既定値は従来どおり
- 分かりにくかった項目にツールチップを追加: seed ID、snowball mode、maximum citations、
  document type、country filter、dry run、PDF オプション（テキスト抽出・キーワード証跡は
  PDF ダウンロードが有効なときだけ動く）

### 修正
- Batch を空の Query で実行した場合、機関ごとに失敗する代わりに、分かりやすいメッセージで停止するようにした

破壊的変更: なし
移行: 不要

## 1.11.1 - 2026-09-29

### 修正
- **`AnyResearchApp.mlapp`から実行するとSettingsタブのAPI Key保存が失敗する不具合。**
  プロジェクトルートの解決に`mfilename('fullpath')`を使っていたが、これはパッケージ化された
  `.mlapp`から読み込まれた場合にリポジトリを正しく指さない（`src/app/AnyResearchApp.m`を
  直接実行した場合のみ正しく動く）ため、保存先がプロジェクト外になりエラーになっていた。
  `which('AnyResearchApp')`経由の解決に変更し、両方の形式で正しく動くようにした。
  同じパターンを使っていたSearch・Batchも同様のリスクがあったため同時に修正した
- 「isolated test settings file」というメッセージが、通常の`config/settings.json`への
  保存時にも誤って表示される不具合を修正

## 1.11.0 - 2026-09-29

### 追加
- GUI（`AnyResearchApp.mlapp`）: `.m` ファイルを編集せずに使える、
  `main_run_pipeline.m` / `main_run_batch.m` の代替入口。Search / Batch /
  Analytics & PDF / Settings の4タブで Layer 0〜3 をカバーする。
  MATLAB R2026b 以降が必要。起動方法は
  [クイックスタートガイド](../quickstart.md#4-任意-gui-anyresearchappmlapp) を参照。

## 1.10.1 - 2026-07-21

### 修正
- **not_found 行を含む昇格済み `institutions.csv` で Section 1 がクラッシュする不具合。**
  `prepare_institutions_csv` は機関を照合できないと `openalex_institution_id` が空の行を
  書き出す。空の CSV セルは `<missing>` として読まれ、`"<missing>" ~= ""` が true になるため、
  これらの行が行フィルタを通過して ID 検証に到達し、include フィルタより前に
  「`<missing>` の string 要素」という分かりにくいエラーで停止していた。
  `load_institutions_list` は missing 値を正規化し、実際に使用する行（include=1）のみ
  ID を検証するようにして、未照合・除外行で実行を止めないようにした。

## 1.10.0 - 2026-07-21

### 追加
- `main_run_batch.m` に Section 0.6 を追加。レビュー済みの
  `data/list/institutions_candidate.csv` を `data/list/institutions.csv` へ
  昇格できるようにした。既存の本番リストは上書き前に
  `institutions.csv.bak.<timestamp>` としてバックアップされる。
- `promote_reviewed_institutions_csv.m` と、コピー元欠落・新規コピー・
  バックアップ（既存ファイルが空の場合を含む）・同一パス拒否を確認する
  offline smoke test を追加。

### 変更
- `prepare_institutions_csv` の完了メッセージで、候補レビュー後に
  Section 0.6 で昇格する導線を案内するようにした。
- ベンチマーク機関ワークフローに、候補レビュー→昇格→本実行の流れと、
  同名別機関の副次ヒットに対する注意を追記。

## 1.9.2 - 2026-07-21

### 修正
- **候補生成が `mergeWith` ファイルでハードエラーになる不具合。**
  `main_run_batch` は `data/list/institutions.csv` を「過去のレビュー結果をマージする
  入力」として `prepare_institutions_csv` に渡すが、新規セットアップではこのファイルが
  無い、または手書きリストにレビュー用の列が無いため、`MergeInputNotFound` /
  `MergeMissingColumn` で処理全体が止まっていた。マージを best-effort 化し、
  ファイルが無い／不正な場合はログ／警告を出して新規候補を生成して継続するよう修正。

## 1.9.1 - 2026-07-21

### 修正
- **example からコピーした `settings.json` で API キーが読めない不具合。**
  `jsondecode` は先頭が `_` の JSON キーを `x_`（例: `_comment` → `x_comment`）へ
  改名するが、config ローダは `_` 始まりしかスキップしていなかったため、
  `settings.example.json` 同梱のメタキーが config に混入し、環境変数オーバーライド
  処理で例外になっていた。結果、キーが入っていても「未設定」に見えていた。
  改名後のメタキーをスキップし、非構造体セクションを防御的に無視するよう修正。
  `config/settings.example.json` をコピーして `settings.json` を作った全ユーザーが対象。
- **「Run Section」で `main_run_batch` / `main_run_pipeline` が失敗する不具合。**
  セクション単独実行（Ctrl+Enter）や未保存バッファ実行では `mfilename('fullpath')`
  が temp フォルダを指し、`src/` や `config/settings.json` を見つけられなかった。
  Current Folder にフォールバックし、リポルートでない場合は明確なメッセージを出すよう修正。

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
