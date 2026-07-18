function [worksTable, meta] = fetch_citing_works(opts)
%FETCH_CITING_WORKS Fetch works that cite a seed work.
arguments
    opts.seedId (1,1) string
    opts.filter (1,1) string = ""
    opts.perPage (1,1) double {mustBeInteger(opts.perPage), mustBePositive(opts.perPage)} = 100
    opts.maxPages (1,1) double {mustBeInteger(opts.maxPages), mustBePositive(opts.maxPages)} = 1
    opts.mailto (1,1) string = ""
    opts.apiKey (1,1) string = ""
    opts.timeoutSec (1,1) double {mustBePositive(opts.timeoutSec)} = 60
    opts.sort (1,1) string = ""
    opts.dryRun (1,1) logical = false
    opts.saveRawResponses (1,1) logical = false
    opts.rawResponseDir (1,1) string = ""
end

seedWorkId = resolve_openalex_seed_id(opts.seedId, apiKey=opts.apiKey, timeoutSec=opts.timeoutSec, ...
    saveRawResponse=opts.saveRawResponses, rawResponsePath=local_seed_raw_path(opts.rawResponseDir, "citing"));
effectiveFilter = local_join_filters(opts.filter, "cites:" + seedWorkId);

[worksTable, meta] = fetch_openalex_works( ...
    searchQuery="", ...
    filter=effectiveFilter, ...
    perPage=opts.perPage, ...
    maxPages=opts.maxPages, ...
    mailto=opts.mailto, ...
    apiKey=opts.apiKey, ...
    timeoutSec=opts.timeoutSec, ...
    sort=opts.sort, ...
    dryRun=opts.dryRun, ...
    saveRawResponses=opts.saveRawResponses, ...
    rawResponseDir=local_pages_raw_dir(opts.rawResponseDir, "citing"));

meta.seed_id = string(opts.seedId);
meta.seed_work_id = seedWorkId;
meta.snowball_mode = "citing";
meta.filter = effectiveFilter;
end

function txt = local_join_filters(varargin)
parts = strings(0,1);
for i = 1:nargin
    v = strtrim(string(varargin{i}));
    if v ~= ""
        parts(end+1,1) = v; %#ok<AGROW>
    end
end
txt = strjoin(parts, ",");
end

function p = local_seed_raw_path(rawResponseDir, modeName)
p = "";
baseDir = strtrim(string(rawResponseDir));
if baseDir == ""
    return;
end
p = string(fullfile(baseDir, char(modeName + "_seed.json")));
end

function p = local_pages_raw_dir(rawResponseDir, modeName)
p = "";
baseDir = strtrim(string(rawResponseDir));
if baseDir == ""
    return;
end
p = string(fullfile(baseDir, char(modeName + "_pages")));
end
