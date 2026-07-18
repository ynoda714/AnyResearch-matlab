function seedWorkId = resolve_openalex_seed_id(seedId, opts)
%RESOLVE_OPENALEX_SEED_ID Resolve DOI or Work ID to canonical OpenAlex Work ID.
arguments
    seedId (1,1) string
    opts.apiKey (1,1) string = ""
    opts.timeoutSec (1,1) double {mustBePositive(opts.timeoutSec)} = 60
    opts.saveRawResponse (1,1) logical = false
    opts.rawResponsePath (1,1) string = ""
end

[seedWorkId, ~] = local_fetch_seed_work(seedId, opts.apiKey, opts.timeoutSec, opts.saveRawResponse, opts.rawResponsePath);
end

function [seedWorkId, response] = local_fetch_seed_work(seedId, apiKey, timeoutSec, saveRawResponse, rawResponsePath)
normalizedSeed = local_normalize_seed(seedId);
baseUrl = "https://api.openalex.org/works/";
requestUrl = baseUrl + urlencode(char(normalizedSeed));
if strlength(strtrim(apiKey)) > 0
    requestUrl = requestUrl + "?api_key=" + strtrim(apiKey);
end

rawJson = webread(char(requestUrl), weboptions('Timeout', timeoutSec, 'ContentType', 'text'));
response = jsondecode(rawJson);
if saveRawResponse
    local_maybe_save_raw_response(rawJson, rawResponsePath);
end

if ~isfield(response, 'id') || isempty(response.id)
    error("resolve_openalex_seed_id:InvalidSeedResponse", ...
        "Seed work could not be resolved: %s", seedId);
end
seedWorkId = string(response.id);
seedWorkId = lower(strtrim(seedWorkId));
seedWorkId = replace(seedWorkId, "https://openalex.org/", "");
seedWorkId = replace(seedWorkId, "http://openalex.org/", "");
end

function normalized = local_normalize_seed(seedId)
normalized = strtrim(string(seedId));
normalized = replace(normalized, "https://openalex.org/works/", "");
normalized = replace(normalized, "http://openalex.org/works/", "");
normalized = replace(normalized, "https://openalex.org/", "");
normalized = replace(normalized, "http://openalex.org/", "");
if startsWith(lower(normalized), "doi:")
    normalized = extractAfter(normalized, 4);
end
if ~isempty(regexp(char(normalized), '^[Ww]\d+$', 'once'))
    normalized = "W" + extractAfter(upper(normalized), 1);
elseif ~startsWith(lower(normalized), "https://doi.org/")
    normalized = "https://doi.org/" + normalized;
end
end

function local_maybe_save_raw_response(rawJson, rawResponsePath)
targetPath = strtrim(string(rawResponsePath));
if targetPath == ""
    return;
end
targetDir = fileparts(targetPath);
if strlength(targetDir) > 0 && ~isfolder(targetDir)
    mkdir(targetDir);
end
fid = fopen(targetPath, 'w', 'n', 'UTF-8');
if fid < 0
    error("resolve_openalex_seed_id:RawSaveFailed", "Cannot open file: %s", targetPath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, char(string(rawJson)), 'char');
end
