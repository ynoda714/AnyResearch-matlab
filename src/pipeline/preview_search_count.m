function preview = preview_search_count(query, fromDate, toDate, options)
%PREVIEW_SEARCH_COUNT  Return the OpenAlex match count without creating run artifacts.
%
%   PREVIEW = PREVIEW_SEARCH_COUNT(QUERY, FROMDATE, TODATE, Name=Value)
%   performs one OpenAlex request using the same filter builder as run_pipeline.

arguments
    query    (1,1) string
    fromDate (1,1) string = ""
    toDate   (1,1) string = ""
    options.language                   (1,1) string = "en"
    options.requireOpenAccess          (1,1) logical = true
    options.requireAbstract            (1,1) logical = true
    options.filterCountryCode          (1,1) string = ""
    options.filterType                 (1,1) string = ""
    options.excludeRetracted           (1,1) logical = true
    options.citedByMin                 (1,1) double = 0
    options.citedByMax                 (1,1) double = 0
    options.firstAuthorInstitution     (1,1) string = ""
    options.firstAuthorInstitutionId           string = strings(0,1)
    options.firstAuthorInstitutionAliases      string = strings(0,1)
    options.sortBy                     (1,1) string = ""
end

thisDir = fileparts(mfilename('fullpath'));
srcDir = fileparts(thisDir);
projectRoot = fileparts(srcDir);
addpath(fullfile(srcDir, 'openalex'));
addpath(fullfile(srcDir, 'config'));
addpath(fullfile(srcDir, 'util'));

institutionIds = normalize_openalex_ids(options.firstAuthorInstitutionId);
filterText = build_openalex_filter(fromDate, toDate, options.language, ...
    options.requireOpenAccess, institutionIds, options.filterCountryCode, ...
    options.filterType, options.requireAbstract, options.excludeRetracted, ...
    options.citedByMin, options.citedByMax);
apiKey = load_openalex_api_key(fullfile(projectRoot, 'config', 'settings.json'), true);
[~, meta] = fetch_openalex_works(searchQuery=query, filter=filterText, ...
    perPage=1, maxPages=1, apiKey=apiKey, sort=options.sortBy, ...
    dryRun=true, saveRawResponses=false);

preview = struct('total_hits', double(meta.total_count), 'filter', string(filterText));
end
