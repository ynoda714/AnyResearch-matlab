function [seedWorkId, referencedIds] = resolve_openalex_referenced_ids(seedId, opts)
%RESOLVE_OPENALEX_REFERENCED_IDS Resolve DOI or Work ID and return referenced work IDs.
arguments
    seedId (1,1) string
    opts.apiKey (1,1) string = ""
    opts.timeoutSec (1,1) double {mustBePositive(opts.timeoutSec)} = 60
    opts.saveRawResponse (1,1) logical = false
    opts.rawResponsePath (1,1) string = ""
end

seedWorkId = resolve_openalex_seed_id(seedId, ...
    apiKey=opts.apiKey, ...
    timeoutSec=opts.timeoutSec, ...
    saveRawResponse=opts.saveRawResponse, ...
    rawResponsePath=opts.rawResponsePath);

normalizedSeed = local_normalize_seed(seedId);
baseUrl = "https://api.openalex.org/works/";
requestUrl = baseUrl + urlencode(char(normalizedSeed));
if strlength(strtrim(opts.apiKey)) > 0
    requestUrl = requestUrl + "?api_key=" + strtrim(opts.apiKey);
end

rawJson = webread(char(requestUrl), weboptions('Timeout', opts.timeoutSec, 'ContentType', 'text'));
response = jsondecode(rawJson);
referencedIds = strings(0,1);
if isfield(response, 'referenced_works') && ~isempty(response.referenced_works)
    referencedIds = string(response.referenced_works);
    referencedIds = lower(strtrim(referencedIds));
    referencedIds = replace(referencedIds, "https://openalex.org/", "");
    referencedIds = replace(referencedIds, "http://openalex.org/", "");
    referencedIds = referencedIds(referencedIds ~= "");
    referencedIds = unique(referencedIds, 'stable');
end
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
