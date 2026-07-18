function test_openalex_empty_query_smoke()
%TEST_OPENALEX_EMPTY_QUERY_SMOKE  M15 query="" filter-only mode smoke test
%
%   addpath("src/openalex"); addpath("src/util"); addpath("test/smoke");
%   test_openalex_empty_query_smoke();
%
% Target: fetch_openalex_works.m behavior when searchQuery=""
% What to verify:
%   Case 1: query="" does not cause argument error (offline check)
%   Case 2: When query="", meta.search_query is ""
%   Case 3: query="" + dryRun=true returns meta.total_count (live API)
%   Case 4: When query="matlab", meta.search_query is "matlab"
%
% Note: Case 3 calls the live OpenAlex API and requires network access.

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', '..', 'src', 'openalex'));
addpath(fullfile(thisDir, '..', '..', 'src', 'util'));

%% Case 1 & 2: meta.search_query is "" when query="" (live API)
try
    [~, m12] = fetch_openalex_works( ...
        searchQuery="", ...
        filter="is_oa:true,language:en,from_publication_date:2025-01-01,to_publication_date:2025-01-02", ...
        dryRun=true);

    %% Case 2: Verify that meta.search_query is ""
    assert(m12.search_query == "", ...
        sprintf("Case2: query='' なのに meta.search_query='%s'", m12.search_query));
    fprintf("[PASS] Case2: query='' → meta.search_query=''\n");

    %% Case 3: total_count returns a non-negative integer
    assert(isfield(m12, 'total_count'), "Case3: meta に total_count がない");
    assert(double(m12.total_count) >= 0, "Case3: total_count が負");
    fprintf("[PASS] Case3: query='' → total_count=%d （filter-only 取得成功）\n", double(m12.total_count));

catch apiEx
    if contains(apiEx.message, 'MATLAB:webservices') || contains(apiEx.message, 'webread') ...
            || contains(apiEx.identifier, 'MATLAB:webread')
        fprintf("[SKIP] Case2/3: ネットワーク到達不可のためスキップ: %s\n", apiEx.message);
    else
        rethrow(apiEx);
    end
end

%% Case 4: When query="matlab", meta.search_query is "matlab"
try
    [~, m4] = fetch_openalex_works( ...
        searchQuery="matlab", ...
        filter="is_oa:true,language:en,from_publication_date:2025-01-01,to_publication_date:2025-01-02", ...
        dryRun=true);
    assert(m4.search_query == "matlab", ...
        sprintf("Case4: query='matlab' なのに meta.search_query='%s'", m4.search_query));
    fprintf("[PASS] Case4: query='matlab' → meta.search_query='matlab'\n");
catch c4Ex
    if contains(c4Ex.message, 'MATLAB:webservices') || contains(c4Ex.message, 'webread') ...
            || contains(c4Ex.identifier, 'MATLAB:webread')
        fprintf("[SKIP] Case4: ネットワーク到達不可のためスキップ\n");
    else
        rethrow(c4Ex);
    end
end

fprintf("\nSmoke test passed: test_openalex_empty_query_smoke (M15)\n");
end
