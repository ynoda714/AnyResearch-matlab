function test_load_run_smoke()
%TEST_LOAD_RUN_SMOKE  Phase J-4 load_run / load_latest_run smoke test

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'util'));

tmpDir = fullfile(tempdir, 'smoke_load_run');
if isfolder(tmpDir)
    rmdir(tmpDir, 's');
end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

run1 = fullfile(tmpDir, '20260717_101500');
run2 = fullfile(tmpDir, '20260717_101501');
mkdir(run1);
mkdir(run2);

T1 = table(["W1"; "W2"], ["Title 1"; "Title 2"], [1; 2], ...
    'VariableNames', ["openalex_id", "title", "cited_by_count"]);
T = T1; %#ok<NASGU>
save(fullfile(run1, 'search_results.mat'), 'T');

T1Loaded = load_run(run1);
assert(istable(T1Loaded), 'Case1: load_run(mat) must return table');
assert(height(T1Loaded) == 2, 'Case1: row count mismatch');
assert(all(T1Loaded.title == T1.title), 'Case1: mat-backed titles mismatch');

T2 = table(["W3"], ["Comma, newline" + newline + """quoted"" text"], [3], ...
    'VariableNames', ["openalex_id", "title", "cited_by_count"]);
write_jsonl(T2, fullfile(run2, 'search_results.jsonl'));

T2Loaded = load_run(run2);
assert(istable(T2Loaded), 'Case2: load_run(jsonl) must return table');
assert(height(T2Loaded) == 1, 'Case2: jsonl row count mismatch');
assert(T2Loaded.title(1) == T2.title(1), 'Case2: jsonl-backed title mismatch');

TLatest = load_latest_run(tmpDir);
assert(height(TLatest) == 1, 'Case3: latest run should be run2');
assert(TLatest.openalex_id(1) == "W3", 'Case3: latest run openalex_id mismatch');

try
    load_run(fullfile(tmpDir, 'missing_run'));
    error('Case4: expected load_run to fail for missing run dir');
catch ex
    assert(strcmp(ex.identifier, 'load_run:RunDirNotFound'), ...
        'Case4: unexpected error id: %s', ex.identifier);
end

fprintf("Smoke test passed: load_run / load_latest_run\n");
end
