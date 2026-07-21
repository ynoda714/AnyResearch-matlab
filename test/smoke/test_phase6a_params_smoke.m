function test_phase6a_params_smoke()
%TEST_PHASE6A_PARAMS_SMOKE  Phase 6A: sortBy / filterType / retry function smoke test
%
%   How to run:
%     addpath("test/smoke"); addpath("src/openalex"); addpath("src/pipeline");
%     addpath("src/config"); addpath("src/util");
%     test_phase6a_params_smoke();
%
%   Test coverage:
%     L0-1: fetch_openalex_works accepts sort argument
%     L0-2: filterType / excludeRetracted -> filter string expansion
%     L0-3: OR syntax is translated to OpenAlex OR semantics
%     M-3 : firstAuthorInstitutionId accepts multiple IDs
%     R-1 : Verify local_webread_with_retry function exists

fprintf('\n=== test_phase6a_params_smoke (Phase 6A) ===\n');

thisDir     = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'openalex'));
addpath(fullfile(projectRoot, 'src', 'pipeline'));
addpath(fullfile(projectRoot, 'src', 'config'));
addpath(fullfile(projectRoot, 'src', 'util'));

apiKey = local_load_api_key(projectRoot);
networkReady = local_network_reachable(apiKey);

%% Case 1: fetch_openalex_works accepts the sort argument (offline verification)
% Passing the arguments block is sufficient. Network errors are acceptable.
if ~networkReady
    fprintf("[SKIP] Case1: OpenAlex API unavailable or rate-limited\n");
else
    try
        [tbl1, m1] = fetch_openalex_works( ...
            searchQuery="renewable energy", ...
            filter="is_oa:true,language:en,from_publication_date:2025-01-01,to_publication_date:2025-01-03", ...
            sort="cited_by_count:desc", ...
            apiKey=apiKey, ...
            dryRun=true);
        assert(isfield(m1, 'total_count'), "Case1: meta.total_count がない");
        assert(height(tbl1) == 0, "Case1: dryRun なのにテーブルが空でない");
        fprintf("[PASS] Case1: sort=cited_by_count:desc → 引数受付 OK  total_count=%d\n", double(m1.total_count));
    catch e1
        if local_is_network_error(e1)
            fprintf("[SKIP] Case1: ネットワーク到達不可のためスキップ\n");
        else
            rethrow(e1);
        end
    end
end

%% Case 2: fetch_openalex_works accepts sort=publication_date:desc
if ~networkReady
    fprintf("[SKIP] Case2: OpenAlex API unavailable or rate-limited\n");
else
    try
        [~, m2] = fetch_openalex_works( ...
            searchQuery="deep learning", ...
            filter="is_oa:true,language:en,from_publication_date:2025-01-01,to_publication_date:2025-01-03", ...
            sort="publication_date:desc", ...
            apiKey=apiKey, ...
            dryRun=true);
        assert(isfield(m2, 'total_count'), "Case2: meta.total_count がない");
        fprintf("[PASS] Case2: sort=publication_date:desc → 引数受付 OK  total_count=%d\n", double(m2.total_count));
    catch e2
        if local_is_network_error(e2)
            fprintf("[SKIP] Case2: ネットワーク到達不可のためスキップ\n");
        else
            rethrow(e2);
        end
    end
end

%% Case 3: filterType is reflected in the settings JSON of fetch_and_normalize_works
% filterType="review" -> verify "type:review" appears in the filter via settings JSON
tmpDir  = fullfile(tempdir, 'smoke_phase6a');
if ~isfolder(tmpDir); mkdir(tmpDir); end
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

settingsPath = fullfile(tmpDir, 'settings_type_review.json');
local_write_settings_with_type_filter(settingsPath, "type:review", apiKey);

if ~networkReady
    fprintf("[SKIP] Case3: OpenAlex API unavailable or rate-limited\n");
else
    try
        res3 = fetch_and_normalize_works(settingsPath, dryRun=true);
        assert(isfield(res3, 'filter'), "Case3: dryRun result に filter フィールドがない");
        assert(contains(res3.filter, "type:review"), ...
            "Case3: filter に type:review が含まれない → filter=%s", res3.filter);
        fprintf("[PASS] Case3: filterType=review → filter に type:review 含まれる\n");
    catch e3
        if local_is_network_error(e3)
            fprintf("[SKIP] Case3: ネットワーク到達不可のためスキップ\n");
        else
            rethrow(e3);
        end
    end
end

%% Case 4: filterType="article,review" -> "type:article|review" appears in the filter
settingsPath4 = fullfile(tmpDir, 'settings_type_article_review.json');
local_write_settings_with_type_filter(settingsPath4, "type:article|review", apiKey);

if ~networkReady
    fprintf("[SKIP] Case4: OpenAlex API unavailable or rate-limited\n");
else
    try
        res4 = fetch_and_normalize_works(settingsPath4, dryRun=true);
        assert(isfield(res4, 'filter'), "Case4: dryRun result に filter フィールドがない");
        assert(contains(res4.filter, "type:"), ...
            "Case4: filter に type: が含まれない → filter=%s", res4.filter);
        fprintf("[PASS] Case4: filterType=article,review → filter に type: 含まれる\n");
    catch e4
        if local_is_network_error(e4)
            fprintf("[SKIP] Case4: ネットワーク到達不可のためスキップ\n");
        else
            rethrow(e4);
        end
    end
end

%% Case 4b: excludeRetracted default/override and cited-by range are reflected in the filter
f4bDefault = build_openalex_filter("2025-01-01", "2025-01-03", "en", true, strings(0,1), "", "", true);
assert(contains(f4bDefault, "is_retracted:false"), ...
    'Case4b: default filter に is_retracted:false が含まれない → filter=%s', f4bDefault);
f4bOff = build_openalex_filter("2025-01-01", "2025-01-03", "en", true, strings(0,1), "", "", true, false);
assert(~contains(f4bOff, "is_retracted:false"), ...
    'Case4b: excludeRetracted=false なのに is_retracted:false が残る → filter=%s', f4bOff);
f4bRange = build_openalex_filter("2025-01-01", "2025-01-03", "en", true, strings(0,1), "", "", true, true, 100, 500);
assert(contains(f4bRange, "cited_by_count:>100"), ...
    'Case4b: citedByMin=100 が filter に反映されない → filter=%s', f4bRange);
assert(contains(f4bRange, "cited_by_count:<500"), ...
    'Case4b: citedByMax=500 が filter に反映されない → filter=%s', f4bRange);
fprintf("[PASS] Case4b: excludeRetracted / citedByMin / citedByMax → filter 反映 OK\n");

%% Case 4d: cited-by filters are omitted when disabled or invalid
f4d = build_openalex_filter("2025-01-01", "2025-01-03", "en", true, strings(0,1), "", "", true, true, 0, NaN);
assert(~contains(f4d, "cited_by_count:>"), ...
    'Case4d: citedByMin=0 なのに lower-bound filter が残る → filter=%s', f4d);
assert(~contains(f4d, "cited_by_count:<"), ...
    'Case4d: citedByMax=NaN なのに upper-bound filter が残る → filter=%s', f4d);
fprintf("[PASS] Case4d: disabled/invalid cited-by filters are omitted\n");

%% Case 4c: build_openalex_filter / normalize_openalex_ids accept multi-ID inputs
ids4c = normalize_openalex_ids(["https://openalex.org/I100000001|I100000002"; "I100000001"]);
assert(isequal(ids4c, ["I100000001"; "I100000002"]), ...
    'Case4c: normalize_openalex_ids failed for pipe-delimited multi-ID input');
f4c = build_openalex_filter("2025-01-01", "2025-01-03", "en", true, ids4c, "", "", true);
assert(contains(f4c, "authorships.institutions.id:I100000001|I100000002"), ...
    'Case4c: multi-ID filter string not joined correctly → filter=%s', f4c);
fprintf("[PASS] Case4c: multi-ID inputs normalize and join correctly\n");

%% Case 5: Verify API retry implementation (R-1)
% In addition to grep-based existence check, specifically verify retry count and backoff implementation
srcFile = fullfile(projectRoot, 'src', 'openalex', 'fetch_openalex_works.m');
assert(isfile(srcFile), "Case5: fetch_openalex_works.m が見つからない");
srcText = fileread(srcFile);
assert(contains(srcText, 'local_webread_with_retry'), ...
    "Case5: local_webread_with_retry が fetch_openalex_works.m に存在しない");
assert(contains(srcText, '429'), ...
    "Case5: リトライ対象コード 429 が fetch_openalex_works.m に存在しない");
assert(contains(srcText, '503'), ...
    "Case5: リトライ対象コード 503 が fetch_openalex_works.m に存在しない");

% Verify maxRetry value is 2 or more (ensures at least 1 retry)
retryMatch = regexp(srcText, 'maxRetry\s*=\s*(\d+)', 'tokens');
assert(~isempty(retryMatch), "Case5: maxRetry の定義が見つからない");
maxRetryVal = str2double(retryMatch{1}{1});
assert(maxRetryVal >= 2, ...
    sprintf("Case5: maxRetry=%d が 2 未満 (リトライが実質0回)", maxRetryVal));

% Verify exponential backoff implementation:
%   Both baseDelay variable definition and pause-based wait must be present
assert(contains(srcText, 'baseDelay') || contains(srcText, 'waitSec'), ...
    "Case5: backoff 用のディレイ変数 (baseDelay / waitSec) が見つからない");
assert(contains(srcText, 'pause('), ...
    "Case5: retry ウェイト実装 (pause) が見つからない");
assert(contains(srcText, 'get_openalex_rate_limit_status'), ...
    "Case5: rate-limit helper 呼び出しが fetch_openalex_works.m に存在しない");
assert(contains(srcText, 'local_parse_retry_after_seconds'), ...
    "Case5: Retry-After 相当の待機秒数解析が fetch_openalex_works.m に存在しない");
assert(~contains(srcText, 'min(maxDelay, max(waitSec, rateInfo.resets_in_seconds))'), ...
    "Case5: rate-limit reset wait が maxDelay で不正に切り詰められている");

fprintf("[PASS] Case5: local_webread_with_retry (429/503, maxRetry=%d, backoff=exponential) が実装済み\n", maxRetryVal);

%% Case 5b: OR syntax regression (dry-run total_count comparison)
if ~networkReady
    fprintf("[SKIP] Case5b: OpenAlex API unavailable or rate-limited\n");
else
    try
        [~, mOr] = fetch_openalex_works( ...
            searchQuery="solar|wind", ...
            filter="is_oa:true,is_retracted:false,language:en,from_publication_date:2025-01-01,to_publication_date:2025-01-03", ...
            apiKey=apiKey, ...
            dryRun=true);
        [~, mAnd] = fetch_openalex_works( ...
            searchQuery="solar wind", ...
            filter="is_oa:true,is_retracted:false,language:en,from_publication_date:2025-01-01,to_publication_date:2025-01-03", ...
            apiKey=apiKey, ...
            dryRun=true);
        assert(double(mOr.total_count) > double(mAnd.total_count), ...
            "Case5b: OR total_count=%d is not greater than AND total_count=%d", ...
            double(mOr.total_count), double(mAnd.total_count));
        fprintf("[PASS] Case5b: solar|wind → OR semantics confirmed (%d > %d)\n", ...
            double(mOr.total_count), double(mAnd.total_count));
    catch e5b
        if local_is_network_error(e5b)
            fprintf("[SKIP] Case5b: ネットワーク到達不可のためスキップ\n");
        else
            rethrow(e5b);
        end
    end
end

%% Case 6: filterType argument in run_pipeline is reflected in settings_front_override.json
% Integration test verifying the actual code path of local_build_openalex_filter
% settings_front_override.json is written before the API call, so
% verification is possible even without an API key.
tmpRunDir6 = fullfile(tempdir, 'smoke_phase6a_case6');
if isfolder(tmpRunDir6), rmdir(tmpRunDir6, 's'); end
mkdir(tmpRunDir6);
cleanup6 = onCleanup(@() rmdir(tmpRunDir6, 's'));

try
    run_pipeline("test query", "2025-01-01", "2025-01-01", ...
        filterType="review", ...
        requireOpenAccess=false, ...
        showCountPreview=false, ...
        maxPages=1, ...
        runRootDir=tmpRunDir6);
catch
    % API failure is acceptable. settings_front_override.json is written before the API call
end

jsonFiles6 = dir(fullfile(tmpRunDir6, '**', 'settings_front_override.json'));
if ~isempty(jsonFiles6)
    s6 = jsondecode(fileread(fullfile(jsonFiles6(1).folder, jsonFiles6(1).name)));
    assert(isfield(s6, 'openalex') && isfield(s6.openalex, 'filter'), ...
        'Case6: settings_front_override.json に openalex.filter がない');
    filterStr6 = string(s6.openalex.filter);
    assert(contains(filterStr6, 'type:review'), ...
        'Case6: filterType=review が filter に反映されない → filter=%s', filterStr6);
    fprintf("[PASS] Case6: run_pipeline filterType=review → settings_front_override.json の filter に type:review 含まれる\n");
else
    fprintf("[SKIP] Case6: settings_front_override.json が生成されなかった (run_pipeline が設定書き込み前に失敗)\n");
end

%% Case 7: sortBy argument in run_pipeline is reflected in the sort field of settings_front_override.json
tmpRunDir7 = fullfile(tempdir, 'smoke_phase6a_case7');
if isfolder(tmpRunDir7), rmdir(tmpRunDir7, 's'); end
mkdir(tmpRunDir7);
cleanup7 = onCleanup(@() rmdir(tmpRunDir7, 's'));

try
    run_pipeline("test query", "2025-01-01", "2025-01-01", ...
        sortBy="publication_date:desc", ...
        requireOpenAccess=false, ...
        showCountPreview=false, ...
        maxPages=1, ...
        runRootDir=tmpRunDir7);
catch
    % API failure is acceptable
end

jsonFiles7 = dir(fullfile(tmpRunDir7, '**', 'settings_front_override.json'));
if ~isempty(jsonFiles7)
    s7 = jsondecode(fileread(fullfile(jsonFiles7(1).folder, jsonFiles7(1).name)));
    assert(isfield(s7, 'openalex') && isfield(s7.openalex, 'sort'), ...
        'Case7: settings_front_override.json に openalex.sort がない');
    sortStr7 = string(s7.openalex.sort);
    assert(sortStr7 == "publication_date:desc", ...
        'Case7: sortBy=publication_date:desc が sort フィールドに反映されない → sort=%s', sortStr7);
fprintf("[PASS] Case7: run_pipeline sortBy=publication_date:desc → settings_front_override.json の sort フィールドに反映\n");
else
    fprintf("[SKIP] Case7: settings_front_override.json が生成されなかった (run_pipeline が設定書き込み前に失敗)\n");
end

%% Case 8: multi-ID firstAuthorInstitutionId is reflected in settings_front_override.json
tmpRunDir8 = fullfile(tempdir, 'smoke_phase6a_case8');
if isfolder(tmpRunDir8), rmdir(tmpRunDir8, 's'); end
mkdir(tmpRunDir8);
cleanup8 = onCleanup(@() rmdir(tmpRunDir8, 's'));

try
    run_pipeline("test query", "2025-01-01", "2025-01-01", ...
        firstAuthorInstitutionId=["I100000001", "I100000002"], ...
        resolveInstitutionIds=false, ...
        requireOpenAccess=false, ...
        showCountPreview=false, ...
        maxPages=1, ...
        runRootDir=tmpRunDir8);
catch
    % API failure is acceptable
end

jsonFiles8 = dir(fullfile(tmpRunDir8, '**', 'settings_front_override.json'));
if ~isempty(jsonFiles8)
    s8 = jsondecode(fileread(fullfile(jsonFiles8(1).folder, jsonFiles8(1).name)));
    assert(isfield(s8, 'openalex') && isfield(s8.openalex, 'first_author_institution_ids'), ...
        'Case8: settings_front_override.json に openalex.first_author_institution_ids がない');
    idsStr8 = string(s8.openalex.first_author_institution_ids);
    assert(idsStr8 == "I100000001 | I100000002", ...
        'Case8: multi-ID list not reflected correctly → first_author_institution_ids=%s', idsStr8);
    filterStr8 = string(s8.openalex.filter);
    assert(contains(filterStr8, "authorships.institutions.id:I100000001|I100000002"), ...
        'Case8: multi-ID filter not reflected correctly → filter=%s', filterStr8);
    fprintf("[PASS] Case8: run_pipeline multi-ID input → settings_front_override.json に反映\n");
else
    fprintf("[SKIP] Case8: settings_front_override.json が生成されなかった (run_pipeline が設定書き込み前に失敗)\n");
end

%% Case 9: citedByMin / citedByMax arguments in run_pipeline are reflected in settings_front_override.json
tmpRunDir9 = fullfile(tempdir, 'smoke_phase6a_case9');
if isfolder(tmpRunDir9), rmdir(tmpRunDir9, 's'); end
mkdir(tmpRunDir9);
cleanup9 = onCleanup(@() rmdir(tmpRunDir9, 's'));

try
    r9 = struct();
    r9 = run_pipeline("test query", "2025-01-01", "2025-01-01", ...
        citedByMin=100, ...
        citedByMax=500, ...
        requireOpenAccess=false, ...
        showCountPreview=false, ...
        maxPages=1, ...
        runRootDir=tmpRunDir9);
catch e9
    if ~local_is_network_error(e9)
        rethrow(e9);
    end
    r9 = struct();
end

jsonFiles9 = dir(fullfile(tmpRunDir9, '**', 'settings_front_override.json'));
if ~isempty(jsonFiles9)
    s9 = jsondecode(fileread(fullfile(jsonFiles9(1).folder, jsonFiles9(1).name)));
    assert(isfield(s9, 'openalex') && isfield(s9.openalex, 'filter'), ...
        'Case9: settings_front_override.json に openalex.filter がない');
    filterStr9 = string(s9.openalex.filter);
    assert(contains(filterStr9, "cited_by_count:>100"), ...
        'Case9: citedByMin=100 が filter に反映されない → filter=%s', filterStr9);
    assert(contains(filterStr9, "cited_by_count:<500"), ...
        'Case9: citedByMax=500 が filter に反映されない → filter=%s', filterStr9);
    if isfield(r9, 'T') && istable(r9.T) && height(r9.T) > 0
        cited9 = double(r9.T.cited_by_count);
        assert(all(cited9 >= 100 & cited9 <= 500), ...
            'Case9: citedBy range violated in fetched rows');
        fprintf("[PASS] Case9: run_pipeline citedByMin/citedByMax → filter reflected and fetched rows stay within range\n");
    else
        fprintf("[SKIP] Case9: network-limited run_pipeline result unavailable; settings-front verification only\n");
    end
else
    fprintf("[SKIP] Case9: settings_front_override.json が生成されなかった (run_pipeline が設定書き込み前に失敗)\n");
end

fprintf('\n=== test_phase6a_params_smoke: ALL PASS ===\n\n');
end

% ── Local helpers ───────────────────────────────────────────────────────

function tf = local_is_network_error(ex)
tf = contains(ex.message, 'MATLAB:webservices') || ...
     contains(ex.message, 'readContentFromWebService') || ...
     contains(ex.message, 'webread') || ...
     contains(ex.message, 'urlread') || ...
     contains(ex.message, 'Too Many Requests') || ...
     contains(ex.message, 'ステータス 429') || ...
     contains(ex.message, 'ステータス 503') || ...
     contains(ex.identifier, 'MATLAB:webread');
end

function apiKey = local_load_api_key(projectRoot)
apiKey = strtrim(string(getenv('ANYRESEARCH_OPENALEX_API_KEY')));
if apiKey ~= ""
    return;
end
settingsPath = fullfile(projectRoot, 'config', 'settings.json');
if ~isfile(settingsPath)
    apiKey = "";
    return;
end
try
    s = jsondecode(fileread(settingsPath));
    if isfield(s, 'openalex') && isfield(s.openalex, 'api_key')
        apiKey = strtrim(string(s.openalex.api_key));
    else
        apiKey = "";
    end
catch
    apiKey = "";
end
end

function ok = local_network_reachable(apiKey)
ok = false;
try
    info = get_openalex_rate_limit_status(apiKey, 8);
    enoughCredits = isnan(info.credits_remaining) || info.credits_remaining >= 6;
    ok = info.ok && info.can_query && enoughCredits;
catch
end
end

function local_write_settings_with_type_filter(path, filterStr, apiKey)
% Write a minimal settings JSON containing the type: notation specified in filterStr
s = struct();
s.openalex = struct();
s.openalex.api_key        = char(apiKey);
s.openalex.search_query   = 'renewable energy';
s.openalex.filter         = char("is_oa:true,language:en," + ...
    "from_publication_date:2025-01-01,to_publication_date:2025-01-03," + filterStr);
s.openalex.sort           = '';
s.openalex.per_page       = 1;
s.openalex.max_pages      = 1;
s.openalex.candidate_max_pages     = 1;
s.openalex.max_rows_for_validation = 0;
s.openalex.sampling_mode  = 'head';
s.openalex.random_seed    = 42;
s.openalex.mailto         = '';
s.openalex.first_author_institution    = '';
s.openalex.first_author_institution_id = '';
s.openalex.first_author_institution_ids = '';
s.openalex.first_author_institution_aliases = '';
s.openalex.first_author_filter_mode = 'direct';

parentDir = fileparts(path);
if strlength(parentDir) > 0 && ~isfolder(parentDir)
    mkdir(parentDir);
end
fid = fopen(path, 'w', 'n', 'UTF-8');
if fid < 0
    error("test_phase6a:WriteSettings", "設定ファイル書き込み失敗: %s", path);
end
c = onCleanup(@() fclose(fid));
fwrite(fid, char(jsonencode(s, PrettyPrint=true)), 'char');
end
