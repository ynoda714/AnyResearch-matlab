function test_snowball_smoke()
%TEST_SNOWBALL_SMOKE  K-4 snowball traversal smoke test.
fprintf('\n=== test_snowball_smoke ===\n');

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'openalex'));
addpath(fullfile(projectRoot, 'src', 'pipeline'));
addpath(fullfile(projectRoot, 'src', 'config'));
addpath(fullfile(projectRoot, 'src', 'adapters'));
addpath(fullfile(projectRoot, 'src', 'util'));

apiKey = local_load_api_key(projectRoot);
if apiKey == ""
    fprintf('[SKIP] OpenAlex API key is not configured.\n');
    fprintf('=== test_snowball_smoke: SKIPPED ===\n\n');
    return;
end
if ~local_network_reachable(apiKey)
    fprintf('[SKIP] OpenAlex API is unreachable or rate-limited.\n');
    fprintf('=== test_snowball_smoke: SKIPPED ===\n\n');
    return;
end

seedDoi = "10.1021/ci034243x";
tmpDir = fullfile(tempdir, 'snowball_smoke_anyresearch');
if isfolder(tmpDir)
    rmdir(tmpDir, 's');
end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

try
    [tbl1, meta1] = fetch_citing_works( ...
        seedId=seedDoi, ...
        filter="is_oa:true,language:en,is_retracted:false", ...
        sort="cited_by_count:desc", ...
        perPage=10, ...
        maxPages=1, ...
        apiKey=apiKey, ...
        saveRawResponses=true, ...
        rawResponseDir=fullfile(tmpDir, 'citing_raw'));

    assert(isfield(meta1, 'seed_work_id') && startsWith(string(meta1.seed_work_id), "w"), ...
        'Case1: seed_work_id was not resolved');
    assert(height(tbl1) >= 1, 'Case1: citing works must return at least 1 row');
    assert(all(tbl1.cited_by_count >= 0 | isnan(tbl1.cited_by_count)), ...
        'Case1: cited_by_count must be numeric');
    assert(isfile(fullfile(tmpDir, 'citing_raw', 'citing_seed.json')), ...
        'Case1: citing seed raw JSON was not saved');
    fprintf('[PASS] Case1: fetch_citing_works rows=%d seed=%s\n', height(tbl1), meta1.seed_work_id);

    [tbl2, meta2] = fetch_referenced_works( ...
        seedId=seedDoi, ...
        filter="is_retracted:false,cited_by_count:>4", ...
        apiKey=apiKey, ...
        saveRawResponses=true, ...
        rawResponseDir=fullfile(tmpDir, 'referenced_raw'));

    assert(isfield(meta2, 'referenced_ids_count') && double(meta2.referenced_ids_count) >= height(tbl2), ...
        'Case2: referenced_ids_count must be present and >= returned rows');
    if height(tbl2) > 0
        assert(all(tbl2.cited_by_count >= 5 | isnan(tbl2.cited_by_count)), ...
            'Case2: citedByMin filter was not reflected in referenced fetch');
    end
    assert(isfile(fullfile(tmpDir, 'referenced_raw', 'referenced_seed.json')), ...
        'Case2: referenced seed raw JSON was not saved');
    fprintf('[PASS] Case2: fetch_referenced_works rows=%d refs=%d\n', height(tbl2), double(meta2.referenced_ids_count));

    runRoot = fullfile(tmpDir, 'runs');
    r = run_pipeline("", "", "", ...
        seedId=seedDoi, ...
        snowballMode="citing", ...
        language="en", ...
        requireOpenAccess=true, ...
        citedByMin=5, ...
        filterCountryCode="", ...
        showCountPreview=false, ...
        enablePdfDownload=false, ...
        useArxiv=false, ...
        runRootDir=runRoot, ...
        saveRawResponses=true);
    assert(isfield(r, 'T') && istable(r.T) && height(r.T) >= 1, ...
        'Case3: run_pipeline seed mode must return result.T');
    assert(isfile(fullfile(r.run_dir, 'search_results.xlsx')), ...
        'Case3: run_pipeline seed mode must generate xlsx');
    fprintf('[PASS] Case3: run_pipeline snowball xlsx generated rows=%d\n', height(r.T));

catch ex
    if local_is_network_error(ex)
        fprintf('[SKIP] Snowball API test skipped due to network/rate-limit error: %s\n', ex.message);
        fprintf('=== test_snowball_smoke: SKIPPED ===\n\n');
        return;
    end
    rethrow(ex);
end

fprintf('=== test_snowball_smoke: ALL PASS ===\n\n');
end

function tf = local_is_network_error(ex)
msg = string(ex.message);
idf = string(ex.identifier);
tf = contains(msg, "429") || contains(msg, "503") || contains(msg, "Too Many Requests") || ...
    contains(msg, "Service Unavailable") || contains(msg, "webread") || contains(msg, "urlread") || ...
    contains(msg, "readContentFromWebService") || contains(idf, "MATLAB:webread");
end

function apiKey = local_load_api_key(projectRoot)
apiKey = strtrim(string(getenv('ANYRESEARCH_OPENALEX_API_KEY')));
if apiKey ~= ""
    return;
end
settingsFile = fullfile(projectRoot, 'config', 'settings.json');
if ~isfile(settingsFile)
    apiKey = "";
    return;
end
try
    s = jsondecode(fileread(settingsFile));
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
    enoughCredits = isnan(info.credits_remaining) || info.credits_remaining >= 4;
    ok = info.ok && info.can_query && enoughCredits;
catch
end
end
