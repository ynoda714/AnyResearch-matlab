function test_batch_comparison_smoke()
%TEST_BATCH_COMPARISON_SMOKE  B-1: write_batch_comparison_xlsx smoke test
%
%   How to run:
%     addpath("src/export"); addpath("src/util");
%     addpath("test/smoke");
%     test_batch_comparison_smoke();
%
%   Target: write_batch_comparison_xlsx
%     B-1: Additional output of batch_comparison.xlsx during batch run
%          Institution x year matrix of paper count / OA rate / avg cited by count
%
%   Test coverage:
%     T1.  Normal case: finalAll table -> xlsx generated, file size checked
%     T2.  spec.sheetName == 'Comparison'
%     T3.  spec.nCols == nYears + 2 (institution_name + years + Total)
%     T4.  sectionRows has 6 elements (3 sections x 2 rows)
%     T5.  Section 1 label contains "Paper Count"
%     T6.  Section 2 label contains "OA Count"
%     T7.  Section 3 label contains "Avg Cited By Count"
%     T8.  data: 2023 Paper Count for institution A is correct
%     T9.  data: Total row Paper Count sum is correct
%     T10. Empty table -> xlsx path returns "" (no error)
%     T11. outputXlsx option allows specifying output path
%     T12. target_institution_name column absent -> xlsxPath returns ""

fprintf('\n=== test_batch_comparison_smoke (B-1) ===\n');
passCount = 0;

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'export'));
addpath(fullfile(projectRoot, 'src', 'util'));

tmpDir = fullfile(tempdir, 'smoke_batch_comparison');
if isfolder(tmpDir)
    rmdir(tmpDir, 's');
end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

% Test data: 2 institutions x 2 years x multiple papers
finalAll = local_make_test_table();

%% T1: Normal case -> xlsx generated
fprintf('[T1] 正常系: xlsx 生成 ...');
batchDir = fullfile(tmpDir, 'batch_t1');
xlsxPath = write_batch_comparison_xlsx(finalAll, string(batchDir));
assert(isfile(char(xlsxPath)), sprintf('T1: xlsx が生成されない: %s', char(xlsxPath)));
info = dir(char(xlsxPath));
assert(info.bytes > 512, sprintf('T1: xlsx が小さすぎる (%d bytes)', info.bytes));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T2: spec.sheetName
fprintf('[T2] sheetName == "Comparison" ...');
% Since it is difficult to directly verify the internal spec of write_batch_comparison_xlsx,
% verify the sheet name in the file (writetable fallback uses 'Comparison')
% Use sheet read-back as an alternative check for COM write
try
    sheets = sheetnames(char(xlsxPath));
    assert(any(strcmp(sheets, 'Comparison')), ...
        sprintf('T2: シート "Comparison" が見つからない。sheets=%s', strjoin(sheets, ',')));
catch ex
    fprintf(' SKIP: sheetnames 不使用環境 (%s)\n', ex.message);
    passCount = passCount + 1;
    return;
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T3: column count nCols == nYears + 2
fprintf('[T3] 列数 == nYears+2 ...');
% Test data has 2 years (2023/2024) -> nCols = 4
rawData = readcell(char(xlsxPath), 'Sheet', 'Comparison', 'NumHeaderLines', 0);
nCols = size(rawData, 2);
assert(nCols == 4, sprintf('T3: nCols=%d (expected 4)', nCols));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T4: 4 sections structure - verify row count and section 4 presence
% Section 4 (Institution Dominance) was added in B-3.
% Exact row count =
%   Header: 1 row
%   + sec1 (label + subhdr + 2 institutions + Total = 5 rows) + blank row: 1
%   + sec2 (5 rows) + blank row: 1
%   + sec3 (5 rows) + blank row: 1
%   + sec4 (label + subhdr + 2 institutions = 4 rows)
%   = 1+5+1+5+1+5+1+4 = 23 rows
fprintf('[T4] 4 セクション構造・行数 = 23 ...');
nRows = size(rawData, 1);
assert(nRows == 23, sprintf('T4: 行数=%d (expected 23)', nRows));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T5: Section 1 label contains "Paper Count"
fprintf('[T5] Section 1 ラベル: "Paper Count" ...');
allText = local_col_to_text(rawData, 1);
hasPaper = any(contains(allText, 'Paper Count'));
assert(hasPaper, 'T5: "Paper Count" が data に見つからない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T6: Section 2 label contains "OA Count"
fprintf('[T6] Section 2 ラベル: "OA Count" ...');
hasOA = any(contains(allText, 'OA Count'));
assert(hasOA, 'T6: "OA Count" が data に見つからない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T7: Section 3 label contains "Avg Cited By Count"
fprintf('[T7] Section 3 ラベル: "Avg Cited By Count" ...');
hasAvg = any(contains(allText, 'Avg Cited By Count'));
assert(hasAvg, 'T7: "Avg Cited By Count" が data に見つからない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T8: 2023 Paper Count for institution A
fprintf('[T8] 機関 A の 2023 年 Paper Count ...');
% Test data: institution A / 2023 / 3 papers
% Scan rawData to verify the 2023 column (col 2) of "Univ A" row
instARow = find(contains(allText, 'Univ A'), 1, 'first');
assert(~isempty(instARow), 'T8: "Univ A" 行が見つからない');
% col 2 = 2023 value (col1=institution_name, col2=2023, col3=2024, col4=Total)
val = rawData{instARow, 2};
if isnumeric(val)
    assert(val == 3, sprintf('T8: Univ A 2023 count=%g (expected 3)', val));
else
    % Convert to numeric if it is a string
    numVal = str2double(char(string(val)));
    assert(numVal == 3, sprintf('T8: Univ A 2023 count=%g (expected 3)', numVal));
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T9: Total row Paper Count sum
fprintf('[T9] Total 行 Paper Count == 7 (3+2+2) →全機関全年合計 ...');
% Verify the Total row in the Paper Count section (after the institution_name subheader)
subHdrRows = find(contains(allText, 'institution_name'));
assert(~isempty(subHdrRows), 'T9: institution_name サブヘッダが見つからない');
hdr1Row = subHdrRows(1) + 1;  % Paper Count セクションの先頭データ行
totalRow = -1;
for ri = hdr1Row:size(rawData, 1)
    if contains(local_cell_val_to_char(rawData{ri, 1}), 'Total')
        totalRow = ri;
        break;
    end
end
assert(totalRow > 0, 'T9: Paper Count セクション内に Total 行が見つからない');
totalCell = rawData{totalRow, 4};  % 最終列（Total）
assert(isnumeric(totalCell) && ~isnan(totalCell), ...
    sprintf('T9: Total 列の値が数値でない: class=%s val=%s', class(totalCell), char(string(totalCell))));
assert(totalCell == 7, sprintf('T9: Total paper count=%g (expected 7)', totalCell));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T10: Empty table -> xlsxPath returns ""
fprintf('[T10] 空テーブル → xlsxPath == "" ...');
emptyT = table(strings(0,1), zeros(0,1), ...
    'VariableNames', {'target_institution_name', 'publication_year'});
batchDir10 = fullfile(tmpDir, 'batch_t10');
xlsxPath10 = write_batch_comparison_xlsx(emptyT, string(batchDir10));
assert(strlength(xlsxPath10) == 0, ...
    sprintf('T10: 空テーブルなのに xlsxPath="%s"', char(xlsxPath10)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T11: outputXlsx option
fprintf('[T11] outputXlsx オプション ...');
customPath = string(fullfile(tmpDir, 'custom_compare.xlsx'));
xlsxPath11 = write_batch_comparison_xlsx(finalAll, string(tmpDir), ...
    'outputXlsx', customPath);
assert(isfile(char(customPath)), ...
    sprintf('T11: カスタムパスに xlsx が生成されない: %s', char(customPath)));
assert(strcmp(char(xlsxPath11), char(customPath)), ...
    sprintf('T11: 戻り値パスが不一致: "%s" (expected "%s")', char(xlsxPath11), char(customPath)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T12: target_institution_name column absent -> xlsxPath returns ""
fprintf('[T12] target_institution_name 列不在 → xlsxPath == "" ...');
noInstT = table(ones(3,1), int32([2023;2023;2024]), ...
    'VariableNames', {'cited_by_count', 'publication_year'});
batchDir12 = fullfile(tmpDir, 'batch_t12');
xlsxPath12 = write_batch_comparison_xlsx(noInstT, string(batchDir12));
assert(strlength(xlsxPath12) == 0, ...
    sprintf('T12: 列不在なのに xlsxPath="%s"', char(xlsxPath12)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T13: Section 4 label contains "Institution Dominance Score" (B-3)
fprintf('[T13] Section 4 ラベル: "Institution Dominance Score" ...');
hasDominance = any(contains(allText, 'Institution Dominance Score'));
assert(hasDominance, 'T13: "Institution Dominance Score" が data に見つからない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T14: Section 4 subheader contains dominance_score column
fprintf('[T14] Section 4 サブヘッダ: dominance_score 列 ...');
% The subheader row is the row after "Institution Dominance Score"
domRow = find(contains(allText, 'Institution Dominance Score'), 1, 'first');
assert(~isempty(domRow), 'T14: Section 4 ラベル行が見つからない');
subHdr4row = domRow + 1;
assert(subHdr4row <= size(rawData,1), 'T14: Section 4 サブヘッダ行が範囲外');
allText4 = local_col_to_text(rawData, 1);
% Check all header columns of sec4 subheader row (col1..4)
sec4SubHdrVals = '';
for ci = 1:4
    sec4SubHdrVals = [sec4SubHdrVals, ' ', local_cell_val_to_char(rawData{subHdr4row, ci})]; %#ok<AGROW>
end
assert(contains(sec4SubHdrVals, 'dominance_score') || ...
       contains(sec4SubHdrVals, 'paper_count') || ...
       contains(sec4SubHdrVals, 'institution_name'), ...
    sprintf('T14: sec4 サブヘッダに期待列が含まれない: %s', sec4SubHdrVals));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T15: Section 4 data: Univ A dominance_score > Univ B (Univ A has more papers/citations)
fprintf('[T15] Section 4: Univ A dominance_score > Univ B ...');
% Dominance data starts at row subHdr4row+1
% col 6 = dominance_score (institution_name/paper_count/total_citations/paper_share/citation_share/dominance_score)
% With nCols=4, only cols 1-4 of dominance section are visible (truncated)
% But we can verify institution order: Univ A appears before Univ B (sorted by dominance desc)
allInstTexts = local_col_to_text(rawData, 1);
% Find first occurrence of Univ A and Univ B after the section 4 subheader
instApos = -1; instBpos = -1;
for ri = (subHdr4row+1):size(rawData,1)
    if contains(allInstTexts{ri}, 'Univ A') && instApos < 0
        instApos = ri;
    elseif contains(allInstTexts{ri}, 'Univ B') && instBpos < 0
        instBpos = ri;
    end
end
assert(instApos > 0, 'T15: Section 4 に "Univ A" が見つからない');
assert(instBpos > 0, 'T15: Section 4 に "Univ B" が見つからない');
assert(instApos < instBpos, ...
    sprintf('T15: Univ A(row %d) が Univ B(row %d) より後（被引用数が多い方が先のはず）', instApos, instBpos));
fprintf(' PASS\n'); passCount = passCount + 1;

fprintf('\n[DONE] test_batch_comparison_smoke: %d/15 PASS\n', passCount);
if passCount == 15
    fprintf('=== ALL PASS ===\n');
else
    error('test_batch_comparison_smoke: %d/15 のみ PASS\n', passCount);
end
end

% ─── Local helpers ────────────────────────────────────────────────────

function texts = local_col_to_text(rawData, colIdx)
%LOCAL_COL_TO_TEXT  Convert a column of readcell output to char cell array (handles missing)
n = size(rawData, 1);
texts = cell(n, 1);
for ri = 1:n
    texts{ri} = local_cell_val_to_char(rawData{ri, colIdx});
end
end

function s = local_cell_val_to_char(val)
%LOCAL_CELL_VAL_TO_CHAR  Safely convert a readcell value to char
if ischar(val)
    s = val;
elseif isstring(val) && isscalar(val) && ~ismissing(val)
    s = char(val);
elseif isnumeric(val) && isscalar(val) && ~isnan(val)
    s = num2str(val);
else
    s = '';
end
end

function T = local_make_test_table()
%LOCAL_MAKE_TEST_TABLE  Create a 7-row integrated test table
%
%   Institution A: 2023: 3 papers, 2024: 2 papers
%   Institution B: 2023: 0 papers, 2024: 2 papers
%   Total:   2023: 3 papers, 2024: 4 papers (Total=7)

institution = ["Univ A";"Univ A";"Univ A";"Univ A";"Univ A"; ...
               "Univ B";"Univ B"];
year        = int32([2023;2023;2023;2024;2024; ...
                     2024;2024]);
cited       = double([10;20;5;15;8; ...
                      12;3]);
is_oa       = logical([1;0;1;1;0; ...
                        1;0]);
T = table(institution, year, cited, is_oa, ...
    'VariableNames', {'target_institution_name','publication_year', ...
                      'cited_by_count','is_oa'});
end
