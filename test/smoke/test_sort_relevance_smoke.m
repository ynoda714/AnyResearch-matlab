function test_sort_relevance_smoke()
%TEST_SORT_RELEVANCE_SMOKE  sort="relevance_score" must reach OpenAlex as relevance_score:desc (network).
%
%   OpenAlex rejects plain "relevance_score" (ascending) with HTTP 400. Also verifies that the
%   error message of a failing request does not contain the API key.

thisDir = fileparts(mfilename('fullpath'));
root = fullfile(thisDir, '..', '..');
addpath(fullfile(root, 'src', 'openalex'));
addpath(fullfile(root, 'src', 'config'));
addpath(fullfile(root, 'src', 'adapters'));
addpath(fullfile(root, 'src', 'util'));

apiKey = load_openalex_api_key(fullfile(root, 'config', 'settings.json'), false);
if apiKey == ""
    fprintf("[SKIP] test_sort_relevance_smoke: no API key configured\n");
    return;
end

filter = "from_publication_date:2025-01-01,to_publication_date:2025-01-03,is_retracted:false,language:en";

% Case 1: relevance_score sort succeeds
[tbl, ~] = fetch_openalex_works(searchQuery="MATLAB Simulink", filter=filter, ...
    perPage=3, maxPages=1, apiKey=apiKey, sort="relevance_score");
assert(height(tbl) > 0, 'Case1: relevance_score sort returned no rows');
fprintf("[PASS] Case1: sort=relevance_score is accepted (%d rows)\n", height(tbl));

% Case 2: a failing request does not leak the API key
try
    fetch_openalex_works(searchQuery="x", filter="bogus_filter:1", perPage=1, maxPages=1, apiKey=apiKey);
    error('test_sort_relevance:NoError', 'Case2: expected the bogus filter to be rejected');
catch ex
    assert(~strcmp(ex.identifier, 'test_sort_relevance:NoError'), '%s', ex.message);
    assert(~contains(string(ex.message), apiKey), 'Case2: API key leaked in the error message');
end
fprintf("[PASS] Case2: error message does not contain the API key\n");
end
