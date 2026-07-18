function test_excel_export_smoke()
%TEST_EXCEL_EXPORT_SMOKE  Phase 2: Excel 4-sheet output smoke test
%
%   How to run:
%     addpath("src/export"); addpath("src/util"); addpath("src/pipeline");
%     addpath("test/smoke");
%     test_excel_export_smoke();
%
%   Test coverage:
%     T1. export_excel_workbook: Normal case (JSONL input -> xlsx generated)
%     T2. export_excel_workbook: CSV fallback input
%     T3. export_excel_workbook: Error when input is absent
%     T4. excel_write_overview:  spec struct integrity (11 columns / headers / hyperlinks)
%     T5. excel_write_overview:  DOI hyperlink generation
%     T6. excel_write_overview:  is_oa conversion (logical / numeric / string) -> Yes/No
%     T7. excel_write_overview:  abstract truncated to 500 chars
%     T8. excel_write_detail:    spec integrity (33 columns / English header content)
%     T9. excel_write_detail:    fill with empty when column is absent (source_name / is_oa, etc.)
%     T10. excel_write_summary:  Annual aggregation (3 years + Total row), English header content
%     T11. excel_write_summary:  Case where publication_year column is absent
%     T12. excel_write_config:   cfg field reflection / English header content / key labels
%     T13. excel_write_config:   Default "(not set)" when cfg field is absent
%     T14. export_excel_workbook: Data containing Japanese characters is written to xlsx
%     T15. create_run_context:   search_results_* fields must exist
%     T16. excel_write_detail:   is_oa conversion (logical/numeric/string) -> Yes/No
%     T17. excel_write_detail:   matlab_mentioned conversion ("1"/"true" -> Yes, "0" -> '')
%     T18. excel_a1_range:       column labels beyond Z
%     T19. COM mode:             export uses COM when available and preserves Japanese text

fprintf('\n=== test_excel_export_smoke ===\n');
passCount = 0;

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'export'));
addpath(fullfile(projectRoot, 'src', 'util'));
addpath(fullfile(projectRoot, 'src', 'pipeline'));

tmpDir = fullfile(tempdir, 'smoke_excel_export');
if isfolder(tmpDir)
    rmdir(tmpDir, 's');
end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

% ─── Sample test data ───────────────────────────────────────
T_normal = local_make_test_table();

%% T1: export_excel_workbook — JSONL input -> xlsx generated
fprintf('[T1] export_excel_workbook: JSONL → xlsx ...');
jsonlPath = fullfile(tmpDir, 'test_input.jsonl');
xlsxPath  = fullfile(tmpDir, 'test_out_t1.xlsx');
write_jsonl(T_normal, jsonlPath);
cfg = local_make_cfg();
export_excel_workbook(jsonlPath, xlsxPath, cfg);
assert(isfile(xlsxPath), 'T1: xlsx ファイルが生成されていない');
info = dir(xlsxPath);
assert(info.bytes > 1024, 'T1: xlsx ファイルサイズが小さすぎる (< 1KB)');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T2: export_excel_workbook — CSV fallback input
fprintf('[T2] export_excel_workbook: CSV フォールバック ...');
csvPath   = fullfile(tmpDir, 'test_input.csv');
xlsxPath2 = fullfile(tmpDir, 'test_out_t2.xlsx');
writetable(T_normal, csvPath, "Encoding", "UTF-8");
export_excel_workbook(csvPath, xlsxPath2, cfg);
assert(isfile(xlsxPath2), 'T2: CSV フォールバックで xlsx が生成されていない');
info2 = dir(xlsxPath2);
assert(info2.bytes > 1024, sprintf('T2: CSV フォールバック xlsx が 1KB 未満 (%d bytes)', info2.bytes));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T3: export_excel_workbook — Error when input is absent
fprintf('[T3] export_excel_workbook: 入力不在でエラー ...');
try
    export_excel_workbook(fullfile(tmpDir, 'nonexistent.jsonl'), ...
        fullfile(tmpDir, 'unused.xlsx'));
    error('T3: エラーが投げられなかった');
catch ex
    assert(contains(ex.identifier, 'InputNotFound') || ...
           contains(ex.message, 'not found') || contains(ex.message, 'not exist'), ...
        ['T3: unexpected error: ' ex.message]);
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T4: excel_write_overview — spec integrity (11 columns)
fprintf('[T4] excel_write_overview: spec 完整性 ...');
spec = excel_write_overview(T_normal, struct());
assert(isfield(spec, 'sheetName'),  'T4: sheetName なし');
assert(isfield(spec, 'headers'),    'T4: headers なし');
assert(isfield(spec, 'data'),       'T4: data なし');
assert(isfield(spec, 'hyperlinks'), 'T4: hyperlinks なし');
assert(spec.nCols == 11, sprintf('T4: nCols=%d (expected 11)', spec.nCols));
assert(strcmp(spec.sheetName, 'Overview'), 'T4: sheetName が Overview でない');
assert(numel(spec.headers) == 11, 'T4: headers 数が 11 でない');
assert(size(spec.data, 1) == height(T_normal), 'T4: data 行数が一致しない');
assert(size(spec.data, 2) == 11, 'T4: data 列数が 11 でない');
% Verify header content (English)
expectedH4 = {'title','DOI','publication_year','cited_by_count','fwci','citation_percentile','repro_signal_score','is_oa','source_name','type','abstract'};
for ci = 1:11
    assert(strcmp(spec.headers{ci}, expectedH4{ci}), ...
        sprintf('T4: headers{%d}="%s" (expected "%s")', ci, spec.headers{ci}, expectedH4{ci}));
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T5: excel_write_overview — DOI hyperlink generation
fprintf('[T5] excel_write_overview: DOI ハイパーリンク ...');
% T_normal rows 1-2 have DOI, row 3 does not
assert(numel(spec.hyperlinks) == 2, ...
    sprintf('T5: hyperlinks=%d (expected 2)', numel(spec.hyperlinks)));
assert(contains(spec.hyperlinks(1).url, 'doi.org'), 'T5: URL に doi.org が含まれない');
assert(spec.hyperlinks(1).row == 2, 'T5: hyperlink row は 2 (ヘッダ行+1) のはず');
assert(spec.hyperlinks(1).col == 2, 'T5: hyperlink col は 2 (DOI列) のはず');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T6: excel_write_overview — is_oa conversion (logical / numeric / string type)
fprintf('[T6] excel_write_overview: is_oa 変換 ...');
% logical type
T_oa_logic = table(["Title1";"Title2";"Title3"],["A1";"A2";"A3"],'VariableNames',["title","abstract"]);
T_oa_logic.is_oa = [true; false; true];
s_logic = excel_write_overview(T_oa_logic, struct());
assert(strcmp(s_logic.data{1,8}, 'Yes'), ['T6 logical true → expected Yes, got ' s_logic.data{1,8}]);
assert(strcmp(s_logic.data{2,8}, 'No'), ['T6 logical false → expected No, got ' s_logic.data{2,8}]);
% numeric type (1 / 0)
T_oa_num = table(["Title1";"Title2"],["A1";"A2"],'VariableNames',["title","abstract"]);
T_oa_num.is_oa = [1.0; 0.0];
s_num = excel_write_overview(T_oa_num, struct());
assert(strcmp(s_num.data{1,8}, 'Yes'), ['T6 numeric 1 → expected Yes, got ' s_num.data{1,8}]);
assert(strcmp(s_num.data{2,8}, 'No'), ['T6 numeric 0 → expected No, got ' s_num.data{2,8}]);
% string type ("true" / "false")
T_oa_str = table(["Title1";"Title2"],["A1";"A2"],'VariableNames',["title","abstract"]);
T_oa_str.is_oa = ["true"; "false"];
s_str = excel_write_overview(T_oa_str, struct());
assert(strcmp(s_str.data{1,8}, 'Yes'), ['T6 string "true" → expected Yes, got ' s_str.data{1,8}]);
assert(strcmp(s_str.data{2,8}, 'No'), ['T6 string "false" → expected No, got ' s_str.data{2,8}]);
fprintf(' PASS\n'); passCount = passCount + 1;

%% T7: excel_write_overview — abstract truncated to 500 chars
fprintf('[T7] excel_write_overview: 抄録 500 字打ち切り ...');
T_long = table( ...
    "LongTitle", string(repmat('A', 1, 1000)), ...
    'VariableNames', ["title", "abstract"]);
s_long = excel_write_overview(T_long, struct());
absCell = s_long.data{1, 11};
assert(length(absCell) <= 504, ... % 500 + '...' (3 chars) + 余裕
    sprintf('T7: 抄録長=%d (expected ≤504)', length(absCell)));
assert(endsWith(absCell, '...'), 'T7: 末尾が ... でない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T8: excel_write_detail — spec integrity (33 columns)
fprintf('[T8] excel_write_detail: spec 完整性 ...');
spec_d = excel_write_detail(T_normal, struct());
assert(spec_d.nCols == 33, sprintf('T8: nCols=%d (expected 33)', spec_d.nCols));
assert(strcmp(spec_d.sheetName, 'Detail'), 'T8: sheetName が Detail でない');
assert(size(spec_d.data, 1) == height(T_normal), 'T8: data 行数が一致しない');
assert(size(spec_d.data, 2) == 33, 'T8: data 列数が 33 でない');
% Verify header content (English) — representative positions
assert(strcmp(spec_d.headers{1},  'title'),           'T8: headers{1} が "title" でない');
assert(strcmp(spec_d.headers{5},  'is_oa'),            'T8: headers{5} が "is_oa" でない');
assert(strcmp(spec_d.headers{9},  'openalex_id'),      'T8: headers{9} が "openalex_id" でない');
assert(strcmp(spec_d.headers{14}, 'doi_normalized'),   'T8: headers{14} が "doi_normalized" でない');
assert(strcmp(spec_d.headers{15}, 'publication_date'), 'T8: headers{15} が "publication_date" でない');
assert(strcmp(spec_d.headers{23}, 'open_access_url'),   'T8: headers{23} が "open_access_url" でない');
assert(strcmp(spec_d.headers{28}, 'mentions_dataset'),  'T8: headers{28} が "mentions_dataset" でない');
assert(strcmp(spec_d.headers{32}, 'repro_signal_score'),'T8: headers{32} が "repro_signal_score" でない');
assert(strcmp(spec_d.headers{33}, 'matlab_mentioned'),  'T8: headers{33} が "matlab_mentioned" でない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T9: excel_write_detail — fill with empty when column is absent
fprintf('[T9] excel_write_detail: 列不在でも空欄補完 ...');
T_min = table( ...
    "Minimal Title", "Minimal abstract text.", ...
    'VariableNames', ["title", "abstract"]);
spec_min = excel_write_detail(T_min, struct());
assert(spec_min.nCols == 33, 'T9: 最小テーブルで nCols が 33 でない');
% All columns are empty (no error)
for c = 1:33
    v = spec_min.data{1, c};
    assert(ischar(v) || isnumeric(v), ...
        sprintf('T9: col %d の型が不正: %s', c, class(v)));
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T10: excel_write_summary — Annual aggregation (3 years + Total row)
fprintf('[T10] excel_write_summary: 年別集計 ...');
T_yr = local_make_year_table();
spec_s = excel_write_summary(T_yr, struct());
assert(strcmp(spec_s.sheetName, 'Summary'), 'T10: sheetName が Summary でない');
assert(spec_s.nCols == 8, sprintf('T10: nCols=%d (expected 8)', spec_s.nCols));
% Section 1: 3 years + Total row = 4 rows -> first 4 rows of spec.data
nSec1Rows = 4;
assert(size(spec_s.data, 1) >= nSec1Rows, ...
    sprintf('T10: data 行数=%d (expected >= %d)', size(spec_s.data, 1), nSec1Rows));
% Total row is the last row of sec1 (row 4)
totalRow = spec_s.data(nSec1Rows, :);
assert(strcmp(totalRow{1}, 'Total'), 'T10: sec1 の4行目が "Total" でない');
assert(totalRow{2} == height(T_yr), ...
    sprintf('T10: 合計件数=%d (expected %d)', totalRow{2}, height(T_yr)));
% Avg cited by count = (10+20+5+15+25+8)/6 = 83/6 ≈ 13.8
expAvg = round(mean([10 20 5 15 25 8]), 1);
assert(abs(double(totalRow{3}) - expAvg) < 0.05, ...
    sprintf('T10: 合計平均被引用数=%g (expected %g)', double(totalRow{3}), expAvg));
% Max cited by count = 25
assert(totalRow{4} == 25, sprintf('T10: 最大被引用数=%d (expected 25)', totalRow{4}));
% OA count: T_yr is_oa = [true;false;true;true;false;true] -> 4
assert(totalRow{5} == 4, sprintf('T10: OA件数=%d (expected 4)', totalRow{5}));
% Verify header content (English) — nCols=8
assert(strcmp(spec_s.headers{1}, 'year'),                      'T10: headers{1} が "year" でない');
assert(strcmp(spec_s.headers{2}, 'paper_count'),               'T10: headers{2} が "paper_count" でない');
assert(strcmp(spec_s.headers{3}, 'avg_cited_by_count'),        'T10: headers{3} が "avg_cited_by_count" でない');
assert(strcmp(spec_s.headers{4}, 'max_cited_by_count'),        'T10: headers{4} が "max_cited_by_count" でない');
assert(strcmp(spec_s.headers{5}, 'oa_count'),                  'T10: headers{5} が "oa_count" でない');
assert(strcmp(spec_s.headers{6}, 'avg_citation_velocity'),     'T10: headers{6} が "avg_citation_velocity" でない');
assert(strcmp(spec_s.headers{7}, 'growth_rate_pct'),           'T10: headers{7} が "growth_rate_pct" でない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T11: excel_write_summary — Case where publication_year column is absent
fprintf('[T11] excel_write_summary: publication_year 列不在 ...');
T_noyear = table(["Title1";"Title2"], ["Abs1";"Abs2"], ...
    'VariableNames', ["title","abstract"]);
spec_ny = excel_write_summary(T_noyear, struct());
% First row of sec1 contains the message
assert(contains(char(spec_ny.data{1,1}), 'publication_year'), ...
    'T11: 不在メッセージに publication_year が含まれない');
% Verify nCols and sectionRows exist
assert(spec_ny.nCols == 8, 'T11: nCols が 8 でない');
assert(isfield(spec_ny, 'sectionRows'), 'T11: sectionRows フィールドがない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T12: excel_write_config — cfg field reflection
fprintf('[T12] excel_write_config: cfg フィールド反映 ...');
T_dummy = table("T","A",'VariableNames',["title","abstract"]);
cfg12 = struct( ...
    'query', "deep learning", ...
    'from_date', "2023-01-01", ...
    'to_date', "2025-12-31", ...
    'filter', "is_oa:true", ...
    'run_id', "20260330_120000", ...
    'created_at', "2026-03-30T12:00:00");
spec_c = excel_write_config(T_dummy, cfg12);
assert(strcmp(spec_c.sheetName, 'Config'), 'T12: sheetName が Config でない');
% Verify headers ('key' / 'value')
assert(strcmp(spec_c.headers{1}, 'key'),   'T12: headers{1} が "key" でない');
assert(strcmp(spec_c.headers{2}, 'value'), 'T12: headers{2} が "value" でない');
% Verify key labels
allKeys = strjoin(string(spec_c.data(:, 1)), ' ');
assert(contains(allKeys, 'query'),      'T12: "query" キーがない');
assert(contains(allKeys, 'from_date'),  'T12: "from_date" キーがない');
assert(contains(allKeys, 'run_id'),     'T12: "run_id" キーがない');
assert(contains(allKeys, 'created_at'), 'T12: "created_at" キーがない');
% Safely join cell{:,2} (avoid vertcat for mismatched width)
allVals = strjoin(string(spec_c.data(:, 2)), ' ');
assert(contains(allVals, 'deep learning'), ...
    'T12: query "deep learning" が Config に反映されていない');
assert(contains(allVals, '2023-01-01'), ...
    'T12: from_date が Config に反映されていない');
assert(contains(allVals, '20260330_120000'), ...
    'T12: run_id が Config に反映されていない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T13: excel_write_config — "(not set)" when cfg field is absent
fprintf('[T13] excel_write_config: 不在フィールド → "(not set)" ...');
spec_empty = excel_write_config(T_dummy, struct());
% Verify query, from_date, etc. become "(not set)" from empty cfg
vals = spec_empty.data(:, 2);
unsetCount = nnz(cellfun(@(v) strcmp(char(v), '(not set)'), vals));
assert(unsetCount >= 4, ...
    sprintf('T13: "(not set)" の件数=%d (expected ≥4)', unsetCount));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T16: excel_write_detail — is_oa conversion (Yes/No)
fprintf('[T16] excel_write_detail: is_oa 変換 ...');
T_d_oa = table(["T1";"T2";"T3"],["A1";"A2";"A3"],'VariableNames',["title","abstract"]);
T_d_oa.is_oa = [true; false; true];
spec_d16 = excel_write_detail(T_d_oa, struct());
% is_oa is column 5
assert(strcmp(spec_d16.data{1,5}, 'Yes'), ['T16 logical true → expected Yes, got ' spec_d16.data{1,5}]);
assert(strcmp(spec_d16.data{2,5}, 'No'),  ['T16 logical false → expected No, got '  spec_d16.data{2,5}]);
T_d_oa_num = table(["T1";"T2"],["A1";"A2"],'VariableNames',["title","abstract"]);
T_d_oa_num.is_oa = [1.0; 0.0];
spec_d16n = excel_write_detail(T_d_oa_num, struct());
assert(strcmp(spec_d16n.data{1,5}, 'Yes'), ['T16 numeric 1 → expected Yes, got ' spec_d16n.data{1,5}]);
assert(strcmp(spec_d16n.data{2,5}, 'No'),  ['T16 numeric 0 → expected No, got '  spec_d16n.data{2,5}]);
fprintf(' PASS\n'); passCount = passCount + 1;

%% T17: excel_write_detail — matlab_mentioned conversion ("1"/"true" -> Yes, "0" -> '')
fprintf('[T17] excel_write_detail: matlab_mentioned 変換 ...');
T_d_ml = table(["T1";"T2";"T3"],["A1";"A2";"A3"],'VariableNames',["title","abstract"]);
T_d_ml.matlab_mentioned = ["1"; "0"; "true"];
T_d_ml.mentions_dataset = ["1"; "0"; "true"];
T_d_ml.repro_signal_score = [4; 0; 2];
spec_d17 = excel_write_detail(T_d_ml, struct());
% mentions_dataset is column 28, repro_signal_score is 32, matlab_mentioned is 33
assert(strcmp(spec_d17.data{1,28}, 'Yes'), ['T17 dataset "1" → expected Yes, got '  spec_d17.data{1,28}]);
assert(spec_d17.data{1,32} == 4,           'T17 repro_signal_score row1');
assert(strcmp(spec_d17.data{1,33}, 'Yes'), ['T17 "1" → expected Yes, got '  spec_d17.data{1,33}]);
assert(strcmp(spec_d17.data{2,33}, ''),    ['T17 "0" → expected "", got '  spec_d17.data{2,33}]);
assert(strcmp(spec_d17.data{3,33}, 'Yes'), ['T17 "true" → expected Yes, got ' spec_d17.data{3,33}]);
fprintf(' PASS\n'); passCount = passCount + 1;

%% T14: Data containing Japanese characters is written to xlsx (file generated, non-zero-byte)
fprintf('[T14] 日本語データ → xlsx 出力 ...');
T_jp = table( ...
    ["MATLAB入門"; "深層学習の基礎"], ...
    ["MATLABは行列計算に適した言語です。"; "ニューラルネットワークの理論を解説する。"], ...
    [2023; 2024], ...
    [10; 5], ...
    'VariableNames', ["title","abstract","publication_year","cited_by_count"]);
xlsxPath_jp = fullfile(tmpDir, 'test_jp.xlsx');
cfg_jp = struct('query','MATLAB','from_date','2023-01-01', ...
    'to_date','2024-12-31','run_id','smoke_jp');
export_excel_workbook(write_jsonl_to_tmp(T_jp, tmpDir), xlsxPath_jp, cfg_jp);
assert(isfile(xlsxPath_jp), 'T14: 日本語テーブルで xlsx が生成されない');
info14 = dir(xlsxPath_jp);
assert(info14.bytes > 1024, 'T14: 日本語テーブルの xlsx が 1KB 未満');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T15: create_run_context — Verify search_results_* fields exist
fprintf('[T15] create_run_context: search_results_* フィールド ...');
testRunsDir = fullfile(tmpDir, 'test_runs');
ctx = create_run_context(testRunsDir);
assert(isfield(ctx, 'search_results_xlsx'),  'T15: search_results_xlsx フィールドがない');
assert(isfield(ctx, 'search_results_jsonl'), 'T15: search_results_jsonl フィールドがない');
assert(isfield(ctx, 'search_results_csv'),   'T15: search_results_csv フィールドがない');
assert(endsWith(ctx.search_results_xlsx, 'search_results.xlsx'), ...
    'T15: search_results_xlsx のパス末尾が search_results.xlsx でない');
assert(endsWith(ctx.search_results_jsonl, 'search_results.jsonl'), ...
    'T15: search_results_jsonl のパス末尾が search_results.jsonl でない');
assert(endsWith(ctx.search_results_csv, 'search_results.csv'), ...
    'T15: search_results_csv のパス末尾が search_results.csv でない');
% Must be placed directly under run_dir (not intermediate/, etc.)
[parentXlsx, ~, ~] = fileparts(ctx.search_results_xlsx);
assert(strcmp(parentXlsx, ctx.run_dir), ...
    'T15: search_results_xlsx は run_dir 直下でなければならない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T18: excel_a1_range — column labels beyond Z
fprintf('[T18] excel_a1_range: A1 記法変換 ...');
assert(excel_a1_range(1, 1) == "A1", 'T18: 1 -> A1 でない');
assert(excel_a1_range(1, 26) == "Z1", 'T18: 26 -> Z1 でない');
assert(excel_a1_range(1, 27) == "AA1", 'T18: 27 -> AA1 でない');
assert(excel_a1_range(1, 52) == "AZ1", 'T18: 52 -> AZ1 でない');
assert(excel_a1_range(1, 53) == "BA1", 'T18: 53 -> BA1 でない');
assert(excel_a1_range(1, 702) == "ZZ1", 'T18: 702 -> ZZ1 でない');
assert(excel_a1_range(1, 703) == "AAA1", 'T18: 703 -> AAA1 でない');
assert(excel_a1_range(2, 1, 3, 2) == "A2:B3", 'T18: range 変換が不正');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T19: COM mode regression — use COM when available and preserve Japanese text
fprintf('[T19] COM 経路の回帰確認 ...');
if excel_check_com_available()
    hookPath = fullfile(tmpDir, 'write_mode.txt');
    xlsxPath_com = fullfile(tmpDir, 'test_jp_com.xlsx');
    cfg_com = cfg_jp;
    cfg_com.testHookWriteModePath = hookPath;
    export_excel_workbook(write_jsonl_to_tmp(T_jp, tmpDir), xlsxPath_com, cfg_com);
    assert(isfile(hookPath), 'T19: write mode hook が生成されていない');
    modeText = strtrim(string(fileread(hookPath)));
    assert(modeText == "com", 'T19: write mode=%s (expected com)', modeText);
    [titleCell, abstractCell] = local_read_excel_cells_via_com(xlsxPath_com, 'Overview', 'A2', 'K2');
    assert(titleCell == "MATLAB入門", 'T19: Japanese title readback failed → %s', titleCell);
    assert(contains(abstractCell, "行列計算に適した言語"), 'T19: Japanese abstract readback failed → %s', abstractCell);
    fprintf(' PASS\n');
    passCount = passCount + 1;
else
    fprintf(' SKIP (COM unavailable)\n');
end

fprintf('\n=== test_excel_export_smoke: %d PASSED (18 mandatory + T19 optional) ===\n', passCount);
assert(passCount >= 18, sprintf('FAILED: mandatory tests did not pass (passCount=%d)', passCount));
end

% ─── Local helpers ────────────────────────────────────────────────

function T = local_make_test_table()
% Standard sample table for testing (3 rows)
T = table( ...
    ["w0001"; "w0002"; "w0003"], ...
    ["Neural Network Study"; "Open Access Review"; "Topology Methods"], ...
    ["We analyze neural nets."; "We review OA mandates."; "We apply topology."], ...
    ["10.1000/abc001"; "10.1000/abc002"; ""], ...
    [2023; 2024; 2025], ...
    [15; 5; 0], ...
    [2.1; 1.3; NaN], ...
    [0.91; 0.42; NaN], ...
    [3; 1; 0], ...
    'VariableNames', ["openalex_id","title","abstract","doi", ...
                     "publication_year","cited_by_count","fwci","citation_percentile","repro_signal_score"]);
end

function T = local_make_year_table()
% Table for annual aggregation test (2023x2, 2024x3, 2025x1)
years = [2023; 2023; 2024; 2024; 2024; 2025];
cited = [10; 20; 5; 15; 25; 8];
oaVals = [true; false; true; true; false; true];
T = table( ...
    repmat("Title", 6, 1), ...
    repmat("Abstract", 6, 1), ...
    years, cited, oaVals, ...
    'VariableNames', ["title","abstract","publication_year","cited_by_count","is_oa"]);
end

function cfg = local_make_cfg()
cfg = struct( ...
    'query',      'neural networks', ...
    'from_date',  '2023-01-01', ...
    'to_date',    '2025-12-31', ...
    'filter',     'is_oa:true,language:en', ...
    'run_id',     'smoke_test_20260330', ...
    'run_dir',    'result/runs/smoke_test', ...
    'rows_fetched', int32(3), ...
    'total_hits',   int32(42), ...
    'created_at', '2026-03-30T00:00:00');
end

function p = write_jsonl_to_tmp(T, tmpDir)
p = fullfile(tmpDir, 'test_jp.jsonl');
write_jsonl(T, p);
end

function [titleCell, abstractCell] = local_read_excel_cells_via_com(xlsxPath, sheetName, titleRef, abstractRef)
excel = actxserver('Excel.Application');
excel.Visible = false;
excel.DisplayAlerts = false;
wb = [];
try
    wb = excel.Workbooks.Open(char(string(xlsxPath)));
    ws = wb.Worksheets.Item(char(sheetName));
    titleCell = string(ws.Range(titleRef).Value);
    abstractCell = string(ws.Range(abstractRef).Value);
    wb.Close(false);
catch ex
    if ~isempty(wb)
        try; wb.Close(false); catch; end %#ok<TRYNC>
    end
    excel.Quit;
    excel.delete;
    rethrow(ex);
end
excel.Quit;
excel.delete;
end
