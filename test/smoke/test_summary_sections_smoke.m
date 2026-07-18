function test_summary_sections_smoke()
%TEST_SUMMARY_SECTIONS_SMOKE  Summary sheet 4-section structure smoke test (B-1/B-2 updated)
%
%   How to run:
%     addpath("src/export"); addpath("src/util"); addpath("src/analytics");
%     addpath("test/smoke");
%     test_summary_sections_smoke();
%
%   Target: excel_write_summary (4-section structure after B-1/B-2)
%     Section 1 — Annual Statistics (year/paper_count/…/avg_citation_velocity/growth_rate_pct)
%     Section 2 — Top N Papers by Citations
%     Section 3 — Top N Journals by Paper Count
%     Section 4 — Top N Papers by Citation Velocity (B-2)
%
%   Test coverage:
%     T1.  nCols == 8 (analytics columns added in B-1)
%     T2.  sectionRows field exists and has 6 elements (3 sections x label+subhdr pair)
%     T3.  sectionRows relative positions (label -> subheader adjacent; sec3 after sec2)
%     T4.  Section 2 label contains "Papers by Citations"
%     T5.  Section 2 subheader (rank/title/doi/publication_year/cited_by_count/citation_velocity/source_name)
%     T6.  Section 2 data: rank=1 has the highest cited_by_count
%     T7.  Section 2 DOI column is plain text (hyperlinks are empty)
%     T8.  Section 3 label contains "Journals by Paper Count"
%     T9.  Section 3 subheader (rank/source_name/paper_count/avg_cited_by_count/oa_count)
%     T10. Section 3 data: rank=1 is the journal with highest paper_count
%     T11. cfg.top_n=3 -> sec2/sec3 data row count is at most 3
%     T12. topN > actual row count -> capped at min(data_rows, topN)
%     T13. cited_by_count column absent -> message row in sec2
%     T14. source_name column absent -> message row in sec3
%     T15. Section 1 Annual Statistics is always at the top (sec1 rows precede sec2 label)

fprintf('\n=== test_summary_sections_smoke (B-1 / B-2) ===\n');
passCount = 0;

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'export'));
addpath(fullfile(projectRoot, 'src', 'util'));
addpath(fullfile(projectRoot, 'src', 'analytics'));

T = local_make_full_table();

%% T1: nCols == 8 (analytics: avg_citation_velocity + growth_rate_pct added in B-1)
fprintf('[T1] nCols == 8 ...');
spec = excel_write_summary(T, struct());
assert(spec.nCols == 8, sprintf('T1: nCols=%d (expected 8)', spec.nCols));
assert(numel(spec.headers) == 8, ...
    sprintf('T1: numel(headers)=%d (expected 8)', numel(spec.headers)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T2: sectionRows field exists and has 6 elements (sec2/sec3/sec4 x label+subhdr)
fprintf('[T2] sectionRows 存在 + 6要素 ...');
assert(isfield(spec, 'sectionRows'), 'T2: sectionRows フィールドがない');
assert(numel(spec.sectionRows) == 6, ...
    sprintf('T2: numel(sectionRows)=%d (expected 6)', numel(spec.sectionRows)));
for si = 1:6
    assert(spec.sectionRows(si) > 0, sprintf('T2: sectionRows(%d) <= 0', si));
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T3: sectionRows relative positions (label->subheader adjacent, sec3 after sec2)
fprintf('[T3] sectionRows 相対位置 ...');
sr = spec.sectionRows;
% sec2 subheader = sec2 label + 1
assert(sr(2) == sr(1) + 1, ...
    sprintf('T3: sec2SubHdrRow(%d) != sec2LabelRow(%d)+1', sr(2), sr(1)));
% sec3 label is further after sec2 subheader
assert(sr(3) > sr(2) + 1, ...
    sprintf('T3: sec3LabelRow(%d) is not > sec2SubHdrRow(%d)+1', sr(3), sr(2)));
% sec3 subheader = sec3 label + 1
assert(sr(4) == sr(3) + 1, ...
    sprintf('T3: sec3SubHdrRow(%d) != sec3LabelRow(%d)+1', sr(4), sr(3)));
% sec4 label is further after sec3 subheader
assert(sr(5) > sr(4) + 1, ...
    sprintf('T3: sec4LabelRow(%d) is not > sec3SubHdrRow(%d)+1', sr(5), sr(4)));
% sec4 subheader = sec4 label + 1
assert(sr(6) == sr(5) + 1, ...
    sprintf('T3: sec4SubHdrRow(%d) != sec4LabelRow(%d)+1', sr(6), sr(5)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T4: Section 2 label contains "Papers by Citations"
% sectionRows are fullData row numbers (header is row 1 of fullData)
% data index = fullData row - 1
fprintf('[T4] Section 2 ラベルテキスト ...');
sec2LabelDataIdx = sr(1) - 1;
labelText = char(string(spec.data{sec2LabelDataIdx, 1}));
assert(contains(labelText, 'Papers by Citations'), ...
    sprintf('T4: sec2Label="%s" に "Papers by Citations" が含まれない', labelText));
assert(contains(labelText, '10'), ...
    sprintf('T4: sec2Label="%s" に topN(10) が含まれない', labelText));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T5: Section 2 subheader columns (B-1 adds citation_velocity between cited_by_count and source_name)
fprintf('[T5] Section 2 サブヘッダ ...');
sec2SubHdrDataIdx = sr(2) - 1;
subHdr2 = spec.data(sec2SubHdrDataIdx, :);
expSub2 = {'rank','title','doi','publication_year','cited_by_count','citation_velocity','source_name',''};
for ci = 1:8
    assert(strcmp(char(string(subHdr2{ci})), expSub2{ci}), ...
        sprintf('T5: sec2SubHdr{%d}="%s" (expected "%s")', ci, char(string(subHdr2{ci})), expSub2{ci}));
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T6: Section 2 data: rank=1 has the highest cited_by_count (col 5)
fprintf('[T6] Section 2 rank順 ...');
% sec2 data row 1: fullData row = sr(2)+1 -> data index = sr(2)+1-1 = sr(2)
sec2DataIdx1 = sr(2);
dataRow1 = spec.data(sec2DataIdx1, :);
rank1Cited = double(dataRow1{5});
assert(dataRow1{1} == 1, ...
    sprintf('T6: rank1 の rank 列=%d (expected 1)', dataRow1{1}));
% T has cited_by_count: 50,30,80,10,60 -> max=80
assert(rank1Cited == 80, ...
    sprintf('T6: rank1 cited_by_count=%d (expected 80)', rank1Cited));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T7: hyperlinks are empty (Summary sheet has no DOI hyperlinks)
fprintf('[T7] hyperlinks は空 ...');
assert(isempty(spec.hyperlinks), ...
    sprintf('T7: hyperlinks に %d 件の要素がある（expected 0）', numel(spec.hyperlinks)));
doiVal = spec.data{sec2DataIdx1, 3};
assert(ischar(doiVal) || isstring(doiVal), 'T7: DOI 列が文字列型でない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T8: Section 3 label contains "Journals by Paper Count"
fprintf('[T8] Section 3 ラベルテキスト ...');
sec3LabelDataIdx = sr(3) - 1;
label3 = char(string(spec.data{sec3LabelDataIdx, 1}));
assert(contains(label3, 'Journals by Paper Count'), ...
    sprintf('T8: sec3Label="%s" に "Journals by Paper Count" が含まれない', label3));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T9: Section 3 subheader (rank/source_name/paper_count/avg_cited_by_count/oa_count/…)
fprintf('[T9] Section 3 サブヘッダ ...');
sec3SubHdrDataIdx = sr(4) - 1;
subHdr3 = spec.data(sec3SubHdrDataIdx, :);
expSub3_5 = {'rank','source_name','paper_count','avg_cited_by_count','oa_count'};
for ci = 1:5
    assert(strcmp(char(string(subHdr3{ci})), expSub3_5{ci}), ...
        sprintf('T9: sec3SubHdr{%d}="%s" (expected "%s")', ci, char(string(subHdr3{ci})), expSub3_5{ci}));
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T10: Section 3 data: rank=1 is the journal with highest paper_count
fprintf('[T10] Section 3 rank順 ...');
% sec3 data row 1: fullData row = sr(4)+1 -> data index = sr(4)
sec3DataIdx1 = sr(4);
sec3DataRow1 = spec.data(sec3DataIdx1, :);
assert(sec3DataRow1{1} == 1, ...
    sprintf('T10: rank1 の rank 列=%d (expected 1)', sec3DataRow1{1}));
srcName1  = char(string(sec3DataRow1{2}));
paperCnt1 = double(sec3DataRow1{3});
assert(paperCnt1 == 2, ...
    sprintf('T10: rank1 paper_count=%d (expected 2)', paperCnt1));
assert(strcmp(srcName1, 'Science') || strcmp(srcName1, 'Nature'), ...
    sprintf('T10: rank1 source_name="%s" (expected "Science" or "Nature")', srcName1));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T11: cfg.top_n=3 -> sec2/sec3 data row count == 3
fprintf('[T11] cfg.top_n=3 のキャップ ...');
spec3 = excel_write_summary(T, struct('top_n', 3));
sr3 = spec3.sectionRows;
% sec2 data rows: fullData rows sr3(2)+1 .. sr3(3)-2 (blank before sec3 label)
% count = (sr3(3) - 2) - sr3(2)
sec2DataRows = (sr3(3) - 2) - sr3(2);
sec2LabelText = char(string(spec3.data{sr3(1)-1, 1}));
assert(contains(sec2LabelText, '3'), ...
    sprintf('T11: sec2Label="%s" に "3" が含まれない', sec2LabelText));
assert(sec2DataRows == 3, ...
    sprintf('T11: sec2 データ行数=%d (expected 3)', sec2DataRows));
% sec3 data rows: fullData rows sr3(4)+1 .. sr3(5)-2
sec3DataRows = (sr3(5) - 2) - sr3(4);
assert(sec3DataRows == 3, ...
    sprintf('T11: sec3 データ行数=%d (expected 3)', sec3DataRows));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T12: topN > actual row count -> capped at min(data_rows, topN)
fprintf('[T12] topN > 実データ行数 → キャップ ...');
spec100 = excel_write_summary(T, struct('top_n', 100));
sr100 = spec100.sectionRows;
sec2Rows100 = (sr100(3) - 2) - sr100(2);
assert(sec2Rows100 == height(T), ...
    sprintf('T12: sec2 データ行数=%d (expected %d)', sec2Rows100, height(T)));
sec3Rows100 = (sr100(5) - 2) - sr100(4);
assert(sec3Rows100 == 3, ...
    sprintf('T12: sec3 データ行数=%d (expected 3; 3 unique journals)', sec3Rows100));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T13: cited_by_count column absent -> message row in sec2
fprintf('[T13] cited_by_count 列不在 → sec2 メッセージ ...');
T_nocite = local_make_table_no_cited();
spec_nc = excel_write_summary(T_nocite, struct());
sr_nc = spec_nc.sectionRows;
% sec2 data row 1 is at fullData row sr_nc(2)+1 -> data index = sr_nc(2)
val_nc = char(string(spec_nc.data{sr_nc(2), 1}));
assert(contains(val_nc, 'cited_by_count') || contains(val_nc, 'no'), ...
    sprintf('T13: sec2 先頭行="%s"（メッセージ期待）', val_nc));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T14: source_name column absent -> message row in sec3
fprintf('[T14] source_name 列不在 → sec3 メッセージ ...');
T_nosrc = local_make_table_no_source();
spec_ns = excel_write_summary(T_nosrc, struct());
sr_ns = spec_ns.sectionRows;
% sec3 data row 1 at data index = sr_ns(4)
val_ns = char(string(spec_ns.data{sr_ns(4), 1}));
assert(contains(val_ns, 'source_name') || contains(val_ns, 'no'), ...
    sprintf('T14: sec3 先頭行="%s"（メッセージ期待）', val_ns));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T15: Section 1 Annual Statistics is always at the top
fprintf('[T15] Section 1 先頭確認 ...');
sec1FirstVal = spec.data{1, 1};
assert(isnumeric(sec1FirstVal) || ischar(sec1FirstVal) || isstring(sec1FirstVal), ...
    'T15: data{1,1} の型が不正');
% sec2 label is at data idx sr(1)-1
% blank row is at data idx sr(1)-2
% sec1 Total row is at data idx sr(1)-3
sec2LabelDataIdx2 = sr(1) - 1;
assert(sec2LabelDataIdx2 >= 4, ...
    sprintf('T15: sec1 データ行が少なすぎる (sec2LabelDataIdx=%d)', sec2LabelDataIdx2));
% data{sr(1)-2, 1} is the blank row before sec2 label
blankRowVal = char(string(spec.data{sr(1) - 2, 1}));
assert(isempty(strtrim(blankRowVal)), ...
    sprintf('T15: sec2ラベル前の空行="%s" (空のはず)', blankRowVal));
% data{sr(1)-3, 1} is the Total row of sec1
totalRowVal = char(string(spec.data{sr(1) - 3, 1}));
assert(strcmp(totalRowVal, 'Total'), ...
    sprintf('T15: sec1 Total 行="%s" (Total のはず)', totalRowVal));
fprintf(' PASS\n'); passCount = passCount + 1;

fprintf('\n=== test_summary_sections_smoke: %d/15 PASSED ===\n', passCount);
assert(passCount == 15, sprintf('FAILED: %d/15 テストが失敗しました', 15 - passCount));
end

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
% Local helpers
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function T = local_make_full_table()
% Full-column table with 5 rows
% source_name: Science=2, Nature=2, PLOS One=1
% cited_by_count: 80(C), 60(E), 50(A), 30(B), 10(D) -> rank order: C,E,A,B,D
T = table( ...
    ["W001";"W002";"W003";"W004";"W005"], ...
    ["Title A";"Title B";"Title C";"Title D";"Title E"], ...
    ["10.1/aaa";"10.1/bbb";"10.1/ccc";"10.1/ddd";"10.1/eee"], ...
    [2023;2024;2023;2024;2024], ...
    [50;30;80;10;60], ...
    [true;false;true;true;false], ...
    ["Science";"Nature";"Science";"PLOS One";"Nature"], ...
    'VariableNames', ["openalex_id","title","doi", ...
                      "publication_year","cited_by_count","is_oa","source_name"]);
end

function T = local_make_table_no_cited()
% No cited_by_count column
T = table( ...
    ["T1";"T2";"T3"], ...
    ["Abs1";"Abs2";"Abs3"], ...
    [2023;2024;2023], ...
    'VariableNames', ["title","abstract","publication_year"]);
end

function T = local_make_table_no_source()
% No source_name column (cited_by_count present)
T = table( ...
    ["T1";"T2";"T3"], ...
    [10;20;5], ...
    [2023;2024;2023], ...
    'VariableNames', ["title","cited_by_count","publication_year"]);
end
