function test_pipeline_e2e_smoke()
%TEST_PIPELINE_E2E_SMOKE  fetch_and_normalize_works -> Excel end-to-end test
%
%   How to run:
%     addpath("src/pipeline"); addpath("src/openalex"); addpath("src/config");
%     addpath("src/adapters"); addpath("src/export"); addpath("src/util");
%     addpath("test/smoke");
%     test_pipeline_e2e_smoke();
%
%   Test coverage:
%     T1. fetch_and_normalize_works generates raw OpenAlex CSV
%     T2. fetch_and_normalize_works generates normalized works CSV
%     T3. Number of fetched rows is 1 or more
%     T4. write_jsonl writes JSONL correctly (first row is valid JSON)
%     T5. export_excel_workbook generates xlsx (> 1KB)
%     T6. First JSONL record has required fields such as title / abstract / publication_year
%     T7. normalized works CSV row count matches JSONL, and required columns exist
%     T8. OpenAlex raw page JSON is saved under the specified raw directory
%     T9. run_pipeline returns result.T and load_run reproduces the same row count
%
%   Note: Requires network connection and a valid settings.json (openalex.api_key).
%         All API-dependent tests are skipped when offline or API key is not configured.

fprintf('\n=== test_pipeline_e2e_smoke ===\n');

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'pipeline'));
addpath(fullfile(projectRoot, 'src', 'config'));
addpath(fullfile(projectRoot, 'src', 'openalex'));
addpath(fullfile(projectRoot, 'src', 'adapters'));
addpath(fullfile(projectRoot, 'src', 'export'));
addpath(fullfile(projectRoot, 'src', 'util'));

tmpDir = fullfile(tempdir, 'smoke_e2e_pipeline');
if isfolder(tmpDir)
    rmdir(tmpDir, 's');
end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

%% API key & network check -> skip all when offline
apiKey = local_load_api_key(projectRoot);
if apiKey == ""
    fprintf('[SKIP] openalex.api_key が設定されていないためスキップします。\n');
    fprintf('       config/settings.json の openalex.api_key を設定してください。\n');
    fprintf('=== test_pipeline_e2e_smoke: SKIPPED ===\n\n');
    return;
end

if ~local_network_reachable(apiKey)
    fprintf('[SKIP] OpenAlex API に到達できないためスキップします。\n');
    fprintf('=== test_pipeline_e2e_smoke: SKIPPED ===\n\n');
    return;
end

passCount = 0;

%% Write temporary settings JSON (minimal: maxPages=1, dryRun=false)
settingsPath = fullfile(tmpDir, 'e2e_settings.json');
local_write_e2e_settings(settingsPath, apiKey);

rawCsvPath = fullfile(tmpDir, 'openalex_raw.csv');
normalizedWorksCsvPath = fullfile(tmpDir, 'normalized_works.csv');
rawResponseDir = fullfile(tmpDir, 'raw');

%% API call
try
    apiRes = fetch_and_normalize_works( ...
        settingsPath, ...
        outputRawCsv=rawCsvPath, ...
        outputNormalizedWorksCsv=normalizedWorksCsvPath, ...
        saveRawResponses=true, ...
        rawResponseDir=rawResponseDir);
catch apiEx
    if contains(apiEx.message, 'webread') || contains(apiEx.identifier, 'MATLAB:webread') ...
            || contains(apiEx.message, 'urlread') || contains(apiEx.message, '429') ...
            || contains(apiEx.message, 'Too Many Requests')
        fprintf('[SKIP] API 呼び出し失敗（ネットワーク不可）: %s\n', apiEx.message);
        fprintf('=== test_pipeline_e2e_smoke: SKIPPED ===\n\n');
        return;
    end
    rethrow(apiEx);
end

%% T1: raw OpenAlex CSV was generated
fprintf('[T1] raw OpenAlex CSV 生成 ...');
assert(isfile(rawCsvPath), 'T1: raw OpenAlex CSV が生成されていない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T2: normalized works CSV was generated
fprintf('[T2] normalized works CSV 生成 ...');
assert(isfile(normalizedWorksCsvPath), 'T2: normalized works CSV が生成されていない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T3: fetched row count >= 1
fprintf('[T3] 取得行数 >= 1 ...');
assert(isfield(apiRes, 'rows'), 'T3: apiRes に rows フィールドがない');
assert(double(apiRes.rows) >= 1, ...
    sprintf('T3: 取得行数=%d (expected >= 1)', double(apiRes.rows)));
fprintf(' PASS  rows=%d\n', double(apiRes.rows)); passCount = passCount + 1;

%% T4: JSONL is written by write_jsonl
fprintf('[T4] write_jsonl: JSONL 生成 ...');
T = readtable(normalizedWorksCsvPath, "TextType", "string", "VariableNamingRule", "preserve", ...
    "Delimiter", ",", "ReadVariableNames", true);
jsonlPath = fullfile(tmpDir, 'search_results.jsonl');
write_jsonl(T, jsonlPath);
assert(isfile(jsonlPath), 'T4: JSONL ファイルが生成されていない');
finfo = dir(jsonlPath);
assert(finfo.bytes > 0, 'T4: JSONL ファイルが空');
% First row must be valid JSON
fid = fopen(jsonlPath, 'r', 'n', 'UTF-8');
firstLine = fgetl(fid);
fclose(fid);
parsed = jsondecode(firstLine);
assert(isstruct(parsed), 'T4: JSONL 先頭行が有効な JSON でない');
fprintf(' PASS  lines=%d\n', height(T)); passCount = passCount + 1;

%% T5: export_excel_workbook generates xlsx
fprintf('[T5] export_excel_workbook: xlsx 生成 ...');
xlsxPath = fullfile(tmpDir, 'search_results.xlsx');
cfg = struct( ...
    'query',      'matlab openaccess test', ...
    'from_date',  '2025-01-01', ...
    'to_date',    '2025-03-31', ...
    'run_id',     'e2e_smoke_test', ...
    'rows_fetched', int32(apiRes.rows), ...
    'created_at', char(string(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'))));
export_excel_workbook(jsonlPath, xlsxPath, cfg);
assert(isfile(xlsxPath), 'T5: xlsx が生成されていない');
xinfo = dir(xlsxPath);
assert(xinfo.bytes > 1024, sprintf('T5: xlsx サイズ=%d (expected > 1024)', xinfo.bytes));
% Verify all 4 sheets exist
sheets = sheetnames(xlsxPath);
for sName = ["Overview", "Detail", "Summary", "Config"]
    assert(any(strcmp(sheets, char(sName))), ...
        sprintf('T5: シート "%s" が存在しない (sheets=%s)', char(sName), strjoin(sheets, ', ')));
end
fprintf(' PASS  size=%dKB  sheets=%d\n', round(xinfo.bytes / 1024), numel(sheets)); passCount = passCount + 1;

%% T6: JSONL content is valid (query filter is reflected in settings)
fprintf('[T6] JSONL 内容検証: 必須列が存在すること ...');
% First row already parsed in T4, additionally verify required columns exist
requiredFields = ["title", "abstract", "publication_year"];
for fi = 1:numel(requiredFields)
    f = char(requiredFields(fi));
    assert(isfield(parsed, f), sprintf('T6: JSONL 先頭行に必須フィールド "%s" がない', f));
end
% title must not be empty
assert(~isempty(strtrim(char(string(parsed.title)))), 'T6: JSONL 先頭行の title が空');
% either doi or publication_year must exist
hasKey = isfield(parsed,'doi') || isfield(parsed,'publication_year');
assert(hasKey, 'T6: doi / publication_year のどちらもない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T7: normalized works CSV content validation (required headers, row count match)
fprintf('[T7] normalized works CSV ヘッダ・行数 ...');
T_check = readtable(normalizedWorksCsvPath, "TextType", "string", "VariableNamingRule", "preserve", ...
    "Delimiter", ",", "ReadVariableNames", true);
assert(height(T_check) == height(T), ...
    sprintf('T7: normalized works CSV 行数=%d が JSONL 行数=%d と一致しない', height(T_check), height(T)));
% Verify required columns exist
for colName = ["title", "abstract", "publication_year"]
    assert(ismember(colName, string(T_check.Properties.VariableNames)), ...
        sprintf('T7: normalized works CSV に必須列 "%s" がない', char(colName)));
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T8: OpenAlex raw page JSON saved
fprintf('[T8] raw OpenAlex response 保存 ...');
rawPage1 = fullfile(rawResponseDir, 'openalex_page_001.json');
assert(isfile(rawPage1), 'T8: openalex_page_001.json が保存されていない');
rawText = strtrim(string(fileread(rawPage1)));
assert(startsWith(rawText, "{"), 'T8: raw JSON の先頭が "{" でない');
assert(contains(rawText, '"results"'), 'T8: raw JSON に results が含まれない');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T9: run_pipeline returns result.T and load_run can restore it
fprintf('[T9] run_pipeline result.T / load_run ...');
pipelineRoot = fullfile(tmpDir, 'runs');
r = run_pipeline("matlab openaccess", "2025-01-01", "2025-03-31", ...
    language="en", requireOpenAccess=true, maxPages=1, candidateMaxPages=1, ...
    maxRowsForValidation=5, samplingMode="head", showCountPreview=false, ...
    enablePdfDownload=false, useArxiv=false, runRootDir=pipelineRoot, saveRawResponses=true);
assert(isfield(r, 'T') && istable(r.T), 'T9: run_pipeline result.T must be a table');
assert(height(r.T) >= 1, 'T9: run_pipeline result.T must have at least 1 row');
assert(isfile(fullfile(r.run_dir, 'search_results.mat')), 'T9: search_results.mat was not saved');
T_loaded = load_run(r.run_dir);
assert(height(T_loaded) == height(r.T), 'T9: load_run row count mismatch');
fprintf(' PASS\n'); passCount = passCount + 1;

fprintf('\n=== test_pipeline_e2e_smoke: %d/9 PASSED ===\n\n', passCount);
assert(passCount == 9, sprintf('FAILED: %d/9 テストが失敗しました', 9 - passCount));
end

%% ─── Local helpers ───────────────────────────────────────────────────

function apiKey = local_load_api_key(projectRoot)
apiKey = "";
% 1. Environment variable
for envName = ["ANYRESEARCH_OPENALEX_API_KEY", "OPENALEX_API_KEY"]
    v = strtrim(string(getenv(char(envName))));
    if v ~= ""
        apiKey = v;
        return;
    end
end
% 2. config/settings.json
settingsFile = fullfile(projectRoot, 'config', 'settings.json');
if isfile(settingsFile)
    try
        s = jsondecode(fileread(settingsFile));
        if isfield(s, 'openalex') && isfield(s.openalex, 'api_key')
            v = strtrim(string(s.openalex.api_key));
            if v ~= ""
                apiKey = v;
                return;
            end
        end
    catch
    end
end
end

function tf = local_network_reachable(apiKey)
tf = false;
try
    info = get_openalex_rate_limit_status(apiKey, 8);
    enoughCredits = isnan(info.credits_remaining) || info.credits_remaining >= 3;
    tf = info.ok && info.can_query && enoughCredits;
catch
end
end

function local_write_e2e_settings(path, apiKey)
% Write minimal settings JSON for E2E test (maxPages=1, date range filter)
s = struct();
s.openalex = struct();
s.openalex.api_key           = char(apiKey);
s.openalex.search_query      = 'matlab openaccess';
s.openalex.filter            = 'is_oa:true,language:en,from_publication_date:2025-01-01,to_publication_date:2025-03-31';
s.openalex.per_page          = 25;
s.openalex.max_pages         = 1;
s.openalex.candidate_max_pages = 1;
s.openalex.max_rows_for_validation = 5;
s.openalex.sampling_mode     = 'head';
s.openalex.random_seed       = 42;
s.openalex.mailto            = '';
s.openalex.first_author_institution = '';
s.openalex.first_author_institution_id = '';
s.openalex.first_author_institution_ids = '';
s.openalex.first_author_institution_aliases = '';
s.openalex.first_author_filter_mode = 'direct';

jsonText = jsonencode(s, PrettyPrint=true);
fid = fopen(path, 'w', 'n', 'UTF-8');
fwrite(fid, char(jsonText), 'char');
fclose(fid);
end
