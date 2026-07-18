function result = fetch_and_normalize_works(settingsJsonPath, opts)
arguments
    settingsJsonPath (1,1) string = "config/settings.example.json"
    opts.outputRawCsv (1,1) string = ""
    opts.outputNormalizedWorksCsv (1,1) string = ""
    opts.dryRun (1,1) logical = false
    opts.saveRawResponses (1,1) logical = true
    opts.rawResponseDir (1,1) string = ""
end

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'config'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'openalex'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'adapters'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'util'));

cfg = load_runtime_config(settingsJsonPath);

firstAuthorInstitution = local_get_openalex_str(cfg, "first_author_institution", "");
firstAuthorInstitutionId = local_get_openalex_str(cfg, "first_author_institution_id", "");
firstAuthorInstitutionAliases = local_get_openalex_str_list(cfg, "first_author_institution_aliases");
firstAuthorInstitutionKeywords = local_resolve_first_author_keywords(firstAuthorInstitution, firstAuthorInstitutionAliases);
firstAuthorInstitutionIds = local_resolve_first_author_ids(firstAuthorInstitutionId, local_get_openalex_str_list(cfg, "first_author_institution_ids"));
firstAuthorFilterMode = lower(local_get_openalex_str(cfg, "first_author_filter_mode", "direct"));
normalMaxPages = local_get_openalex_num(cfg, "max_pages", 1);
candidateMaxPages = local_get_openalex_num(cfg, "candidate_max_pages", normalMaxPages);
sortVal = local_get_openalex_str(cfg, "sort", "");
apiKey = local_get_openalex_str(cfg, "api_key", "");

if opts.dryRun
    [~, dryMeta] = fetch_openalex_works( ...
        searchQuery=string(cfg.openalex.search_query), ...
        filter=string(cfg.openalex.filter), ...
        perPage=1, ...
        maxPages=1, ...
        mailto=string(cfg.openalex.mailto), ...
        apiKey=apiKey, ...
        sort=sortVal, ...
        dryRun=true, ...
        saveRawResponses=false);
    totalCount = int32(-1);
    if isfield(dryMeta, 'total_count')
        totalCount = int32(dryMeta.total_count);
    end
    result = struct();
    result.dry_run = true;
    result.total_count = totalCount;
    result.filter = string(cfg.openalex.filter);
    result.search_query = string(cfg.openalex.search_query);
    return;
end

if firstAuthorFilterMode == "two_stage" && firstAuthorInstitution ~= ""
    [openalexTbl, meta] = fetch_openalex_works( ...
        searchQuery=string(cfg.openalex.search_query), ...
        filter=string(cfg.openalex.filter), ...
        perPage=double(cfg.openalex.per_page), ...
        maxPages=double(candidateMaxPages), ...
        mailto=string(cfg.openalex.mailto), ...
        apiKey=apiKey, ...
        sort=sortVal, ...
        firstAuthorInstitution="", ...
        firstAuthorInstitutionKeywords=strings(0,1), ...
        firstAuthorInstitutionIds=strings(0,1), ...
        saveRawResponses=opts.saveRawResponses, ...
        rawResponseDir=opts.rawResponseDir);

    candidateRows = height(openalexTbl);
    [openalexTbl, droppedInstMismatch] = local_filter_first_author_institution(openalexTbl, firstAuthorInstitutionKeywords, firstAuthorInstitutionIds);
    meta.first_author_institution = firstAuthorInstitution;
    meta.first_author_institution_ids = strjoin(firstAuthorInstitutionIds, " | ");
    meta.first_author_institution_keywords = strjoin(firstAuthorInstitutionKeywords, " | ");
    meta.dropped_first_author_institution_mismatch_rows = int32(droppedInstMismatch);
    meta.candidate_rows_before_first_author_filter = int32(candidateRows);
    meta.first_author_filter_mode = firstAuthorFilterMode;
else
    [openalexTbl, meta] = fetch_openalex_works( ...
        searchQuery=string(cfg.openalex.search_query), ...
        filter=string(cfg.openalex.filter), ...
        perPage=double(cfg.openalex.per_page), ...
        maxPages=double(normalMaxPages), ...
        mailto=string(cfg.openalex.mailto), ...
        apiKey=apiKey, ...
        sort=sortVal, ...
        firstAuthorInstitution=firstAuthorInstitution, ...
        firstAuthorInstitutionKeywords=firstAuthorInstitutionAliases, ...
        firstAuthorInstitutionIds=firstAuthorInstitutionIds, ...
        saveRawResponses=opts.saveRawResponses, ...
        rawResponseDir=opts.rawResponseDir);
    meta.first_author_filter_mode = firstAuthorFilterMode;
    meta.candidate_rows_before_first_author_filter = int32(height(openalexTbl) + double(meta.dropped_first_author_institution_mismatch_rows));
end

if height(openalexTbl) == 0
    cand = int32(0);
    miss = int32(0);
    mode = firstAuthorFilterMode;
    if isfield(meta, 'candidate_rows_before_first_author_filter')
        cand = int32(meta.candidate_rows_before_first_author_filter);
    end
    if isfield(meta, 'dropped_first_author_institution_mismatch_rows')
        miss = int32(meta.dropped_first_author_institution_mismatch_rows);
    end
    error("fetch_and_normalize_works:NoRows", ...
        "No valid rows retrieved from OpenAlex API. mode=%s candidate_rows=%d first_author_mismatch=%d", ...
        string(mode), cand, miss);
end

titleVals = string(openalexTbl.title);
absVals = string(openalexTbl.abstract);
titleVals(ismissing(titleVals)) = "";
absVals(ismissing(absVals)) = "";
validMask = strlength(strtrim(titleVals)) > 0;
dropCount = nnz(~validMask);
missingAbstractCount = nnz(strlength(strtrim(absVals)) == 0);
openalexTbl = openalexTbl(validMask, :);

if height(openalexTbl) == 0
    error("fetch_and_normalize_works:NoValidRows", "No rows with valid title. Original count=%d", double(meta.rows));
end

maxRows = local_get_openalex_num(cfg, "max_rows_for_validation", 0);
samplingMode = local_get_openalex_str(cfg, "sampling_mode", "head");
randomSeed = local_get_openalex_num(cfg, "random_seed", 42);
if maxRows > 0 && height(openalexTbl) > maxRows
    if lower(samplingMode) == "random"
        rng(randomSeed);
        pick = randperm(height(openalexTbl), maxRows);
        pick = sort(pick);
        openalexTbl = openalexTbl(pick, :);
    else
        openalexTbl = openalexTbl(1:maxRows, :);
    end
end

strictValidation = false;
normalizedWorks = openalex_to_normalized_works(openalexTbl, StrictValidation=strictValidation);

if opts.outputRawCsv ~= ""
    rawPath = string(opts.outputRawCsv);
else
    rawPath = string(cfg.output.openalex_raw_csv);
end
if opts.outputNormalizedWorksCsv ~= ""
    outPath = string(opts.outputNormalizedWorksCsv);
else
    outPath = string(local_get_output_path(cfg));
end

rawDir = fileparts(rawPath);
if strlength(rawDir) > 0 && ~isfolder(rawDir)
    mkdir(rawDir);
end
outDir = fileparts(outPath);
if strlength(outDir) > 0 && ~isfolder(outDir)
    mkdir(outDir);
end

local_write_csv_utf8_bom(openalexTbl, rawPath);
local_write_csv_utf8_bom(normalizedWorks, outPath);

rawJsonl = strrep(rawPath, '.csv', '.jsonl');
outJsonl  = strrep(outPath, '.csv', '.jsonl');
write_jsonl(openalexTbl, rawJsonl);
write_jsonl(normalizedWorks, outJsonl);

result = struct();
result.settings_json = settingsJsonPath;
result.openalex_raw_csv = rawPath;
result.openalex_raw_jsonl = rawJsonl;
result.normalized_works_csv = outPath;
result.normalized_works_jsonl = outJsonl;
result.openalex_raw_table = openalexTbl;
result.normalized_works_table = normalizedWorks;
result.rows = height(normalizedWorks);
result.pages = meta.pages;
result.dropped_empty_title_rows = int32(dropCount);
result.missing_abstract_rows = int32(missingAbstractCount);
result.max_rows_for_validation = int32(maxRows);
result.sampling_mode = string(samplingMode);
result.first_author_institution = firstAuthorInstitution;
result.first_author_institution_ids = strjoin(firstAuthorInstitutionIds, " | ");
result.first_author_institution_keywords = strjoin(firstAuthorInstitutionKeywords, " | ");
result.first_author_filter_mode = firstAuthorFilterMode;
result.save_raw_responses = opts.saveRawResponses;
result.raw_response_dir = string(opts.rawResponseDir);
if isfield(meta, 'dropped_first_author_institution_mismatch_rows')
    result.dropped_first_author_institution_mismatch_rows = int32(meta.dropped_first_author_institution_mismatch_rows);
else
    result.dropped_first_author_institution_mismatch_rows = int32(0);
end
if isfield(meta, 'candidate_rows_before_first_author_filter')
    result.candidate_rows_before_first_author_filter = int32(meta.candidate_rows_before_first_author_filter);
else
    result.candidate_rows_before_first_author_filter = int32(result.rows + result.dropped_first_author_institution_mismatch_rows);
end

log_info("OpenAlex API fetch done: rows=%d pages=%d", result.rows, result.pages);
log_info("dropped_empty_title_rows=%d", result.dropped_empty_title_rows);
log_info("missing_abstract_rows=%d", result.missing_abstract_rows);
log_info("first_author_filter_mode=%s candidate_rows=%d", result.first_author_filter_mode, result.candidate_rows_before_first_author_filter);
log_info("first_author_institution=%s dropped_mismatch=%d", result.first_author_institution, result.dropped_first_author_institution_mismatch_rows);
log_info("first_author_ids=%s", result.first_author_institution_ids);
log_info("first_author_keywords=%s", result.first_author_institution_keywords);
log_info("max_rows_for_validation=%d sampling_mode=%s", result.max_rows_for_validation, result.sampling_mode);
log_info("raw=%s", result.openalex_raw_csv);
log_info("normalized_works=%s", result.normalized_works_csv);
end

function p = local_get_output_path(cfg)
if isfield(cfg, 'output') && isfield(cfg.output, 'normalized_works_csv')
    p = string(cfg.output.normalized_works_csv);
    return;
end
if isfield(cfg, 'output') && isfield(cfg.output, ['scoring' '_input_csv'])
    p = string(cfg.output.(['scoring' '_input_csv']));
    return;
end
if isfield(cfg, 'output') && isfield(cfg.output, 'openalex_raw_csv')
    outDir = fileparts(string(cfg.output.openalex_raw_csv));
    p = string(fullfile(outDir, char("scoring" + "_input.csv")));
    return;
end
p = "scoring" + "_input.csv";
end

function [T, dropped] = local_filter_first_author_institution(T, keywords, targetIds)
targets = lower(strtrim(string(keywords)));
targets = targets(targets ~= "");
targetIds = local_normalize_ids(targetIds);
if (isempty(targets) && isempty(targetIds)) || height(T) == 0
    dropped = 0;
    return;
end

mask = false(height(T), 1);
if ~isempty(targetIds) && ismember("first_author_institution_ids", string(T.Properties.VariableNames))
    idVals = local_normalize_ids(T.first_author_institution_ids);
    for i = 1:numel(targetIds)
        mask = mask | contains(idVals, targetIds(i));
    end
elseif ~isempty(targets) && ismember("first_author_institutions", string(T.Properties.VariableNames))
    instVals = lower(string(T.first_author_institutions));
    instVals(ismissing(instVals)) = "";
    for i = 1:numel(targets)
        mask = mask | contains(instVals, targets(i));
    end
else
    dropped = 0;
    return;
end
dropped = nnz(~mask);
T = T(mask, :);
end

function ids = local_resolve_first_author_ids(primaryId, idList)
ids = strings(0,1);
pid = strtrim(string(primaryId));
if pid ~= ""
    ids(end+1) = pid; %#ok<AGROW>
end
idList = string(idList);
for i = 1:numel(idList)
    v = strtrim(idList(i));
    if v == ""
        continue;
    end
    ids(end+1) = v; %#ok<AGROW>
end
if isempty(ids)
    return;
end
ids = local_normalize_ids(ids);
ids = unique(ids, 'stable');
end

function vals = local_normalize_ids(vals)
vals = string(vals);
vals(ismissing(vals)) = "";
vals = lower(strtrim(vals));
vals = replace(vals, "https://openalex.org/", "");
vals = replace(vals, "http://openalex.org/", "");
vals = regexprep(vals, "\s+", "");
end

function keys = local_resolve_first_author_keywords(primaryName, aliases)
keys = strings(0,1);
if strlength(strtrim(string(primaryName))) > 0
    keys(end+1) = strtrim(string(primaryName)); %#ok<AGROW>
end
aliases = string(aliases);
for i = 1:numel(aliases)
    v = strtrim(aliases(i));
    if v == ""
        continue;
    end
    keys(end+1) = v; %#ok<AGROW>
end
if isempty(keys)
    return;
end
keys = unique(lower(keys), 'stable');
end

function vals = local_get_openalex_str_list(cfg, key)
vals = strings(0,1);
if ~(isfield(cfg, 'openalex') && isfield(cfg.openalex, key))
    return;
end
raw = string(cfg.openalex.(key));
if strlength(strtrim(raw)) == 0
    return;
end
parts = split(raw, "|");
parts = strtrim(parts);
parts = parts(parts ~= "");
vals = parts;
end

function local_write_csv_utf8_bom(T, path)
writetable(T, path, "Encoding", "UTF-8");

fid = fopen(path, 'r');
if fid < 0
    return;
end
cleanupIn = onCleanup(@() fclose(fid)); %#ok<NASGU>
bytes = fread(fid, Inf, '*uint8');

bom = uint8([239; 187; 191]);
hasBom = numel(bytes) >= 3 && all(bytes(1:3) == bom);
if hasBom
    return;
end

fidw = fopen(path, 'w');
if fidw < 0
    return;
end
cleanupOut = onCleanup(@() fclose(fidw)); %#ok<NASGU>
fwrite(fidw, bom, 'uint8');
fwrite(fidw, bytes, 'uint8');
end

function v = local_get_openalex_num(cfg, key, defaultVal)
if isfield(cfg, 'openalex') && isfield(cfg.openalex, key)
    v = double(cfg.openalex.(key));
else
    v = defaultVal;
end
end

function v = local_get_openalex_str(cfg, key, defaultVal)
if isfield(cfg, 'openalex') && isfield(cfg.openalex, key)
    v = string(cfg.openalex.(key));
else
    v = string(defaultVal);
end
end
