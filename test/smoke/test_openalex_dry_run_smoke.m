function test_openalex_dry_run_smoke()
%TEST_OPENALEX_DRY_RUN_SMOKE  M15 dryRun flag smoke test
%
%   addpath("src/openalex"); addpath("src/util"); addpath("test/smoke");
%   test_openalex_dry_run_smoke();
%
% Target: dryRun option of fetch_openalex_works.m
% What to verify:
%   Case 1: dryRun=true does not cause argument error (argument validation)
%   Case 2: When dryRun=true, meta struct has a total_count field
%   Case 3: When dryRun=true, returned table is empty (height=0)
%   Case 4: When filterCountryCode is non-empty, meta.filter contains country_code:
%
% Note: Case 2/3 calls the live OpenAlex API and requires network access.
%       Cases 2/3 are skipped when network is unavailable.

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', '..', 'src', 'openalex'));
addpath(fullfile(thisDir, '..', '..', 'src', 'util'));

%% Case 1: Passing dryRun=true does not cause argument error (verifiable offline)
% Wrap in try-catch so assertions only run when actual API call succeeds
try
    [tbl, m] = fetch_openalex_works( ...
        searchQuery="matlab", ...
        filter="is_oa:true,language:en,from_publication_date:2025-01-01,to_publication_date:2025-01-31", ...
        dryRun=true, ...
        perPage=50, ...
        maxPages=5);

    %% Case 2: meta struct contains a total_count field
    assert(isfield(m, 'total_count'), "Case2: meta に total_count フィールドがない");
    assert(isnumeric(m.total_count) || isinteger(m.total_count), ...
        "Case2: total_count が数値型でない");
    fprintf("[PASS] Case2: meta.total_count = %d\n", double(m.total_count));

    %% Case 3: Returned table is empty (dryRun does not fetch data)
    assert(height(tbl) == 0, "Case3: dryRun=true なのに worksTable が空でない (height=%d)", height(tbl));
    fprintf("[PASS] Case3: dryRun=true → 返却テーブルは空（height=0）\n");

catch apiEx
    if contains(apiEx.message, 'MATLAB:webservices') || contains(apiEx.message, 'urlread') ...
            || contains(apiEx.message, 'webread') || contains(apiEx.identifier, 'MATLAB:webread')
        fprintf("[SKIP] Case2/3: ネットワーク到達不可のためスキップ: %s\n", apiEx.message);
    else
        rethrow(apiEx);
    end
end

%% Case 4: When filterCountryCode is non-empty, meta.filter contains country_code:
% (Offline check: verify meta.filter string)
try
    [~, m4] = fetch_openalex_works( ...
        searchQuery="", ...
        filter="is_oa:true,from_publication_date:2025-01-01,to_publication_date:2025-01-05", ...
        filterCountryCode="JP", ...
        dryRun=true);
    assert(contains(m4.filter, "country_code:JP"), ...
        "Case4: filterCountryCode=JP なのに meta.filter に country_code:JP が含まれない");
    fprintf("[PASS] Case4: filterCountryCode=JP → meta.filter=%s\n", m4.filter);
catch c4Ex
    if contains(c4Ex.message, 'MATLAB:webservices') || contains(c4Ex.message, 'webread') ...
            || contains(c4Ex.identifier, 'MATLAB:webread')
        fprintf("[SKIP] Case4: ネットワーク到達不可のためスキップ\n");
    else
        rethrow(c4Ex);
    end
end

%% Case 5: Passing sort parameter does not cause argument error (Phase 6A L0-1)
try
    [~, m5] = fetch_openalex_works( ...
        searchQuery="matlab", ...
        filter="is_oa:true,from_publication_date:2025-01-01,to_publication_date:2025-01-07", ...
        sort="cited_by_count:desc", ...
        dryRun=true);
    assert(isfield(m5, 'total_count'), "Case5: meta に total_count フィールドがない");
    fprintf("[PASS] Case5: sort=cited_by_count:desc → 引数エラーなし total_count=%d\n", double(m5.total_count));
catch c5Ex
    if contains(c5Ex.message, 'MATLAB:webservices') || contains(c5Ex.message, 'webread') ...
            || contains(c5Ex.identifier, 'MATLAB:webread')
        fprintf("[SKIP] Case5: ネットワーク到達不可のためスキップ\n");
    else
        rethrow(c5Ex);
    end
end

fprintf("\nSmoke test passed: test_openalex_dry_run_smoke (M15)\n");
end
