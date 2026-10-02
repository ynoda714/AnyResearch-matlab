function test_search_limit_network_smoke()
%TEST_SEARCH_LIMIT_NETWORK_SMOKE  preview_search_count and run_pipeline's maxRecords against the live API.
%
%   The GUI asks OpenAlex for the number of matches before a search and caps the fetch at
%   Max records. This checks the two pipeline-side pieces.
%
%   Interfaces used (new):
%     preview = preview_search_count(query, fromDate, toDate, Name=Value ...)   % src/pipeline
%         the same filter-related options as run_pipeline (language, requireOpenAccess, requireAbstract,
%         filterCountryCode, filterType, citedByMin, citedByMax, firstAuthorInstitutionId, ...);
%         returns struct(total_hits (double), filter (string)); one API request; creates no run folder
%         and writes nothing under result/.
%     result = run_pipeline(..., maxRecords=N)    % default 1000 (what maxPages=10 gave); result.limit_reached
%
%   Needs an OpenAlex API key and network access; skipped without either. Costs a few credits.

thisDir = fileparts(mfilename("fullpath"));
projectRoot = fileparts(fileparts(thisDir));
addpath(fullfile(thisDir, ".."));
addpath(fullfile(projectRoot, "src", "pipeline"));

tempRoot = fullfile(tempdir, "anyresearch_limit_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss")));
mkdir(tempRoot);
cleanup = onCleanup(@() local_remove(tempRoot)); %#ok<NASGU>
runsRoot = fullfile(projectRoot, "result", "runs");

try
    %% Case 1: the preview matches the pipeline's own count and leaves no trace
    before = local_dirs(runsRoot);
    preview = preview_search_count("MATLAB Simulink", "2025-01-01", "2025-01-31", language="en");
    after = local_dirs(runsRoot);
    assert(isequal(before, after), "Case1: the preview must not create anything under result/runs");
    assert(isscalar(preview.total_hits) && preview.total_hits > 0, "Case1: expected a positive count");
    assert(contains(preview.filter, "from_publication_date:2025-01-01"), "Case1: filter was '%s'", preview.filter);
    fprintf("[PASS] Case1: preview_search_count -> %d matches, no run folder\n", preview.total_hits);

    %% Case 2: maxRecords caps the fetch exactly and reports it
    limit = 120;
    assert(preview.total_hits > limit, "Case2: the test query must match more than %d works (matched %d)", limit, preview.total_hits);
    r = run_pipeline("MATLAB Simulink", "2025-01-01", "2025-01-31", language="en", ...
        sortBy="cited_by_count:desc", maxRecords=limit, runRootDir=tempRoot, ...
        saveRawResponses=false, enablePdfDownload=false);
    assert(double(r.rows_fetched) == limit, "Case2: rows_fetched was %d, expected exactly %d", r.rows_fetched, limit);
    assert(isfield(r, "limit_reached") && r.limit_reached, "Case2: limit_reached must be true");
    assert(abs(double(r.total_hits) - double(preview.total_hits)) <= max(5, 0.05 * double(preview.total_hits)), ...
        "Case2: total_hits %d vs preview %d", r.total_hits, preview.total_hits);
    assert(issorted(r.T.cited_by_count, "descend"), "Case2: the cap must keep the requested sort (top works first)");
    fprintf("[PASS] Case2: maxRecords=%d -> %d rows, limit_reached, still sorted\n", limit, r.rows_fetched);

    %% Case 3: matches within the limit are all fetched and not flagged
    % Not 01-01..01-03: OpenAlex files many works without a known date under January 1st (1,368 matches
    % on 2025-01-01 alone), so that range exceeds 1,000. A mid-month range stays small.
    smallFrom = "2025-01-15";
    smallTo = "2025-01-17";
    smallPreview = preview_search_count("MATLAB Simulink", smallFrom, smallTo, language="en");
    assert(smallPreview.total_hits > 0 && smallPreview.total_hits <= 900, ...
        "Case3: the test range must match 1..900 works (matched %d); pick another range", smallPreview.total_hits);
    r3 = run_pipeline("MATLAB Simulink", smallFrom, smallTo, language="en", ...
        maxRecords=1000, runRootDir=tempRoot, saveRawResponses=false, enablePdfDownload=false);
    assert(isfield(r3, "limit_reached") && ~r3.limit_reached, "Case3: limit_reached must be false");
    assert(abs(double(r3.rows_fetched) - double(r3.total_hits)) <= max(2, 0.05 * double(r3.total_hits)), ...
        "Case3: fetched %d of %d", r3.rows_fetched, r3.total_hits);
    fprintf("[PASS] Case3: all %d matches fetched, not flagged\n", r3.rows_fetched);

    fprintf("Smoke test passed: preview_search_count and maxRecords\n");
catch ex
    if is_network_error(ex)
        fprintf("[SKIP] Network unreachable: %s\n", ex.message);
    elseif any(strcmp(ex.identifier, ["run_pipeline:NoApiKey", "openalex:NoApiKey"]))
        fprintf("[SKIP] No OpenAlex API key configured\n");
    else
        rethrow(ex);
    end
end
end

function names = local_dirs(root)
names = strings(0, 1);
if isfolder(root)
    d = dir(root);
    names = sort(string({d([d.isdir]).name}));
    names = names(~ismember(names, [".", ".."]));
end
end

function local_remove(folder)
if isfolder(folder)
    rmdir(folder, "s");
end
end
