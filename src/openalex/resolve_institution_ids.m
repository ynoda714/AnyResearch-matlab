function [primaryId, allIds] = resolve_institution_ids(instName, currentId, aliases, timeoutSec)
%RESOLVE_INSTITUTION_IDS  Resolves OpenAlex institution IDs from an institution name.
%
%   Searches the OpenAlex institutions API and returns a list of institution IDs
%   matching instName / aliases. Falls back to currentId if the API call fails.
%
%   Usage:
%     [primaryId, allIds] = resolve_institution_ids("Nagoya City University", "", [], 30)

primaryId = strtrim(string(currentId));
allIds    = normalize_openalex_ids(primaryId);
if strlength(strtrim(instName)) == 0
    return;
end

queryName = strtrim(string(instName));
url = "https://api.openalex.org/institutions?search=" + ...
    string(urlencode(char(queryName))) + "&per-page=25&select=id,display_name";

log_info("resolving institution ids: name=%s", queryName);
started = tic;
try
    resp = webread(char(url), weboptions('Timeout', timeoutSec));
catch ex
    log_warn("institution id resolve failed (fallback to current setting): %s", string(ex.message));
    return;
end

if ~isfield(resp, 'results') || isempty(resp.results)
    log_warn("institution id resolve: no results for name=%s", queryName);
    return;
end

targets  = [lower(queryName); lower(strtrim(string(aliases(:))))];
targets  = targets(targets ~= "");
ids      = strings(0,1);
exactIds = strings(0,1);
for i = 1:numel(resp.results)
    item = resp.results(i);
    if ~isfield(item, 'id') || isempty(item.id)
        continue;
    end
    candId = normalize_openalex_ids(string(item.id));
    if isempty(candId)
        continue;
    end
    candName = "";
    if isfield(item, 'display_name') && ~isempty(item.display_name)
        candName = lower(strtrim(string(item.display_name)));
    end

    match = false;
    if isempty(targets)
        match = true;
    else
        for t = 1:numel(targets)
            if candName == targets(t) || contains(candName, targets(t)) || contains(targets(t), candName)
                match = true;
                if candName == targets(t)
                    exactIds(end+1,1) = candId(1); %#ok<AGROW>
                end
                break;
            end
        end
    end

    if match
        ids(end+1,1) = candId(1); %#ok<AGROW>
    end
end

ids      = unique(ids, 'stable');
exactIds = unique(exactIds, 'stable');
if ~isempty(exactIds)
    ids = unique([exactIds; ids], 'stable');
end
if isempty(ids)
    log_warn("institution id resolve: no matched candidates for name=%s", queryName);
    return;
end

allIds = ids;
if primaryId == ""
    primaryId = ids(1);
else
    normalizedPrimary = normalize_openalex_ids(primaryId);
    if ~isempty(normalizedPrimary)
        primaryId = normalizedPrimary(1);
    else
        primaryId = ids(1);
    end
end
if all(primaryId ~= ids)
    allIds = [primaryId; ids];
end

elapsed = toc(started);
log_info("institution id resolve done: candidates=%d primary=%s all=%s elapsed=%s", ...
    numel(allIds), primaryId, strjoin(allIds, " | "), format_duration(elapsed));
end
