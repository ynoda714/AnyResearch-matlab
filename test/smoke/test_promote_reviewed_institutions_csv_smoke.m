function test_promote_reviewed_institutions_csv_smoke()
%TEST_PROMOTE_REVIEWED_INSTITUTIONS_CSV_SMOKE  Smoke test for candidate CSV promotion.

fprintf('\n=== test_promote_reviewed_institutions_csv_smoke ===\n');
passCount = 0;
totalTests = 5;

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'openalex'));
addpath(fullfile(projectRoot, 'src', 'util'));

tmpRoot = fullfile(tempdir, ['test_promote_reviewed_' char(java.util.UUID.randomUUID())]);
mkdir(tmpRoot);
cleanup = onCleanup(@() local_remove_dir(tmpRoot));

expectedCols = {'account','openalex_institution_id','display_name','country_code', ...
    'works_count','include','role','note','status'};

%% T1: Missing source gives an actionable error
fprintf('[T1] missing source -> SourceNotFound ...');
missingSource = fullfile(tmpRoot, 'missing_candidate.csv');
target1 = fullfile(tmpRoot, 'data', 'list', 'institutions.csv');
try
    promote_reviewed_institutions_csv(missingSource, target1);
    error('T1: expected SourceNotFound error');
catch ex
    assert(contains(ex.identifier, 'SourceNotFound'), ...
        sprintf('T1: unexpected error id="%s"', ex.identifier));
    assert(contains(ex.message, 'Section 0.5') && contains(ex.message, 'Section 0.6'), ...
        'T1: error message should describe the 0.5 -> review -> 0.6 flow');
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T2: New target is created without backup
fprintf('[T2] promote to new target -> copy without backup ...');
source2 = fullfile(tmpRoot, 'institutions_candidate.csv');
target2 = fullfile(tmpRoot, 'data', 'list', 'institutions.csv');
local_write_reviewed_csv(source2, expectedCols, "Example Research University", "I1234567890");
result2 = promote_reviewed_institutions_csv(source2, target2);
assert(isfile(target2), 'T2: target CSV was not created');
assert(result2.backupCsv == "", 'T2: backupCsv should be empty when target did not exist');
T2 = readtable(target2, 'VariableNamingRule', 'preserve');
assert(string(T2.account(1)) == "Example Research University", 'T2: copied account mismatch');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T3: Existing target is backed up before overwrite
fprintf('[T3] promote over existing target -> backup then overwrite ...');
source3 = fullfile(tmpRoot, 'institutions_candidate_updated.csv');
target3 = target2;
local_write_reviewed_csv(source3, expectedCols, "Example Technical University", "I1000000001");
result3 = promote_reviewed_institutions_csv(source3, target3);
assert(isfile(char(result3.backupCsv)), 'T3: backup CSV missing');
backupText3 = fileread(char(result3.backupCsv));
targetText3 = fileread(target3);
assert(contains(backupText3, 'Example Research University'), 'T3: backup does not contain previous target content');
assert(contains(targetText3, 'Example Technical University'), 'T3: target was not overwritten with reviewed candidate');
assert(contains(char(result3.backupCsv), 'institutions.csv.bak.'), 'T3: backup filename does not follow institutions.csv.bak.<timestamp>');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T3.5: Existing but empty target is still backed up before overwrite
fprintf('[T3.5] promote over empty existing target -> backup created ...');
source35 = fullfile(tmpRoot, 'institutions_candidate_empty.csv');
target35 = fullfile(tmpRoot, 'data', 'list', 'institutions_empty_target.csv');
local_write_reviewed_csv(source35, expectedCols, "Example Medical University", "I2000000002");
local_write_empty_file(target35);
result35 = promote_reviewed_institutions_csv(source35, target35);
assert(isfile(char(result35.backupCsv)), 'T3.5: backup CSV missing for empty existing target');
assert(contains(char(result35.backupCsv), 'institutions_empty_target.csv.bak.'), ...
    'T3.5: backup filename does not follow <target>.bak.<timestamp>');
backupInfo35 = dir(char(result35.backupCsv));
assert(backupInfo35.bytes == 0, 'T3.5: backup of empty target should also be empty');
targetText35 = fileread(target35);
assert(contains(targetText35, 'Example Medical University'), ...
    'T3.5: empty target was not overwritten with reviewed candidate');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T4: Source and target must be different
fprintf('[T4] source equals target -> SamePath ...');
try
    promote_reviewed_institutions_csv(target3, target3);
    error('T4: expected SamePath error');
catch ex
    assert(contains(ex.identifier, 'SamePath'), ...
        sprintf('T4: unexpected error id="%s"', ex.identifier));
end
fprintf(' PASS\n'); passCount = passCount + 1;

fprintf('\n[DONE] test_promote_reviewed_institutions_csv_smoke: %d/%d PASS\n', passCount, totalTests);
if passCount ~= totalTests
    error('test_promote_reviewed_institutions_csv_smoke: %d/%d PASS', passCount, totalTests);
end
fprintf('=== ALL PASS ===\n');
end

function local_write_reviewed_csv(pathValue, expectedCols, accountValue, idValue)
outDir = fileparts(pathValue);
if ~isfolder(outDir)
    mkdir(outDir);
end
T = table( ...
    string(accountValue), string(idValue), string(accountValue), "JP", 100, 1, "main", "reviewed", "found", ...
    'VariableNames', expectedCols);
writetable(T, pathValue);
end

function local_write_empty_file(pathValue)
outDir = fileparts(pathValue);
if ~isfolder(outDir)
    mkdir(outDir);
end
fid = fopen(pathValue, 'w');
if fid == -1
    error('local_write_empty_file: could not create %s', pathValue);
end
fclose(fid);
end

function local_remove_dir(dirPath)
if isfolder(dirPath)
    rmdir(dirPath, 's');
end
end
