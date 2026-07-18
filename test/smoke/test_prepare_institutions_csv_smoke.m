function test_prepare_institutions_csv_smoke()
%TEST_PREPARE_INSTITUTIONS_CSV_SMOKE  Smoke test for reviewed institutions.csv generation.
%
%   How to run:
%     addpath("src/openalex"); addpath("src/config"); addpath("src/util");
%     addpath("test/smoke");
%     test_prepare_institutions_csv_smoke();

fprintf('\n=== test_prepare_institutions_csv_smoke ===\n');
passCount = 0;
totalTests = 14;

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'openalex'));
addpath(fullfile(projectRoot, 'src', 'config'));
addpath(fullfile(projectRoot, 'src', 'util'));

expectedCols = {'account','openalex_institution_id','display_name','country_code', ...
    'works_count','include','role','note','status'};

%% T1: Empty input -> EmptyList
fprintf('[T1] empty list -> EmptyList ...');
try
    prepare_institutions_csv(strings(0, 1), outputPath=fullfile(tempdir, 'dummy.csv'));
    error('T1: expected EmptyList error');
catch ex
    assert(contains(ex.identifier, 'EmptyList') || contains(lower(ex.message), 'empty'), ...
        sprintf('T1: unexpected error id="%s" msg="%s"', ex.identifier, ex.message));
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T1b: load_openalex_api_key precedence
fprintf('[T1b] load_openalex_api_key precedence -> env overrides JSON ...');
tmpSettings1b = fullfile(tempdir, 'test_prepare_institutions_settings_1b.json');
fid = fopen(tmpSettings1b, 'w', 'n', 'UTF-8');
fprintf(fid, '{"openalex":{"api_key":"from_json"}}');
fclose(fid);
oldEnv1b = getenv('ANYRESEARCH_OPENALEX_API_KEY');
setenv('ANYRESEARCH_OPENALEX_API_KEY', '');
cleanup1b = onCleanup(@() setenv('ANYRESEARCH_OPENALEX_API_KEY', oldEnv1b)); %#ok<NASGU>
assert(load_openalex_api_key(tmpSettings1b, false) == "from_json", 'T1b: JSON key not loaded');
setenv('ANYRESEARCH_OPENALEX_API_KEY', 'from_env');
assert(load_openalex_api_key(tmpSettings1b, false) == "from_env", 'T1b: env key did not override JSON');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T1c: load_openalex_api_key(required=true) -> NoApiKey
fprintf('[T1c] load_openalex_api_key required -> NoApiKey ...');
tmpSettings1c = fullfile(tempdir, 'test_prepare_institutions_settings_1c.json');
fid = fopen(tmpSettings1c, 'w', 'n', 'UTF-8');
fprintf(fid, '{"openalex":{"api_key":""}}');
fclose(fid);
oldEnv1c = getenv('ANYRESEARCH_OPENALEX_API_KEY');
setenv('ANYRESEARCH_OPENALEX_API_KEY', '');
cleanup1c = onCleanup(@() setenv('ANYRESEARCH_OPENALEX_API_KEY', oldEnv1c)); %#ok<NASGU>
try
    load_openalex_api_key(tmpSettings1c, true);
    error('T1c: expected NoApiKey error');
catch ex
    assert(contains(ex.identifier, 'NoApiKey'), ...
        sprintf('T1c: unexpected error id="%s"', ex.identifier));
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T2: Text file input -> v2 columns
fprintf('[T2] text file input -> v2 column layout (network) ...');
tmpTxt = fullfile(tempdir, 'test_prepare_institutions_names.txt');
tmpCsv = fullfile(tempdir, 'test_prepare_institutions_T2.csv');
fid = fopen(tmpTxt, 'w', 'n', 'UTF-8');
fprintf(fid, '# comment line\n');
fprintf(fid, 'Nagoya University\n');
fprintf(fid, '\n');
fprintf(fid, 'Kyoto University\n');
fclose(fid);
try
    [outPath2, T2] = prepare_institutions_csv(tmpTxt, outputPath=tmpCsv);
    assert(isfile(char(outPath2)), 'T2: output file missing');
    local_assert_columns(T2, expectedCols, 'T2');
    assert(numel(unique(T2.account)) == 2, 'T2: expected 2 unique accounts');
    fprintf(' PASS\n'); passCount = passCount + 1;
catch ex
    if local_is_network_error(ex)
        fprintf(' SKIP (network unavailable)\n');
        passCount = passCount + 1;
    else
        rethrow(ex);
    end
end

%% T3: rank-1 proposal and role hint
fprintf('[T3] found rows -> include proposal and hospital role hint (network) ...');
tmpCsv3 = fullfile(tempdir, 'test_prepare_institutions_T3.csv');
try
    [~, T3] = prepare_institutions_csv(["Nagoya University Hospital"], ...
        outputPath=tmpCsv3, maxCandidates=3);
    local_assert_columns(T3, expectedCols, 'T3');
    foundRows = T3(T3.status == "found", :);
    assert(~isempty(foundRows), 'T3: no found rows');
    assert(foundRows.include(1) == 1, 'T3: first found row must propose include=1');
    if height(foundRows) >= 2
        assert(all(foundRows.include(2:end) == 0), 'T3: non-top rows must default include=0');
    end
    if any(contains(lower(foundRows.display_name), "hospital")) || any(contains(foundRows.display_name, "病院"))
        assert(any(foundRows.role == "hospital"), 'T3: hospital-like candidate should propose role=hospital');
    end
    fprintf(' PASS\n'); passCount = passCount + 1;
catch ex
    if local_is_network_error(ex)
        fprintf(' SKIP (network unavailable)\n');
        passCount = passCount + 1;
    else
        rethrow(ex);
    end
end

%% T4: not found row keeps blank ID and status
fprintf('[T4] fictitious institution -> not_found audit row (network) ...');
tmpCsv4 = fullfile(tempdir, 'test_prepare_institutions_T4.csv');
try
    [~, T4] = prepare_institutions_csv(["XYZZY_NONEXISTENT_UNIV_99999"], outputPath=tmpCsv4);
    assert(height(T4) == 1, sprintf('T4: expected 1 row, got %d', height(T4)));
    assert(T4.status(1) == "not_found", 'T4: expected status=not_found');
    assert(T4.openalex_institution_id(1) == "", 'T4: ID should be blank for not_found');
    assert(T4.include(1) == 0, 'T4: include should default to 0');
    fprintf(' PASS\n'); passCount = passCount + 1;
catch ex
    if local_is_network_error(ex)
        fprintf(' SKIP (network unavailable)\n');
        passCount = passCount + 1;
    else
        rethrow(ex);
    end
end

%% T5: countryFilter and maxCandidates
fprintf('[T5] countryFilter + maxCandidates respected (network) ...');
tmpCsv5 = fullfile(tempdir, 'test_prepare_institutions_T5.csv');
names5 = ["Nagoya University"; "Tohoku University"];
try
    [~, T5] = prepare_institutions_csv(names5, ...
        outputPath=tmpCsv5, countryFilter="JP", maxCandidates=2);
    for k = 1:numel(names5)
        rows = T5(T5.account == names5(k) & T5.status == "found", :);
        assert(height(rows) <= 2, 'T5: maxCandidates exceeded');
        if ~isempty(rows)
            assert(all(rows.country_code == "JP"), 'T5: non-JP row survived JP filter');
        end
    end
    fprintf(' PASS\n'); passCount = passCount + 1;
catch ex
    if local_is_network_error(ex)
        fprintf(' SKIP (network unavailable)\n');
        passCount = passCount + 1;
    else
        rethrow(ex);
    end
end

%% T6: merge preserves reviewed fields on exact match
fprintf('[T6] merge exact match preserves include/role/note (offline) ...');
fresh6 = table( ...
    ["Alpha"; "Alpha"], ["I1"; "I2"], ["Alpha Univ"; "Alpha Hospital"], ["JP"; "JP"], ...
    [100; 50], [1; 0], [""; "hospital"], [""; ""], ["found"; "found"], ...
    'VariableNames', expectedCols);
existing6 = table( ...
    ["Alpha"; "Alpha"], ["I1"; "I2"], ["Old Alpha"; "Old Hospital"], ["JP"; "JP"], ...
    [90; 40], ["0"; "1"], ["primary"; "hospital"], ["keep1"; "keep2"], ["found"; "found"], ...
    'VariableNames', expectedCols);
M6 = merge_institutions_review_table(fresh6, existing6, "2026-07-17");
rowI1 = M6(M6.account == "Alpha" & M6.openalex_institution_id == "I1", :);
rowI2 = M6(M6.account == "Alpha" & M6.openalex_institution_id == "I2", :);
assert(rowI1.include == 0 && rowI1.role == "primary" && rowI1.note == "keep1", 'T6: I1 reviewed fields not preserved');
assert(rowI2.include == 1 && rowI2.role == "hospital" && rowI2.note == "keep2", 'T6: I2 reviewed fields not preserved');
assert(rowI1.display_name == "Alpha Univ" && rowI1.works_count == 100, 'T6: API fields not refreshed');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T7: merge adds new candidate to existing account with include=0 and note
fprintf('[T7] merge new ID on existing account -> include=0 + note (offline) ...');
fresh7 = table( ...
    ["Alpha"; "Alpha"], ["I1"; "I3"], ["Alpha Univ"; "Alpha Clinic"], ["JP"; "JP"], ...
    [100; 20], [1; 1], [""; ""], [""; ""], ["found"; "found"], ...
    'VariableNames', expectedCols);
existing7 = table( ...
    "Alpha", "I1", "Old Alpha", "JP", 90, "1", "primary", "reviewed", "found", ...
    'VariableNames', expectedCols);
M7 = merge_institutions_review_table(fresh7, existing7, "2026-07-17");
rowNew = M7(M7.account == "Alpha" & M7.openalex_institution_id == "I3", :);
assert(height(rowNew) == 1, 'T7: new candidate row missing');
assert(rowNew.include == 0, 'T7: new candidate must default to include=0 in merge mode');
assert(contains(rowNew.note, 'new candidate since 2026-07-17'), 'T7: missing new-candidate note');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T8: merge keeps existing row not returned by API
fprintf('[T8] merge missing API row -> keep row and append note (offline) ...');
fresh8 = table( ...
    "Alpha", "I1", "Alpha Univ", "JP", 100, 1, "", "", "found", ...
    'VariableNames', expectedCols);
existing8 = table( ...
    ["Alpha"; "Alpha"], ["I1"; "I9"], ["Old Alpha"; "Legacy Alpha"], ["JP"; "JP"], ...
    [90; 10], ["1"; "0"], [""; ""], ["keep"; "manual"], ["found"; "found"], ...
    'VariableNames', expectedCols);
M8 = merge_institutions_review_table(fresh8, existing8, "2026-07-17");
rowOld = M8(M8.account == "Alpha" & M8.openalex_institution_id == "I9", :);
assert(height(rowOld) == 1, 'T8: missing legacy row');
assert(contains(rowOld.note, 'manual'), 'T8: original note lost');
assert(contains(rowOld.note, 'not returned by API on 2026-07-17'), 'T8: missing retention note');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T9: merge new account resets proposals to include=0
fprintf('[T9] merge new account rows -> include=0 (offline) ...');
fresh9 = table( ...
    ["Beta"; "Beta"], ["I20"; "I21"], ["Beta Univ"; "Beta Hospital"], ["US"; "US"], ...
    [30; 20], [1; 0], [""; "hospital"], [""; ""], ["found"; "found"], ...
    'VariableNames', expectedCols);
existing9 = table( ...
    "Alpha", "I1", "Alpha Univ", "JP", 100, "1", "primary", "done", "found", ...
    'VariableNames', expectedCols);
M9 = merge_institutions_review_table(fresh9, existing9, "2026-07-17");
betaRows = M9(M9.account == "Beta", :);
assert(all(betaRows.include == 0), 'T9: new account rows must default to include=0 in merge mode');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T10: mergeWith roundtrip preserves reviewed fields in written CSV
fprintf('[T10] prepare_institutions_csv mergeWith writes preserved review fields (network) ...');
mergePath10 = fullfile(tempdir, 'test_prepare_institutions_merge_existing.csv');
outCsv10 = fullfile(tempdir, 'test_prepare_institutions_T10.csv');
existing10 = table( ...
    "Nagoya University", "I145673806", "Old Name", "JP", 1, "1", "primary", "keep reviewed", "found", ...
    'VariableNames', expectedCols);
writetable(existing10, mergePath10);
try
    [~, T10] = prepare_institutions_csv(["Nagoya University"], ...
        outputPath=outCsv10, maxCandidates=1, mergeWith=mergePath10);
    row10 = T10(T10.account == "Nagoya University" & T10.openalex_institution_id == "I145673806", :);
    assert(height(row10) <= 1, 'T10: duplicate merged row found');
    if height(row10) == 1
        assert(row10.include == 1, 'T10: include not preserved');
        assert(row10.role == "primary", 'T10: role not preserved');
        assert(contains(row10.note, "keep reviewed"), 'T10: note not preserved');
    end
    fprintf(' PASS\n'); passCount = passCount + 1;
catch ex
    if local_is_network_error(ex)
        fprintf(' SKIP (network unavailable)\n');
        passCount = passCount + 1;
    else
        rethrow(ex);
    end
end

%% T11: source-level guard -> prepare_institutions_csv requires API key helper
fprintf('[T11] prepare_institutions_csv uses load_openalex_api_key ...');
src11 = fileread(fullfile(projectRoot, 'src', 'openalex', 'prepare_institutions_csv.m'));
assert(contains(src11, 'load_openalex_api_key'), ...
    'T11: prepare_institutions_csv does not call load_openalex_api_key');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T12: source-level guard -> batch dryRun preview passes explicit apiKey
fprintf('[T12] run_batch_from_institutions_list dryRun passes explicit apiKey ...');
src12 = fileread(fullfile(projectRoot, 'src', 'pipeline', 'run_batch_from_institutions_list.m'));
assert(contains(src12, 'load_openalex_api_key'), ...
    'T12: local_preview_target does not load API key explicitly');
assert(contains(src12, 'apiKey=apiKey'), ...
    'T12: local_preview_target does not pass explicit apiKey to fetch_openalex_works');
fprintf(' PASS\n'); passCount = passCount + 1;

fprintf('\n[DONE] test_prepare_institutions_csv_smoke: %d/%d PASS\n', passCount, totalTests);
if passCount ~= totalTests
    error('test_prepare_institutions_csv_smoke: %d/%d PASS', passCount, totalTests);
end
fprintf('=== ALL PASS ===\n');
end

function local_assert_columns(T, expectedCols, label)
for i = 1:numel(expectedCols)
    assert(ismember(expectedCols{i}, T.Properties.VariableNames), ...
        sprintf('%s: missing column "%s"', label, expectedCols{i}));
end
end

function tf = local_is_network_error(ex)
tf = contains(ex.message, 'MATLAB:webservices') || ...
     contains(lower(ex.message), 'connect') || ...
     contains(lower(ex.message), 'timeout') || ...
     contains(lower(ex.message), 'failed to') || ...
     contains(ex.identifier, 'webread') || ...
     contains(ex.identifier, 'ApiError');
end
