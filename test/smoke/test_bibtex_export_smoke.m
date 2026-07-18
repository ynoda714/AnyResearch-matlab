function test_bibtex_export_smoke()
%TEST_BIBTEX_EXPORT_SMOKE  O-1: export_bibtex smoke test
%
%   How to run:
%     addpath("src/export"); addpath("src/util");
%     addpath("test/smoke");
%     test_bibtex_export_smoke();
%
% Target: export_bibtex (src/export/)
%     O-1: search_results.jsonl -> generate BibTeX (.bib) and RIS (.ris)
%
%   Test coverage:
%     T1.  Normal case: JSONL input -> .bib and .ris generated simultaneously
%     T2.  result.rows_written is greater than 0
%     T3.  .bib content: @article{ entry count == input row count
%     T4.  .bib content: title / journal / year / doi fields exist
%     T5.  .bib key: composed of author last name + year + first word of title
%     T6.  .bib key: if duplicate, add a/b/c suffix at the end
%     T7.  .ris content: TY - JOUR appears input-row-count times
%     T8.  .ris content: TI (title) / PY (year) / DO (DOI) fields
%     T9.  conference-paper → @inproceedings / CONF
%     T10. book-chapter → @incollection / CHAP
%     T11. enableBibtex=false -> .bib is not generated
%     T12. enableRis=false   -> .ris is not generated
%     T13. Empty input -> rows_written==0, file not generated
%     T14. Also works with CSV input (equivalent output to JSONL)

fprintf('\n=== test_bibtex_export_smoke (O-1) ===\n');
passCount = 0;

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'export'));
addpath(fullfile(projectRoot, 'src', 'util'));

tmpDir = fullfile(tempdir, 'smoke_bibtex');
if isfolder(tmpDir)
    rmdir(tmpDir, 's');
end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

% Create test data
T = local_make_test_table();
jsonlPath = fullfile(tmpDir, 'input.jsonl');
write_jsonl(T, jsonlPath);

%% T1: Normal case -> .bib and .ris are generated
fprintf('[T1] 正常系: .bib と .ris 生成 ...');
outDir1 = fullfile(tmpDir, 't1');
result1 = export_bibtex(string(jsonlPath), string(outDir1));
assert(isfile(char(result1.bib_path)), ...
    sprintf('T1: .bib が生成されない: %s', char(result1.bib_path)));
assert(isfile(char(result1.ris_path)), ...
    sprintf('T1: .ris が生成されない: %s', char(result1.ris_path)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T2: rows_written > 0
fprintf('[T2] rows_written > 0 ...');
assert(result1.rows_written > 0, ...
    sprintf('T2: rows_written=%d (expected >0)', result1.rows_written));
assert(result1.rows_written == height(T), ...
    sprintf('T2: rows_written=%d (expected %d)', result1.rows_written, height(T)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T3: .bib entry count == input row count
fprintf('[T3] .bib エントリ数 == 入力行数 ...');
bibText = local_read_text(result1.bib_path);
entryCount = numel(regexp(bibText, '@[a-z]+\{', 'match'));
assert(entryCount == height(T), ...
    sprintf('T3: BibTeX エントリ数=%d (expected %d)', entryCount, height(T)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T4: .bib content: title / year / doi fields
fprintf('[T4] .bib: title / year / doi フィールド確認 ...');
assert(contains(bibText, '  title   ='), ...
    'T4: title フィールドが見つからない');
assert(contains(bibText, '  year    ='), ...
    'T4: year フィールドが見つからない');
assert(contains(bibText, '  doi     ='), ...
    'T4: doi フィールドが見つからない');
% article/review type also requires the journal field
assert(contains(bibText, '  journal ='), ...
    'T4: journal フィールドが見つからない（article タイプ）');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T5: .bib key format (author last name + year + first word of title)
fprintf('[T5] .bib キー形式 ...');
% Row 1 of T: first_author_name="Smith, John", year=2023, title="Deep Learning ..."
% -> expected key "smith2023deep"
keyPattern = '@article\{(\w+),';
keys = regexp(bibText, keyPattern, 'tokens');
assert(~isempty(keys), 'T5: BibTeX キーが見つからない');
firstKey = lower(char(keys{1}{1}));
assert(contains(firstKey, 'smith'), ...
    sprintf('T5: キー "%s" に "smith" が含まれない', firstKey));
assert(contains(firstKey, '2023'), ...
    sprintf('T5: キー "%s" に "2023" が含まれない', firstKey));
% title = "Deep Learning for Climate" -> first non-stopword: 'deep' (4 chars, not a stopword)
% Verify key is in "smith2023deep" format
assert(contains(firstKey, 'deep') || contains(firstKey, 'learning') || contains(firstKey, 'climate'), ...
    sprintf('T5: キー "%s" にタイトル由来の語 (deep/learning/climate) がない', firstKey));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T6: .bib key duplicate -> a/b/c suffix
fprintf('[T6] .bib キー重複 → サフィックス ...');
% Duplicates occur when same author, same year, and similar title
% Add intentionally duplicate-prone entries to test data
T_dup = local_make_dup_table();
jsonlDup = fullfile(tmpDir, 'dup.jsonl');
write_jsonl(T_dup, jsonlDup);
outDir6 = fullfile(tmpDir, 't6');
result6 = export_bibtex(string(jsonlDup), string(outDir6));
bibText6 = local_read_text(result6.bib_path);
keys6 = regexp(bibText6, '@\w+\{(\w+),', 'tokens');
keyStrs = cellfun(@(k) lower(char(k{1})), keys6, 'UniformOutput', false);
% All keys must be unique
assert(numel(keyStrs) == numel(unique(keyStrs)), ...
    sprintf('T6: 重複キーあり: %s', strjoin(keyStrs, ', ')));
% Same author x same year x similar title -> keys with a/b/c suffix should exist
% Pattern: 4 digits followed by letter+letter (suffix assigned e.g. kim2024studya, kim2024studyb)
hasSuffix = any(cellfun(@(k) ~isempty(regexp(k, '\d{4}[a-z]+[a-z]$', 'once')), keyStrs));
assert(hasSuffix, sprintf('T6: サフィックス付きキー（末尾 a/b/c）が見つからない。keys=%s', strjoin(keyStrs, ', ')));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T7: .ris entry count
fprintf('[T7] .ris TY ラインの数 == 入力行数 ...');
risText = local_read_text(result1.ris_path);
tyCount = numel(regexp(risText, 'TY  - ', 'match'));
assert(tyCount == height(T), ...
    sprintf('T7: RIS TY 行数=%d (expected %d)', tyCount, height(T)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T8: .ris: TI / PY / DO fields
fprintf('[T8] .ris: TI / PY / DO フィールド確認 ...');
assert(contains(risText, 'TI  - '), 'T8: TI フィールドなし');
assert(contains(risText, 'PY  - '), 'T8: PY フィールドなし');
assert(contains(risText, 'DO  - '), 'T8: DO フィールドなし');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T9: conference-paper → @inproceedings (BibTeX) / CONF (RIS)
fprintf('[T9] conference-paper → @inproceedings / CONF ...');
T_conf = local_make_typed_table('conference-paper');
jsonlConf = fullfile(tmpDir, 'conf.jsonl');
write_jsonl(T_conf, jsonlConf);
outDir9 = fullfile(tmpDir, 't9');
result9 = export_bibtex(string(jsonlConf), string(outDir9));
bibConf = local_read_text(result9.bib_path);
risConf = local_read_text(result9.ris_path);
assert(contains(bibConf, '@inproceedings{'), ...
    sprintf('T9: @inproceedings が見つからない。実際: %s', bibConf(1:min(200,end))));
assert(contains(risConf, 'TY  - CONF'), ...
    sprintf('T9: CONF が見つからない。実際: %s', risConf(1:min(200,end))));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T10: book-chapter → @incollection (BibTeX) / CHAP (RIS)
fprintf('[T10] book-chapter → @incollection / CHAP ...');
T_book = local_make_typed_table('book-chapter');
jsonlBook = fullfile(tmpDir, 'book.jsonl');
write_jsonl(T_book, jsonlBook);
outDir10 = fullfile(tmpDir, 't10');
result10 = export_bibtex(string(jsonlBook), string(outDir10));
bibBook = local_read_text(result10.bib_path);
risBook = local_read_text(result10.ris_path);
assert(contains(bibBook, '@incollection{'), ...
    sprintf('T10: @incollection が見つからない。実際: %s', bibBook(1:min(200,end))));
assert(contains(risBook, 'TY  - CHAP'), ...
    sprintf('T10: CHAP が見つからない。実際: %s', risBook(1:min(200,end))));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T11: enableBibtex=false -> .bib is not generated
fprintf('[T11] enableBibtex=false → .bib 非生成 ...');
outDir11 = fullfile(tmpDir, 't11');
result11 = export_bibtex(string(jsonlPath), string(outDir11), enableBibtex=false);
assert(strlength(result11.bib_path) == 0, ...
    sprintf('T11: bib_path="%s" (expected "")', char(result11.bib_path)));
assert(~isfile(fullfile(outDir11, 'search_results.bib')), ...
    'T11: .bib ファイルが存在している');
assert(isfile(char(result11.ris_path)), ...
    sprintf('T11: .ris が生成されない: %s', char(result11.ris_path)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T12: enableRis=false -> .ris is not generated
fprintf('[T12] enableRis=false → .ris 非生成 ...');
outDir12 = fullfile(tmpDir, 't12');
result12 = export_bibtex(string(jsonlPath), string(outDir12), enableRis=false);
assert(strlength(result12.ris_path) == 0, ...
    sprintf('T12: ris_path="%s" (expected "")', char(result12.ris_path)));
assert(~isfile(fullfile(outDir12, 'search_results.ris')), ...
    'T12: .ris ファイルが存在している');
assert(isfile(char(result12.bib_path)), ...
    sprintf('T12: .bib が生成されない: %s', char(result12.bib_path)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T13: Empty input -> rows_written==0, file not generated
fprintf('[T13] 空入力 → rows_written==0 ...');
emptyT = table( ...
    strings(0,1), strings(0,1), int32(zeros(0,1)), ...
    'VariableNames', {'title', 'doi', 'publication_year'});
emptyJsonl = fullfile(tmpDir, 'empty.jsonl');
write_jsonl(emptyT, emptyJsonl);
outDir13 = fullfile(tmpDir, 't13');
result13 = export_bibtex(string(emptyJsonl), string(outDir13));
assert(result13.rows_written == 0, ...
    sprintf('T13: rows_written=%d (expected 0)', result13.rows_written));
% With empty input, bib_path / ris_path are "" and files are not generated
assert(strlength(result13.bib_path) == 0, ...
    sprintf('T13: bib_path="%s" (expected "")', char(result13.bib_path)));
assert(strlength(result13.ris_path) == 0, ...
    sprintf('T13: ris_path="%s" (expected "")', char(result13.ris_path)));
assert(~isfile(fullfile(outDir13, 'search_results.bib')), ...
    'T13: rows=0 なのに search_results.bib が生成された');
assert(~isfile(fullfile(outDir13, 'search_results.ris')), ...
    'T13: rows=0 なのに search_results.ris が生成された');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T14: Also works with CSV input
fprintf('[T14] CSV 入力 ...');
csvPath = fullfile(tmpDir, 'input.csv');
writetable(T, csvPath, 'Encoding', 'UTF-8');
outDir14 = fullfile(tmpDir, 't14');
result14 = export_bibtex(string(csvPath), string(outDir14));
assert(isfile(char(result14.bib_path)), ...
    sprintf('T14: CSV 入力で .bib が生成されない: %s', char(result14.bib_path)));
assert(result14.rows_written == height(T), ...
    sprintf('T14: rows_written=%d (expected %d)', result14.rows_written, height(T)));
fprintf(' PASS\n'); passCount = passCount + 1;

fprintf('\n[DONE] test_bibtex_export_smoke: %d/14 PASS\n', passCount);
if passCount == 14
    fprintf('=== ALL PASS ===\n');
else
    error('test_bibtex_export_smoke: %d/14 のみ PASS\n', passCount);
end
end

% ─── Local helpers ────────────────────────────────────────────────────

function T = local_make_test_table()
%LOCAL_MAKE_TEST_TABLE  Standard test table (3 rows)
T = table( ...
    ["Deep Learning for Climate"; "Neural Networks Review"; "Attention Mechanisms"], ...
    ["10.1000/dl2023"; "10.1001/nn2022"; "10.1002/attn2024"], ...
    int32([2023; 2022; 2024]), ...
    int32([150; 80; 45]), ...
    logical([true; false; true]), ...
    ["Nature Machine Intelligence"; "Science"; "ICML Proceedings"], ...
    ["article"; "review"; "conference-paper"], ...
    ["Deep learning methods are applied to climate forecasting."; ...
     "A comprehensive review of neural network architectures."; ...
     "Self-attention mechanisms improve sequence modeling."], ...
    ["Smith, John"; "Tanaka, Yuki"; "Mueller, Hans"], ...
    ["Smith, John"; "Sato, Kenji"; "Weber, Anna"], ...
    'VariableNames', {'title','doi','publication_year','cited_by_count', ...
                      'is_oa','source_name','type','abstract', ...
                      'first_author_name','last_author_name'});
end

function T = local_make_dup_table()
%LOCAL_MAKE_DUP_TABLE  Table where same author x same year causes key duplication (3 rows)
T = table( ...
    ["Study on Renewable Energy"; "Study on Solar Energy"; "Study on Wind Energy"], ...
    ["10.1000/re1"; "10.1000/re2"; "10.1000/re3"], ...
    int32([2024; 2024; 2024]), ...
    int32([10; 20; 30]), ...
    logical([true; true; true]), ...
    ["Journal A"; "Journal A"; "Journal A"], ...
    ["article"; "article"; "article"], ...
    ["Abstract one."; "Abstract two."; "Abstract three."], ...
    ["Kim, Jae"; "Kim, Jae"; "Kim, Jae"], ...
    ["Park, Su"; "Park, Su"; "Park, Su"], ...
    'VariableNames', {'title','doi','publication_year','cited_by_count', ...
                      'is_oa','source_name','type','abstract', ...
                      'first_author_name','last_author_name'});
end

function T = local_make_typed_table(typeStr)
%LOCAL_MAKE_TYPED_TABLE  1-row table with specified type
T = table( ...
    string("Test Paper"), ...
    string("10.9999/test"), ...
    int32(2023), ...
    int32(5), ...
    true, ...
    string("Test Venue"), ...
    string(typeStr), ...
    string("Test abstract."), ...
    string("Author, Test"), ...
    string("Author, Test"), ...
    'VariableNames', {'title','doi','publication_year','cited_by_count', ...
                      'is_oa','source_name','type','abstract', ...
                      'first_author_name','last_author_name'});
end

function txt = local_read_text(filePath)
%LOCAL_READ_TEXT  Read a text file and return all lines concatenated
fid = fopen(char(filePath), 'r', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));
txt = '';
while ~feof(fid)
    line = fgetl(fid);
    if ischar(line)
        txt = [txt, line, newline]; %#ok<AGROW>
    end
end
end
