function [worksTable, meta] = fetch_referenced_works(opts)
%FETCH_REFERENCED_WORKS Fetch works referenced by a seed work.
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

seedRawPath = local_seed_raw_path(opts.rawResponseDir);
[seedWorkId, referencedIds] = resolve_openalex_referenced_ids(opts.seedId, apiKey=opts.apiKey, timeoutSec=opts.timeoutSec, ...
    saveRawResponse=opts.saveRawResponses, rawResponsePath=seedRawPath);

meta = struct();
meta.seed_id = string(opts.seedId);
meta.seed_work_id = seedWorkId;
meta.snowball_mode = "referenced";
meta.referenced_ids_count = int32(numel(referencedIds));
meta.filter = local_join_filters(opts.filter, "openalex_id:<chunked>");

if opts.dryRun
    worksTable = local_empty_works_table();
    meta.pages = int32(0);
    meta.requests = int32(1);
    meta.rows = int32(0);
    meta.total_count = int32(numel(referencedIds));
    return;
end

if isempty(referencedIds)
    worksTable = local_empty_works_table();
    meta.pages = int32(0);
    meta.requests = int32(1);
    meta.rows = int32(0);
    meta.total_count = int32(0);
    return;
end

maxRows = max(1, opts.maxPages * opts.perPage);
if numel(referencedIds) > maxRows
    referencedIds = referencedIds(1:maxRows);
end

chunkSize = 50;
worksTable = local_empty_works_table();
requests = 0;
pages = 0;
for startIdx = 1:chunkSize:numel(referencedIds)
    chunkIds = referencedIds(startIdx:min(startIdx + chunkSize - 1, numel(referencedIds)));
    chunkFilter = local_join_filters(opts.filter, "openalex_id:" + strjoin(chunkIds, "|"));
    chunkRawDir = local_chunk_raw_dir(opts.rawResponseDir, startIdx);
    [chunkTable, chunkMeta] = fetch_openalex_works( ...
        searchQuery="", ...
        filter=chunkFilter, ...
        perPage=min(opts.perPage, numel(chunkIds)), ...
        maxPages=1, ...
        mailto=opts.mailto, ...
        apiKey=opts.apiKey, ...
        timeoutSec=opts.timeoutSec, ...
        sort=opts.sort, ...
        dryRun=false, ...
        saveRawResponses=opts.saveRawResponses, ...
        rawResponseDir=chunkRawDir);
    worksTable = [worksTable; chunkTable]; %#ok<AGROW>
    requests = requests + double(chunkMeta.requests);
    pages = pages + double(chunkMeta.pages);
end

if height(worksTable) > 0 && ismember("openalex_id", string(worksTable.Properties.VariableNames))
    [~, keepIdx] = unique(string(worksTable.openalex_id), 'stable');
    keepIdx = sort(keepIdx);
    worksTable = worksTable(keepIdx, :);
end

meta.pages = int32(pages);
meta.requests = int32(requests + 1);
meta.rows = int32(height(worksTable));
meta.total_count = int32(numel(referencedIds));
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

function T = local_empty_works_table()
T = table('Size', [0 27], ...
    'VariableTypes', {'string','string','string','string','double','string','double','double','double','string','double','string','string','double','string','string','string','string','string','string','string','double','string','string','string','string','string'}, ...
    'VariableNames', {'openalex_id','title','abstract','doi','publication_year','publication_date','cited_by_count','fwci','citation_percentile','counts_by_year','is_retracted','best_oa_pdf_url','license','referenced_works_count','source_dataset','first_author_name','first_author_institutions','first_author_institution_ids','last_author_name','last_author_institutions','last_author_institution_ids','is_oa','type','source_name','open_access_url','topics','language'});
end

function p = local_seed_raw_path(rawResponseDir)
p = "";
baseDir = strtrim(string(rawResponseDir));
if baseDir == ""
    return;
end
p = string(fullfile(baseDir, 'referenced_seed.json'));
end

function p = local_chunk_raw_dir(rawResponseDir, startIdx)
p = "";
baseDir = strtrim(string(rawResponseDir));
if baseDir == ""
    return;
end
p = string(fullfile(baseDir, sprintf('referenced_chunk_%03d', ceil(startIdx / 50))));
end
