function test_load_institutions_list_smoke()
%TEST_LOAD_INSTITUTIONS_LIST_SMOKE  Phase M: reviewed institutions.csv loader smoke test.
%
%   How to run:
%     addpath("src/openalex");
%     addpath("test/smoke");
%     test_load_institutions_list_smoke();

fprintf('\n=== test_load_institutions_list_smoke ===\n');
passCount = 0;

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'openalex'));

tmpDir = fullfile(tempdir, 'smoke_load_institutions_list');
if isfolder(tmpDir)
    rmdir(tmpDir, 's');
end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

%% T1: legacy 2-column CSV -> grouped targets
fprintf('[T1] legacy 2-column CSV -> grouped targets ...');
csv1 = fullfile(tmpDir, 'legacy.csv');
writecell({ ...
    'Account', 'openalex_institution_id'; ...
    'Example Medical University', 'I100000001'; ...
    'Example Medical University', 'I100000002'; ...
    'Nagoya University', 'I1234567890'}, csv1);
T1 = load_institutions_list(csv1);
assert(height(T1) == 2, 'T1: target rows ~= 2');
assert(T1.n_ids(1) == 2, 'T1: Example Medical n_ids ~= 2');
assert(isequal(string(T1.institution_ids{1}), ["I100000001"; "I100000002"]), ...
    'T1: grouped institution_ids mismatch');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T2: reviewed v2 CSV -> include filter / display_name / role preserved
fprintf('[T2] reviewed v2 CSV -> include filter and metadata retention ...');
csv2 = fullfile(tmpDir, 'reviewed_v2.csv');
writecell({ ...
    'account', 'openalex_institution_id', 'display_name', 'include', 'role', 'note'; ...
    'University of Hyogo', 'I108169390', 'University of Hyogo', '1', 'main', ''; ...
    'University of Hyogo', 'I137459256', 'University of Hyogo Hospital', '0', 'hospital', 'excluded'; ...
    'University of Hyogo', 'I180941496', 'University of Hyogo Branch', 'true', 'branch', ''; ...
    'Nagoya City University', 'I33858575', 'Nagoya City University', 'yes', 'main', ''}, csv2);
T2 = load_institutions_list(csv2);
uoh = T2(T2.account == "University of Hyogo", :);
assert(height(uoh) == 1, 'T2: University of Hyogo row missing');
assert(uoh.n_ids == 2, 'T2: include filter did not reduce rows to 2');
assert(isequal(string(uoh.display_names{1}), ["University of Hyogo"; "University of Hyogo Branch"]), ...
    'T2: display_names mismatch');
assert(isequal(string(uoh.roles{1}), ["main"; "branch"]), ...
    'T2: roles mismatch');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T3: invalid ID format -> error
fprintf('[T3] invalid ID -> InvalidId ...');
csv3 = fullfile(tmpDir, 'bad_id.csv');
writecell({ ...
    'Account', 'openalex_institution_id'; ...
    'Bad University', '12345'}, csv3);
try
    load_institutions_list(csv3);
    error('T3: error not thrown');
catch ex
    assert(contains(ex.identifier, 'InvalidId'), ...
        'T3: expected InvalidId');
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T4: include=0 only account -> warning + skipped target
fprintf('[T4] include=0 only account -> warning and skip ...');
csv4 = fullfile(tmpDir, 'skip_only.csv');
writecell({ ...
    'account', 'openalex_institution_id', 'include'; ...
    'Skip Me', 'I1000000001', '0'; ...
    'Keep Me', 'I1000000002', '1'}, csv4);
lastwarn('');
T4 = load_institutions_list(csv4);
[warnMsg, warnId] = lastwarn();
assert(height(T4) == 1 && T4.account(1) == "Keep Me", ...
    'T4: skipped account still present');
assert(contains(warnId, 'NoIncludedRows') || contains(warnMsg, 'include=1'), ...
    'T4: expected skip warning was not emitted');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T5: duplicate ID across accounts -> warning
fprintf('[T5] duplicate ID across accounts -> warning ...');
csv5 = fullfile(tmpDir, 'dup_across_accounts.csv');
writecell({ ...
    'Account', 'openalex_institution_id'; ...
    'Univ A', 'I1000000099'; ...
    'Univ B', 'I1000000099'}, csv5);
lastwarn('');
T5 = load_institutions_list(csv5);
[warnMsg5, warnId5] = lastwarn();
assert(height(T5) == 2, 'T5: both accounts should remain');
assert(contains(warnId5, 'DuplicateIdAcrossAccounts') || contains(warnMsg5, 'multiple accounts'), ...
    'T5: expected duplicate warning was not emitted');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T6: invalid include value -> error
fprintf('[T6] invalid include value -> InvalidInclude ...');
csv6 = fullfile(tmpDir, 'bad_include.csv');
writecell({ ...
    'account', 'openalex_institution_id', 'include'; ...
    'Bad Include University', 'I1000000101', 'maybe'}, csv6);
try
    load_institutions_list(csv6);
    error('T6: error not thrown');
catch ex
    assert(contains(ex.identifier, 'InvalidInclude'), ...
        'T6: expected InvalidInclude');
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T7: all accounts excluded -> NoTargets
fprintf('[T7] all accounts excluded -> NoTargets ...');
csv7 = fullfile(tmpDir, 'all_excluded.csv');
writecell({ ...
    'account', 'openalex_institution_id', 'include'; ...
    'Skip A', 'I1000000102', '0'; ...
    'Skip B', 'I1000000103', 'false'}, csv7);
try
    load_institutions_list(csv7);
    error('T7: error not thrown');
catch ex
    assert(contains(ex.identifier, 'NoTargets'), ...
        'T7: expected NoTargets');
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T8: header case-insensitive + same-account duplicate IDs deduplicated
fprintf('[T8] case-insensitive headers + same-account dedup ...');
csv8 = fullfile(tmpDir, 'mixed_headers.csv');
writecell({ ...
    'ACCOUNT', 'OPENALEX_INSTITUTION_ID', 'DISPLAY_NAME', 'INCLUDE', 'ROLE'; ...
    'Dedup University', 'I1000000104', 'Dedup University', '1', 'main'; ...
    'Dedup University', 'I1000000104', 'Dedup University Duplicate', '1', 'main'; ...
    'Dedup University', 'I1000000105', 'Dedup University Hospital', '1', 'hospital'}, csv8);
T8 = load_institutions_list(csv8);
assert(height(T8) == 1, 'T8: target rows ~= 1');
assert(T8.n_ids(1) == 2, 'T8: duplicate IDs were not deduplicated');
assert(isequal(string(T8.institution_ids{1}), ["I1000000104"; "I1000000105"]), ...
    'T8: institution_ids mismatch after dedup');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T9: not_found row with empty ID is dropped, not crash the loader
fprintf('[T9] not_found row (empty ID) -> dropped, reviewed targets load ...');
csv9 = fullfile(tmpDir, 'with_not_found.csv');
fid9 = fopen(csv9, 'w', 'n', 'UTF-8');
assert(fid9 > 0, 'T9: could not write fixture');
fprintf(fid9, 'account,openalex_institution_id,display_name,include,role,note,status\n');
fprintf(fid9, 'Toyo University,I158123994,Toyo University,1,main,,found\n');
fprintf(fid9, 'Toyo University,I215126927,Toyo University Branch,0,,,found\n');
fprintf(fid9, 'Hokuriku Polytechnic College,,,0,,,not_found\n');
fclose(fid9);
T9 = load_institutions_list(csv9);
assert(any(T9.account == "Toyo University"), 'T9: reviewed target was not loaded');
assert(~any(T9.account == "Hokuriku Polytechnic College"), ...
    'T9: not_found row with empty ID leaked into targets');
fprintf(' PASS\n'); passCount = passCount + 1;

fprintf('\n=== test_load_institutions_list_smoke: %d PASSED ===\n\n', passCount);
end
