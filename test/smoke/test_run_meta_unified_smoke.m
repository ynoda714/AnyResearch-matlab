function test_run_meta_unified_smoke()
%TEST_RUN_META_UNIFIED_SMOKE  M17: run_meta.json unified output smoke test
%
%   Test coverage:
%   1. write_run_meta can write JSON correctly
%   2. schema_version is "2.1"
%   3. created_at is automatically populated
%   4. pipeline / batch modes both have equivalent fields
%   5. JSON can be written even when status = "failed"
%   6. run_manifest_json does not exist in create_run_context

fprintf('\n=== test_run_meta_unified_smoke ===\n');
passCount = 0;
failCount = 0;

tmpDir = fullfile(tempdir, 'test_run_meta_smoke');
if isfolder(tmpDir)
    rmdir(tmpDir, 's');
end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

%% Test 1: write_run_meta basic output
fprintf('[Test 1] write_run_meta basic output ...');
metaPath = fullfile(tmpDir, 'test1_run_meta.json');
meta = struct();
meta.run_id = "20260319_120000";
meta.run_dir = "result/runs/20260319_120000";
meta.mode = "pipeline";
meta.status = "completed";
meta.query = "matlab";
meta.filter = "is_oa:true,language:en";
write_run_meta(metaPath, meta);

assert(isfile(metaPath), 'run_meta.json が生成されていない');
raw = fileread(metaPath);
decoded = jsondecode(raw);
assert(isfield(decoded, 'schema_version'), 'schema_version フィールドが存在しない');
assert(strcmp(decoded.schema_version, '2.1'), 'schema_version が 2.1 ではない');
assert(isfield(decoded, 'created_at'), 'created_at が自動付与されていない');
assert(strlength(string(decoded.created_at)) > 0, 'created_at が空');
assert(strcmp(decoded.run_id, '20260319_120000'), 'run_id が正しくない');
assert(strcmp(decoded.mode, 'pipeline'), 'mode が正しくない');
assert(strcmp(decoded.status, 'completed'), 'status が正しくない');
fprintf(' PASS\n');
passCount = passCount + 1;

%% Test 2: do not overwrite created_at when already specified
fprintf('[Test 2] created_at preservation ...');
metaPath2 = fullfile(tmpDir, 'test2_run_meta.json');
meta2 = struct();
meta2.run_id = "20260319_130000";
meta2.run_dir = "result/runs/20260319_130000";
meta2.mode = "batch";
meta2.status = "completed";
meta2.created_at = "2026-03-19T13:00:00";
write_run_meta(metaPath2, meta2);

raw2 = fileread(metaPath2);
decoded2 = jsondecode(raw2);
assert(strcmp(decoded2.created_at, '2026-03-19T13:00:00'), 'created_at が上書きされてしまった');
fprintf(' PASS\n');
passCount = passCount + 1;

%% Test 3: output when status = "failed"
fprintf('[Test 3] failed status output ...');
metaPath3 = fullfile(tmpDir, 'test3_run_meta.json');
meta3 = struct();
meta3.run_id = "20260319_140000";
meta3.run_dir = "result/runs/20260319_140000";
meta3.mode = "pipeline";
meta3.status = "failed";
meta3.error_id = "test:SomeError";
meta3.error_message = "Something went wrong";
meta3.hint = "retry with different params";
write_run_meta(metaPath3, meta3);

raw3 = fileread(metaPath3);
decoded3 = jsondecode(raw3);
assert(strcmp(decoded3.status, 'failed'), 'status が failed ではない');
assert(strcmp(decoded3.error_id, 'test:SomeError'), 'error_id が正しくない');
assert(isfield(decoded3, 'schema_version'), '失敗時も schema_version が必要');
fprintf(' PASS\n');
passCount = passCount + 1;

%% Test 4: steps structure is preserved correctly
fprintf('[Test 4] steps structure ...');
metaPath4 = fullfile(tmpDir, 'test4_run_meta.json');
meta4 = struct();
meta4.run_id = "20260319_150000";
meta4.run_dir = "result/runs/20260319_150000";
meta4.mode = "pipeline";
meta4.status = "completed";
steps = struct();
steps.openalex_fetch = struct('status', 'ok');
steps.pdf_download = struct('status', 'ok');
steps.pdf_text_extraction = struct('status', 'skipped');
steps.scoring = struct('status', 'skipped');
steps.keyword_evidence = struct('status', 'ok');
meta4.steps = steps;
write_run_meta(metaPath4, meta4);

raw4 = fileread(metaPath4);
decoded4 = jsondecode(raw4);
assert(isfield(decoded4, 'steps'), 'steps フィールドが存在しない');
assert(strcmp(decoded4.steps.openalex_fetch.status, 'ok'), 'openalex_fetch status が正しくない');
assert(strcmp(decoded4.steps.pdf_text_extraction.status, 'skipped'), 'pdf_text_extraction status is incorrect');
fprintf(' PASS\n');
passCount = passCount + 1;

%% Test 5: outputs structure is preserved correctly
fprintf('[Test 5] outputs structure ...');
metaPath5 = fullfile(tmpDir, 'test5_run_meta.json');
meta5 = struct();
meta5.run_id = "20260319_160000";
meta5.run_dir = "result/runs/20260319_160000";
meta5.mode = "batch";
meta5.status = "completed";
meta5.institution_name = "Test University";
meta5.openalex_institution_id = "I1234567890";
outputs = struct();
outputs.openalex_raw_csv = "raw/openalex_raw.csv";
outputs.normalized_works_csv = "intermediate/normalized_works.csv";
outputs.final_integrated_csv = "intermediate/final_integrated_with_summary.csv";
meta5.outputs = outputs;
write_run_meta(metaPath5, meta5);

raw5 = fileread(metaPath5);
decoded5 = jsondecode(raw5);
assert(isfield(decoded5, 'outputs'), 'outputs フィールドが存在しない');
assert(strcmp(decoded5.outputs.openalex_raw_csv, 'raw/openalex_raw.csv'), 'openalex_raw_csv が正しくない');
assert(strcmp(decoded5.outputs.normalized_works_csv, 'intermediate/normalized_works.csv'), 'normalized_works_csv が正しくない');
assert(strcmp(decoded5.institution_name, 'Test University'), 'institution_name が正しくない');
assert(strcmp(decoded5.mode, 'batch'), 'batch mode が正しくない');
fprintf(' PASS\n');
passCount = passCount + 1;

%% Test 6: create_run_context field verification (deprecated/added)
fprintf('[Test 6] create_run_context fields ...');
testRunDir = fullfile(tmpDir, 'test_runs');
ctx = create_run_context(testRunDir);

% Deprecated in M17: run_manifest_json must not exist
assert(~isfield(ctx, 'run_manifest_json'), 'run_manifest_json がまだ存在する（M17で廃止済み）');
assert(isfield(ctx, 'run_meta_json'), 'run_meta_json フィールドが存在しない');
assert(contains(ctx.run_meta_json, 'run_meta.json'), 'run_meta_json パスに run_meta.json が含まれない');

% Added in P2-6: search_results_* must exist directly under run_dir
assert(isfield(ctx, 'search_results_xlsx'),  'search_results_xlsx フィールドがない');
assert(isfield(ctx, 'search_results_jsonl'), 'search_results_jsonl フィールドがない');
assert(isfield(ctx, 'search_results_csv'),   'search_results_csv フィールドがない');
assert(endsWith(ctx.search_results_xlsx,  'search_results.xlsx'),  'search_results_xlsx の末尾が search_results.xlsx でない');
assert(endsWith(ctx.search_results_jsonl, 'search_results.jsonl'), 'search_results_jsonl の末尾が search_results.jsonl でない');
assert(endsWith(ctx.search_results_csv,   'search_results.csv'),   'search_results_csv の末尾が search_results.csv でない');
[parentXlsx, ~, ~] = fileparts(ctx.search_results_xlsx);
assert(strcmp(parentXlsx, ctx.run_dir), 'search_results_xlsx は run_dir 直下でなければならない');

fprintf(' PASS\n');
passCount = passCount + 1;

%% Test 7: pipeline/batch have equivalent field structure
fprintf('[Test 7] pipeline/batch field parity ...');
metaPipeline = fullfile(tmpDir, 'test7_pipeline.json');
metaBatch = fullfile(tmpDir, 'test7_batch.json');

pMeta = struct();
pMeta.run_id = "20260319_170000";
pMeta.run_dir = "result/runs/20260319_170000";
pMeta.mode = "pipeline";
pMeta.status = "completed";
pMeta.query = "matlab";
pMeta.steps = struct('openalex_fetch', struct('status', 'ok'));
pMeta.outputs = struct('openalex_raw_csv', 'raw/openalex_raw.csv');
write_run_meta(metaPipeline, pMeta);

bMeta = struct();
bMeta.run_id = "20260319_170001";
bMeta.run_dir = "result/batch/20260319/runs/20260319_170001";
bMeta.mode = "batch";
bMeta.status = "completed";
bMeta.query = "matlab";
bMeta.institution_name = "Test Univ";
bMeta.openalex_institution_id = "I999";
bMeta.steps = struct('openalex_fetch', struct('status', 'ok'));
bMeta.outputs = struct('openalex_raw_csv', 'raw/openalex_raw.csv');
write_run_meta(metaBatch, bMeta);

dp = jsondecode(fileread(metaPipeline));
db = jsondecode(fileread(metaBatch));

% Verify common fields exist
commonFields = ["run_id", "run_dir", "mode", "status", "query", "schema_version", "created_at", "steps", "outputs"];
for i = 1:numel(commonFields)
    f = char(commonFields(i));
    assert(isfield(dp, f), sprintf('pipeline に %s フィールドなし', f));
    assert(isfield(db, f), sprintf('batch に %s フィールドなし', f));
end
% batch-only fields
assert(isfield(db, 'institution_name'), 'batch に institution_name がない');
assert(isfield(db, 'openalex_institution_id'), 'batch に openalex_institution_id がない');
fprintf(' PASS\n');
passCount = passCount + 1;

%% Test 8: JSON is valid UTF-8
fprintf('[Test 8] UTF-8 encoding ...');
metaPath8 = fullfile(tmpDir, 'test8_run_meta.json');
meta8 = struct();
meta8.run_id = "20260319_180000";
meta8.run_dir = "result/runs/20260319_180000";
meta8.mode = "pipeline";
meta8.status = "completed";
meta8.query = "MATLAB";
meta8.first_author_institution = "名古屋市立大学";
write_run_meta(metaPath8, meta8);

fid = fopen(metaPath8, 'r', 'n', 'UTF-8');
assert(fid > 0, 'ファイルを開けない');
raw8 = fread(fid, Inf, '*char')';
fclose(fid);
assert(contains(raw8, '名古屋市立大学'), 'UTF-8 日本語が正しく保持されていない');
fprintf(' PASS\n');
passCount = passCount + 1;

%% Summary
fprintf('\n--- test_run_meta_unified_smoke summary ---\n');
fprintf('PASS: %d / FAIL: %d / TOTAL: %d\n', passCount, failCount, passCount + failCount);
if failCount > 0
    error('test_run_meta_unified_smoke:TestFailed', '%d 件のテストが失敗しました', failCount);
end
fprintf('=== All tests passed ===\n\n');
end
