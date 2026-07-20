function [worksTable, meta] = fetch_openalex_works(opts)
% FETCH_OPENALEX_WORKS  Fetches paper metadata from the OpenAlex API.
%
% Options:
%   apiKey         (string, default "") — OpenAlex API Key (required since 2026)
%                  Set via config/settings.json openalex.api_key or
%                  environment variable ANYRESEARCH_OPENALEX_API_KEY.
%   dryRun         (logical, default false) — When true, fetches only 1 record and
%                  returns meta.total_count (data table is empty). Used for count preview.
%   filterCountryCode (string, default "") — When non-empty,
%                  appends "authorships.institutions.country_code:<code>" to filter.
%                  Example: "JP" -> Japan filter
%   sort           (string, default "") — Sort order for results.
%                  Example: "cited_by_count:desc" / "publication_date:desc" / "relevance_score"
arguments
    opts.searchQuery (1,1) string = ""
    opts.filter (1,1) string = "is_oa:true,has_abstract:true,language:en"
    opts.perPage (1,1) double {mustBeInteger(opts.perPage), mustBePositive(opts.perPage)} = 100
    opts.maxPages (1,1) double {mustBeInteger(opts.maxPages), mustBePositive(opts.maxPages)} = 1
    opts.mailto (1,1) string = ""
    opts.apiKey (1,1) string = ""
    opts.selectFields (1,1) string = "id,doi,display_name,publication_year,publication_date,cited_by_count,fwci,citation_normalized_percentile,counts_by_year,referenced_works_count,is_retracted,abstract_inverted_index,authorships,open_access,primary_location,best_oa_location,type,language,topics"
    opts.firstAuthorInstitution (1,1) string = ""
    opts.firstAuthorInstitutionKeywords string = strings(0,1)
    opts.firstAuthorInstitutionIds string = strings(0,1)
    opts.timeoutSec (1,1) double {mustBePositive(opts.timeoutSec)} = 60
    opts.dryRun (1,1) logical = false
    opts.filterCountryCode (1,1) string = ""
    opts.sort (1,1) string = ""
    opts.saveRawResponses (1,1) logical = false
    opts.rawResponseDir (1,1) string = ""
end

% If filterCountryCode is specified, append it to the filter
effectiveFilter = string(opts.filter);
if strlength(strtrim(opts.filterCountryCode)) > 0
    effectiveFilter = effectiveFilter + ",authorships.institutions.country_code:" + strtrim(opts.filterCountryCode);
end

% When dryRun=true, use perPage=1, maxPages=1 to fetch count only
effectivePerPage  = opts.perPage;
effectiveMaxPages = opts.maxPages;
if opts.dryRun
    effectivePerPage  = 1;
    effectiveMaxPages = 1;
end

baseUrl = "https://api.openalex.org/works";
cursor = "*";
rowCells = cell(0,27);
pageCount = 0;
requestCount = 0;
dropFirstAuthorMismatchCount = 0;
totalCount = int32(-1);
firstAuthorKeywords = local_resolve_first_author_keywords(opts.firstAuthorInstitution, opts.firstAuthorInstitutionKeywords);
firstAuthorIds = local_resolve_first_author_ids(opts.firstAuthorInstitutionIds);

while pageCount < effectiveMaxPages
    pageCount = pageCount + 1;
    queryKeys = {"filter", "per-page", "cursor", "select"};
    queryVals = {char(effectiveFilter), char(string(effectivePerPage)), char(cursor), char(opts.selectFields)};
    if opts.searchQuery ~= ""
        queryKeys{end+1} = "search"; %#ok<AGROW>
        queryVals{end+1} = char(opts.searchQuery); %#ok<AGROW>
    end
    if strlength(strtrim(opts.sort)) > 0
        queryKeys{end+1} = "sort"; %#ok<AGROW>
        queryVals{end+1} = char(strtrim(opts.sort)); %#ok<AGROW>
    end
    if opts.mailto ~= ""
        queryKeys{end+1} = "mailto"; %#ok<AGROW>
        queryVals{end+1} = char(opts.mailto); %#ok<AGROW>
    end
    if opts.apiKey ~= ""
        queryKeys{end+1} = "api_key"; %#ok<AGROW>
        queryVals{end+1} = char(opts.apiKey); %#ok<AGROW>
    end

    queryParts = strings(1, numel(queryKeys));
    for qi = 1:numel(queryKeys)
        k = string(queryKeys{qi});
        v = string(queryVals{qi});
        if k == "search" || k == "mailto"
            if k == "search"
                % Normalize AnyResearch OR syntax to the OpenAlex search syntax.
                v = replace(v, "\|", "|");
                v = replace(v, "|", " OR ");
                v = regexprep(v, '\s+', ' ');
                v = strtrim(v);
            end
            v = string(urlencode(char(v)));
        elseif k == "cursor" && v == "*"
            v = "%2A";
        end
        % api_key is sent as-is (no URL encoding needed)
        queryParts(qi) = k + "=" + v;
    end
    requestUrl = baseUrl + "?" + strjoin(queryParts, "&");

    rawPageJson = local_webread_with_retry(requestUrl, opts.timeoutSec);
    response = jsondecode(rawPageJson);
    requestCount = requestCount + 1;
    local_maybe_save_raw_page(rawPageJson, pageCount, opts.saveRawResponses, opts.rawResponseDir);

    % Record meta.count from the first response
    if totalCount < 0 && isfield(response, 'meta') && isfield(response.meta, 'count')
        totalCount = int32(response.meta.count);
    end

    % When dryRun=true, stop here without processing data
    if opts.dryRun
        break;
    end

    if ~isfield(response, 'results') || isempty(response.results)
        break;
    end

    % Pre-extract raw abstract JSON per work id to avoid jsondecode identifier conversion
    % and to keep abstracts aligned even when one raw extraction fails.
    rawAbstractEntries = extract_openalex_raw_abstracts(rawPageJson);
    rawAbstractMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for rawIdx = 1:numel(rawAbstractEntries)
        rawAbstractMap(char(rawAbstractEntries(rawIdx).openalex_id)) = rawAbstractEntries(rawIdx).raw_abstract_json;
    end

    results = response.results;
    keptInPage = 0;
    droppedInPage = 0;
    for i = 1:numel(results)
        w = results(i);
        [firstAuthorName, firstAuthorInstitutions, firstAuthorInstitutionIds] = local_extract_first_author_institutions(w);
        [lastAuthorName, lastAuthorInstitutions, lastAuthorInstitutionIds] = local_extract_last_author_institutions(w);

        if ~isempty(firstAuthorIds) && ~local_match_first_author_institution_ids(firstAuthorInstitutionIds, firstAuthorIds)
            dropFirstAuthorMismatchCount = dropFirstAuthorMismatchCount + 1;
            droppedInPage = droppedInPage + 1;
            continue;
        end
        if isempty(firstAuthorIds) && ~isempty(firstAuthorKeywords) && ~local_match_first_author_institution_names(firstAuthorInstitutions, firstAuthorKeywords)
            dropFirstAuthorMismatchCount = dropFirstAuthorMismatchCount + 1;
            droppedInPage = droppedInPage + 1;
            continue;
        end

        openalexId = local_get_field(w, 'id');
        doiValue = local_get_field(w, 'doi');
        titleText = local_get_field(w, 'display_name');
        pubYear = local_get_numeric(w, 'publication_year');
        publicationDate = local_get_field(w, 'publication_date');
        citedByCount = local_get_numeric(w, 'cited_by_count');
        fwciVal = local_get_numeric(w, 'fwci');
        citationPercentile = local_get_nested_numeric(w, {'citation_normalized_percentile', 'value'});
        countsByYear = local_get_json_text(w, 'counts_by_year');
        isRetracted = local_get_numeric(w, 'is_retracted');
        bestOaPdfUrl = local_get_best_oa_pdf_url(w);
        licenseVal = local_get_best_oa_license(w);
        referencedWorksCount = local_get_numeric(w, 'referenced_works_count');
        abstractText = "";
        if openalexId ~= "" && isKey(rawAbstractMap, char(openalexId))
            rawAbstractJson = string(rawAbstractMap(char(openalexId)));
            if rawAbstractJson ~= ""
                abstractText = parse_openalex_inverted_index_json(rawAbstractJson);
            end
        end
        if abstractText == ""
            % Fail-safe: if raw extraction is missing or parsing yields no tokens,
            % fall back to the jsondecode-based reconstruction rather than silently
            % returning an empty abstract.
            abstractText = local_reconstruct_abstract(w);
        end
        isOa = local_get_is_oa(w);
        typeVal = local_get_field(w, 'type');
        sourceNameVal = local_get_source_name(w);
        openAccessUrl = local_get_oa_url(w);
        topicsVal = local_get_first_topic(w);
        languageVal = local_get_field(w, 'language');

        rowCells(end+1, :) = { ...
            string(openalexId), ...
            string(titleText), ...
            string(abstractText), ...
            string(doiValue), ...
            pubYear, ...
            string(publicationDate), ...
            citedByCount, ...
            fwciVal, ...
            citationPercentile, ...
            string(countsByYear), ...
            isRetracted, ...
            string(bestOaPdfUrl), ...
            string(licenseVal), ...
            referencedWorksCount, ...
            "openalex_api", ...
            string(firstAuthorName), ...
            string(firstAuthorInstitutions), ...
            string(firstAuthorInstitutionIds), ...
            string(lastAuthorName), ...
            string(lastAuthorInstitutions), ...
            string(lastAuthorInstitutionIds), ...
            isOa, ...
            string(typeVal), ...
            string(sourceNameVal), ...
            string(openAccessUrl), ...
            string(topicsVal), ...
            string(languageVal) ...
            }; %#ok<AGROW>
        keptInPage = keptInPage + 1;
    end

    log_progress(pageCount, opts.maxPages, "openalex-pages");

    if ~isfield(response, 'meta') || ~isfield(response.meta, 'next_cursor') || isempty(response.meta.next_cursor)
        break;
    end

    cursor = string(response.meta.next_cursor);
    if cursor == ""
        break;
    end
end

if isempty(rowCells)
    worksTable = table('Size', [0 27], ...
        'VariableTypes', {'string','string','string','string','double','string','double','double','string','double','string','string','double','string','string','string','string','string','string','string','string','double','string','string','string','string','string'}, ...
        'VariableNames', {'openalex_id','title','abstract','doi','publication_year','publication_date','cited_by_count','fwci','citation_percentile','counts_by_year','is_retracted','best_oa_pdf_url','license','referenced_works_count','source_dataset','first_author_name','first_author_institutions','first_author_institution_ids','last_author_name','last_author_institutions','last_author_institution_ids','is_oa','type','source_name','open_access_url','topics','language'});
else
    worksTable = cell2table(rowCells, 'VariableNames', {'openalex_id','title','abstract','doi','publication_year','publication_date','cited_by_count','fwci','citation_percentile','counts_by_year','is_retracted','best_oa_pdf_url','license','referenced_works_count','source_dataset','first_author_name','first_author_institutions','first_author_institution_ids','last_author_name','last_author_institutions','last_author_institution_ids','is_oa','type','source_name','open_access_url','topics','language'});
    worksTable.openalex_id = string(worksTable.openalex_id);
    worksTable.title = string(worksTable.title);
    worksTable.abstract = string(worksTable.abstract);
    worksTable.doi = string(worksTable.doi);
    worksTable.publication_year = double(worksTable.publication_year);
    worksTable.publication_date = string(worksTable.publication_date);
    worksTable.cited_by_count = double(worksTable.cited_by_count);
    worksTable.fwci = double(worksTable.fwci);
    worksTable.citation_percentile = double(worksTable.citation_percentile);
    worksTable.counts_by_year = string(worksTable.counts_by_year);
    worksTable.is_retracted = double(worksTable.is_retracted);
    worksTable.best_oa_pdf_url = string(worksTable.best_oa_pdf_url);
    worksTable.license = string(worksTable.license);
    worksTable.referenced_works_count = double(worksTable.referenced_works_count);
    worksTable.source_dataset = string(worksTable.source_dataset);
    worksTable.first_author_name = string(worksTable.first_author_name);
    worksTable.first_author_institutions = string(worksTable.first_author_institutions);
    worksTable.first_author_institution_ids = string(worksTable.first_author_institution_ids);
    worksTable.last_author_name = string(worksTable.last_author_name);
    worksTable.last_author_institutions = string(worksTable.last_author_institutions);
    worksTable.last_author_institution_ids = string(worksTable.last_author_institution_ids);
    worksTable.is_oa = double(worksTable.is_oa);
    worksTable.type = string(worksTable.type);
    worksTable.source_name = string(worksTable.source_name);
    worksTable.open_access_url = string(worksTable.open_access_url);
    worksTable.topics = string(worksTable.topics);
    worksTable.language = string(worksTable.language);
end

meta = struct();
meta.pages = int32(pageCount);
meta.requests = int32(requestCount);
meta.rows = int32(height(worksTable));
meta.total_count = totalCount;
meta.filter = string(effectiveFilter);
meta.search_query = string(opts.searchQuery);
meta.first_author_institution = string(opts.firstAuthorInstitution);
meta.first_author_institution_ids = string(strjoin(firstAuthorIds, " | "));
meta.first_author_institution_keywords = string(strjoin(firstAuthorKeywords, " | "));
meta.dropped_first_author_institution_mismatch_rows = int32(dropFirstAuthorMismatchCount);
meta.save_raw_responses = opts.saveRawResponses;
meta.raw_response_dir = string(opts.rawResponseDir);
end

function ids = local_resolve_first_author_ids(vals)
ids = string(vals);
ids(ismissing(ids)) = "";
ids = lower(strtrim(ids));
ids = replace(ids, "https://openalex.org/", "");
ids = replace(ids, "http://openalex.org/", "");
ids = ids(ids ~= "");
ids = unique(ids, 'stable');
end

function keys = local_resolve_first_author_keywords(primaryName, aliasValues)
keys = strings(0,1);
if strlength(strtrim(string(primaryName))) > 0
    keys(end+1) = strtrim(string(primaryName)); %#ok<AGROW>
end
aliasValues = string(aliasValues);
for i = 1:numel(aliasValues)
    v = strtrim(aliasValues(i));
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

function val = local_get_is_oa(w)
% Returns 1.0 if open_access.is_oa is true, 0.0 if false, NaN if missing.
val = nan;
if isfield(w, 'open_access') && ~isempty(w.open_access) && isstruct(w.open_access)
    if isfield(w.open_access, 'is_oa') && ~isempty(w.open_access.is_oa)
        val = double(w.open_access.is_oa);
    end
end
end

function name = local_get_source_name(w)
% Returns primary_location.source.display_name, or "" if missing.
name = "";
if isfield(w, 'primary_location') && ~isempty(w.primary_location) && isstruct(w.primary_location)
    if isfield(w.primary_location, 'source') && ~isempty(w.primary_location.source) && isstruct(w.primary_location.source)
        if isfield(w.primary_location.source, 'display_name') && ~isempty(w.primary_location.source.display_name)
            name = string(w.primary_location.source.display_name);
        end
    end
end
end

function url = local_get_oa_url(w)
% Returns open_access.oa_url, or "" if missing.
url = "";
if isfield(w, 'open_access') && ~isempty(w.open_access) && isstruct(w.open_access)
    if isfield(w.open_access, 'oa_url') && ~isempty(w.open_access.oa_url)
        url = string(w.open_access.oa_url);
    end
end
end

function topic = local_get_first_topic(w)
% Returns topics[0].display_name only (first topic, single string).
topic = "";
if ~isfield(w, 'topics') || isempty(w.topics)
    return;
end
t = w.topics;
if isstruct(t) && numel(t) >= 1
    first = t(1);
    if isfield(first, 'display_name') && ~isempty(first.display_name)
        topic = string(first.display_name);
    end
end
end

function val = local_get_field(s, fieldName)
if isfield(s, fieldName)
    v = s.(fieldName);
    if isempty(v)
        val = "";
    else
        val = string(v);
    end
else
    val = "";
end
end

function val = local_get_numeric(s, fieldName)
if isfield(s, fieldName)
    v = s.(fieldName);
    if isempty(v)
        val = nan;
    else
        val = double(v);
    end
else
    val = nan;
end
end

function abstractText = local_reconstruct_abstract(w)
if ~isfield(w, 'abstract_inverted_index') || isempty(w.abstract_inverted_index)
    abstractText = "";
    return;
end

idxMap = w.abstract_inverted_index;
words = fieldnames(idxMap);
maxPos = 0;
for i = 1:numel(words)
    pos = idxMap.(words{i});
    if isempty(pos)
        continue;
    end
    maxPos = max(maxPos, max(double(pos)));
end

if maxPos <= 0
    abstractText = "";
    return;
end

tokens = strings(maxPos + 1, 1);
for i = 1:numel(words)
    term = string(words{i});
    pos = double(idxMap.(words{i}));
    for j = 1:numel(pos)
        p = pos(j) + 1;
        if p >= 1 && p <= numel(tokens)
            tokens(p) = term;
        end
    end
end

tokens = tokens(tokens ~= "");
abstractText = strtrim(strjoin(tokens, " "));
end

function [firstAuthorName, names, ids] = local_extract_first_author_institutions(work)
firstAuthorName = "";
names = "";
ids = "";
if ~isfield(work, 'authorships') || isempty(work.authorships)
    return;
end

auths = work.authorships;
firstIdx = 1;
for i = 1:numel(auths)
    a = auths(i);
    if isfield(a, 'author_position') && strcmpi(string(a.author_position), "first")
        firstIdx = i;
        break;
    end
end

firstAuth = auths(firstIdx);
if isfield(firstAuth, 'author') && ~isempty(firstAuth.author)
    a = firstAuth.author;
    if isfield(a, 'display_name') && ~isempty(a.display_name)
        firstAuthorName = string(a.display_name);
    end
end
if ~isfield(firstAuth, 'institutions') || isempty(firstAuth.institutions)
    return;
end

insts = firstAuth.institutions;
vals = strings(0,1);
idVals = strings(0,1);
for i = 1:numel(insts)
    inst = insts(i);
    if isfield(inst, 'display_name') && ~isempty(inst.display_name)
        vals(end+1) = string(inst.display_name); %#ok<AGROW>
    end
    if isfield(inst, 'id') && ~isempty(inst.id)
        idVals(end+1) = string(inst.id); %#ok<AGROW>
    end
end
if ~isempty(vals)
    names = strjoin(vals, " | ");
end
if ~isempty(idVals)
    idVals = replace(lower(strtrim(idVals)), "https://openalex.org/", "");
    idVals = idVals(idVals ~= "");
    if ~isempty(idVals)
        ids = strjoin(idVals, " | ");
    end
end
end

function [lastAuthorName, names, ids] = local_extract_last_author_institutions(work)
% Extracts the name and affiliations of the last author (last element of authorships).
% If there is only one author, the result equals first_author.
lastAuthorName = "";
names = "";
ids = "";
if ~isfield(work, 'authorships') || isempty(work.authorships)
    return;
end

auths = work.authorships;
lastAuth = auths(end);
if isfield(lastAuth, 'author') && ~isempty(lastAuth.author)
    a = lastAuth.author;
    if isfield(a, 'display_name') && ~isempty(a.display_name)
        lastAuthorName = string(a.display_name);
    end
end
if ~isfield(lastAuth, 'institutions') || isempty(lastAuth.institutions)
    return;
end

insts = lastAuth.institutions;
vals = strings(0,1);
idVals = strings(0,1);
for i = 1:numel(insts)
    inst = insts(i);
    if isfield(inst, 'display_name') && ~isempty(inst.display_name)
        vals(end+1) = string(inst.display_name); %#ok<AGROW>
    end
    if isfield(inst, 'id') && ~isempty(inst.id)
        idVals(end+1) = string(inst.id); %#ok<AGROW>
    end
end
if ~isempty(vals)
    names = strjoin(vals, " | ");
end
if ~isempty(idVals)
    idVals = replace(lower(strtrim(idVals)), "https://openalex.org/", "");
    idVals = idVals(idVals ~= "");
    if ~isempty(idVals)
        ids = strjoin(idVals, " | ");
    end
end
end

function tf = local_match_first_author_institution_names(instNames, targets)
targets = string(targets);
targets = lower(strtrim(targets));
targets = targets(targets ~= "");
if isempty(targets)
    tf = true;
    return;
end

instText = lower(string(instNames));
tf = false;
for k = 1:numel(targets)
    if contains(instText, targets(k))
        tf = true;
        return;
    end
end
end

function tf = local_match_first_author_institution_ids(instIds, targets)
targets = local_resolve_first_author_ids(targets);
if isempty(targets)
    tf = true;
    return;
end

idText = lower(string(instIds));
idText = replace(idText, "https://openalex.org/", "");
idText = replace(idText, "http://openalex.org/", "");
tf = false;
for k = 1:numel(targets)
    if contains(idText, targets(k))
        tf = true;
        return;
    end
end
end

function rawJson = local_webread_with_retry(url, timeoutSec)
% Retry only 429 / 503 responses with backoff and rate-limit awareness.
maxRetry   = 3;
baseDelay  = 2.0;
maxDelay   = 5.0;
rawJson    = "";
lastEx     = [];
for attempt = 1:maxRetry
    try
        rawJson = webread(char(url), weboptions('Timeout', timeoutSec, 'ContentType', 'text'));
        return;
    catch ex
        lastEx = ex;
        msg = string(ex.message);
        isRetryable = contains(msg, "429") || contains(msg, "503") || ...
                      contains(msg, "Too Many Requests") || contains(msg, "Service Unavailable");
        if ~isRetryable || attempt == maxRetry
            rethrow(ex);
        end
        waitSec = local_compute_retry_wait_seconds(msg, attempt, baseDelay, maxDelay, url);
        log_warn("OpenAlex API error (attempt %d/%d). Retrying in %.0f seconds: %s", ...
            attempt, maxRetry, waitSec, msg);
        pause(waitSec);
    end
end
if ~isempty(lastEx)
    rethrow(lastEx);
end

function waitSec = local_compute_retry_wait_seconds(msg, attempt, baseDelay, maxDelay, url)
waitSec = min(maxDelay, baseDelay * (2 ^ (attempt - 1)));

if ~(contains(msg, "429") || contains(msg, "Too Many Requests"))
    return;
end

retryAfterSec = local_parse_retry_after_seconds(msg);
if ~isnan(retryAfterSec)
    waitSec = max(waitSec, retryAfterSec);
    return;
end

apiKey = local_extract_query_param(url, "api_key");
rateInfo = get_openalex_rate_limit_status(apiKey, 8);
if ~rateInfo.ok
    return;
end

if ~isnan(rateInfo.resets_in_seconds)
    waitSec = max(waitSec, rateInfo.resets_in_seconds);
end
end

function val = local_extract_query_param(url, key)
val = "";
pattern = "(?:\?|&)" + regexptranslate("escape", key) + "=([^&]+)";
tokens = regexp(char(url), pattern, "tokens", "once");
if isempty(tokens)
    return;
end
val = string(urldecode(tokens{1}));
end

function waitSec = local_parse_retry_after_seconds(msg)
waitSec = NaN;
patterns = { ...
    'Retry-After[^0-9]*(\d+)', ...
    'retry after[^0-9]*(\d+)', ...
    'try again in[^0-9]*(\d+)\s*seconds?'};
for i = 1:numel(patterns)
    tokens = regexp(char(msg), patterns{i}, 'tokens', 'once', 'ignorecase');
    if isempty(tokens)
        continue;
    end
    parsed = str2double(tokens{1});
    if ~isnan(parsed) && parsed >= 0
        waitSec = parsed;
        return;
    end
end
end
end

function val = local_get_nested_numeric(s, fieldPath)
val = nan;
node = s;
for i = 1:numel(fieldPath)
    key = fieldPath{i};
    if ~isstruct(node) || ~isfield(node, key)
        return;
    end
    node = node.(key);
    if isempty(node)
        return;
    end
end
if isnumeric(node) || islogical(node)
    val = double(node);
else
    parsed = str2double(string(node));
    if ~isnan(parsed)
        val = parsed;
    end
end
end

function txt = local_get_json_text(s, fieldName)
txt = "";
if ~isfield(s, fieldName)
    return;
end
v = s.(fieldName);
if isempty(v)
    return;
end
if ischar(v) || isstring(v)
    txt = string(v);
    return;
end
try
    txt = string(jsonencode(v));
catch
    txt = string(v);
end
end

function url = local_get_best_oa_pdf_url(w)
url = "";
if isfield(w, 'best_oa_location') && ~isempty(w.best_oa_location) && isstruct(w.best_oa_location)
    if isfield(w.best_oa_location, 'pdf_url') && ~isempty(w.best_oa_location.pdf_url)
        url = string(w.best_oa_location.pdf_url);
    end
end
end

function val = local_get_best_oa_license(w)
val = "";
if isfield(w, 'best_oa_location') && ~isempty(w.best_oa_location) && isstruct(w.best_oa_location)
    if isfield(w.best_oa_location, 'license') && ~isempty(w.best_oa_location.license)
        val = string(w.best_oa_location.license);
    end
end
end

function local_maybe_save_raw_page(rawPageJson, pageNum, saveRawResponses, rawResponseDir)
if ~saveRawResponses
    return;
end
targetDir = strtrim(string(rawResponseDir));
if targetDir == ""
    return;
end
try
    if ~isfolder(targetDir)
        mkdir(targetDir);
    end
    filePath = fullfile(targetDir, sprintf('openalex_page_%03d.json', pageNum));
    fid = fopen(filePath, 'w', 'n', 'UTF-8');
    if fid < 0
        error("fetch_openalex_works:RawSaveOpenFailed", "Cannot open file: %s", filePath);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fwrite(fid, char(string(rawPageJson)), 'char');
catch ex
    log_warn("Failed to save OpenAlex raw response page %d (continuing): %s", pageNum, ex.message);
end
end
