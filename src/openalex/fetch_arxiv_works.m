function [worksTable, meta] = fetch_arxiv_works(opts)
% FETCH_ARXIV_WORKS  Fetches preprint metadata from the arXiv API.
%
% arXiv API: http://export.arxiv.org/api/query  (free, no authentication)
% Returns Atom 1.0 XML. Rate-limit: >= 3 seconds between paginated requests.
%
% Options:
%   searchQuery       (string) -- Search terms. Accepts same syntax as main_run_pipeline
%                                  query: spaces = AND, | = OR, "phrase" = phrase match.
%   category          (string) -- arXiv subject category e.g. "cs.LG". "" = no filter.
%   fromDate          (string) -- Start date "YYYY-MM-DD". "" = no filter.
%   toDate            (string) -- End date "YYYY-MM-DD". "" = no filter.
%   maxResults        (double) -- Max records to fetch (1-2000 per request). Default 100.
%   sortBy            (string) -- "submittedDate" | "relevance" | "lastUpdatedDate"
%   sortOrder         (string) -- "descending" | "ascending"
%   delayBetweenPages (double) -- Delay (sec) between paginated requests (arXiv ToS: >= 3s).
%
% Returns:
%   worksTable -- table with columns:
%     arxiv_id, title, abstract, published, doi, pdf_url,
%     primary_category, journal_ref, authors, affiliations
%   meta.total_count   -- int32 from <opensearch:totalResults>
%   meta.fetched_count -- int32 actual rows returned

arguments
    opts.searchQuery       (1,1) string = ""
    opts.category          (1,1) string = ""
    opts.fromDate          (1,1) string = ""
    opts.toDate            (1,1) string = ""
    opts.maxResults        (1,1) double = 100
    opts.sortBy            (1,1) string = "submittedDate"
    opts.sortOrder         (1,1) string = "descending"
    opts.delayBetweenPages (1,1) double = 3
    opts.saveRawResponse   (1,1) logical = false
    opts.rawResponsePath   (1,1) string = ""
end

BASE_URL  = "http://export.arxiv.org/api/query";
PAGE_SIZE = 200;  % records per single request (arXiv allows up to 2000)

searchQ = local_build_arxiv_query( ...
    opts.searchQuery, opts.category, opts.fromDate, opts.toDate);
if searchQ == ""
    error("fetch_arxiv_works:EmptyQuery", ...
        "searchQuery (or category/date filter) must be non-empty.");
end

COL_NAMES = {'arxiv_id','title','abstract','published','doi','pdf_url', ...
             'primary_category','journal_ref','authors','affiliations'};
rowCells   = cell(0, 10);
totalCount = int32(-1);
fetched    = 0;
startIdx   = 0;
xmlPages    = strings(0, 1);

while fetched < opts.maxResults
    batchSize = min(PAGE_SIZE, opts.maxResults - fetched);
    url = BASE_URL ...
        + "?search_query=" + searchQ ...
        + "&max_results=" + string(batchSize) ...
        + "&start=" + string(startIdx) ...
        + "&sortBy=" + opts.sortBy ...
        + "&sortOrder=" + opts.sortOrder;

    log_info("arXiv fetch: start=%d, max_results=%d", startIdx, batchSize);
    xmlText = local_webread_arxiv(url);
    xmlPages(end+1, 1) = string(xmlText); %#ok<AGROW>

    if totalCount < 0
        totalCount = local_parse_total_results(xmlText);
    end

    entries = local_parse_entries(xmlText);
    if isempty(entries)
        break;
    end

    for k = 1:numel(entries)
        e = entries{k};
        rowCells(end+1, :) = { ...
            e.arxiv_id, e.title, e.abstract, e.published, ...
            e.doi, e.pdf_url, e.primary_category, e.journal_ref, ...
            e.authors, e.affiliations ...
            }; %#ok<AGROW>
    end

    fetched  = fetched + numel(entries);
    startIdx = startIdx + numel(entries);

    % Stop if fewer entries than requested (last page) or already met total
    if numel(entries) < batchSize || (totalCount >= 0 && fetched >= double(totalCount))
        break;
    end

    pause(opts.delayBetweenPages);
end

if isempty(rowCells)
    worksTable = table('Size', [0 10], ...
        'VariableTypes', repmat({'string'}, 1, 10), ...
        'VariableNames', COL_NAMES);
else
    worksTable = cell2table(rowCells, 'VariableNames', COL_NAMES);
    for fi = 1:numel(COL_NAMES)
        worksTable.(COL_NAMES{fi}) = string(worksTable.(COL_NAMES{fi}));
    end
end

meta = struct();
meta.total_count   = totalCount;
meta.fetched_count = int32(height(worksTable));
meta.raw_response_path = "";
if opts.saveRawResponse && strlength(strtrim(opts.rawResponsePath)) > 0
    meta.raw_response_path = local_save_raw_arxiv_response(xmlPages, opts.rawResponsePath);
end
end

function savedPath = local_save_raw_arxiv_response(xmlPages, rawResponsePath)
savedPath = "";
try
    outPath = string(rawResponsePath);
    outDir = fileparts(outPath);
    if strlength(outDir) > 0 && ~isfolder(outDir)
        mkdir(outDir);
    end
    fid = fopen(outPath, 'w', 'n', 'UTF-8');
    if fid < 0
        error("fetch_arxiv_works:RawSaveOpenFailed", "Cannot open file: %s", outPath);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    for i = 1:numel(xmlPages)
        if i > 1
            fprintf(fid, '\n<!-- page-break -->\n');
        end
        fwrite(fid, char(xmlPages(i)), 'char');
    end
    savedPath = outPath;
catch ex
    log_warn("Failed to save arXiv raw response (continuing): %s", ex.message);
end
end

% ─── Local: Query builder ─────────────────────────────────────────────────────

function q = local_build_arxiv_query(searchQuery, category, fromDate, toDate)
% Converts OpenAlex-style query string to arXiv search_query URL segment.
%
% Conversion rules (applied in order):
%   1. "phrase" (double-quoted) -> all:%22phrase%22
%   2. | (pipe) between terms   -> +OR+
%   3. space between terms      -> +AND+
%   4. each token prefixed with all:
% Then appends date filter (submittedDate) and category filter if specified.

q  = "";
sq = strtrim(searchQuery);

if sq ~= ""
    % Step 1: Extract quoted phrases and replace with placeholders
    phrases      = {};
    placeholders = {};
    phIdx = 1;
    while true
        [tok, tokStart, tokEnd] = regexp(sq, '"([^"]*)"', 'tokens', 'start', 'end', 'once');
        if isempty(tok)
            break;
        end
        ph    = sprintf('__PH%d__', phIdx);
        phIdx = phIdx + 1;
        sq    = [sq(1:tokStart-1), ph, sq(tokEnd+1:end)];
        phrases{end+1}      = tok{1}; %#ok<AGROW>
        placeholders{end+1} = ph;     %#ok<AGROW>
    end

    % Step 2-4: Split by | (OR groups), then by space (AND tokens), prefix all:
    orParts  = strsplit(sq, '|');
    orTokens = strings(0, 1);
    for oi = 1:numel(orParts)
        part     = strtrim(orParts{oi});
        andParts = strsplit(part, ' ');
        andToks  = strings(0, 1);
        for ai = 1:numel(andParts)
            t = strtrim(andParts{ai});
            if t == ""
                continue;
            end
            % Restore phrase placeholder -> all:%22encoded+phrase%22
            phMatched = false;
            for pi = 1:numel(placeholders)
                if t == placeholders{pi}
                    encoded = strrep(phrases{pi}, ' ', '+');
                    t = "all:%22" + encoded + "%22";
                    phMatched = true;
                    break;
                end
            end
            if ~phMatched
                t = "all:" + t;
            end
            andToks(end+1) = t; %#ok<AGROW>
        end
        if ~isempty(andToks)
            orTokens(end+1) = strjoin(andToks, "+AND+"); %#ok<AGROW>
        end
    end

    if ~isempty(orTokens)
        q = strjoin(orTokens, "+OR+");
    end
end

% Date filter: submittedDate:[YYYYMMDD0000+TO+YYYYMMDD2359]
fd = strtrim(fromDate);
td = strtrim(toDate);
if fd ~= "" || td ~= ""
    if fd == ""
        fd = "19000101";
    else
        fd = strrep(fd, "-", "");
    end
    fd = fd + "0000";
    if td == ""
        td = "21001231";
    else
        td = strrep(td, "-", "");
    end
    td = td + "2359";
    dateFilter = "submittedDate:[" + fd + "+TO+" + td + "]";
    if q == ""
        q = dateFilter;
    else
        q = q + "+AND+" + dateFilter;
    end
end

% Category filter: cat:<value>
cat = strtrim(category);
if cat ~= ""
    catFilter = "cat:" + cat;
    if q == ""
        q = catFilter;
    else
        q = q + "+AND+" + catFilter;
    end
end
end

% ─── Local: XML parsers ───────────────────────────────────────────────────────

function n = local_parse_total_results(xmlText)
% Extracts <opensearch:totalResults> from Atom feed text.
tok = regexp(char(xmlText), ...
    '<opensearch:totalResults[^>]*>(\d+)</opensearch:totalResults>', ...
    'tokens', 'once');
if isempty(tok)
    n = int32(-1);
else
    n = int32(str2double(tok{1}));
end
end

function entries = local_parse_entries(xmlText)
% Splits Atom feed text into <entry> blocks and parses each one.
rawStr = char(xmlText);
[~, tok] = regexp(rawStr, '<entry>([\s\S]*?)</entry>', 'match', 'tokens');
entries = cell(numel(tok), 1);
for k = 1:numel(tok)
    entries{k} = local_parse_single_entry(tok{k}{1});
end
end

function e = local_parse_single_entry(text)
% Parses one <entry> block from arXiv Atom XML.
e = struct();

% arxiv_id: extract from <id>http://arxiv.org/abs/XXXX.XXXXXv1</id>
idTok = regexp(text, '<id>[^\n]*abs/([^\s<v]+)', 'tokens', 'once');
if isempty(idTok)
    e.arxiv_id = "";
else
    e.arxiv_id = strtrim(string(idTok{1}));
end

% title / abstract (summary)
e.title    = local_clean_whitespace(local_extract_text(text, 'title'));
e.abstract = local_clean_whitespace(local_extract_text(text, 'summary'));

% published (ISO 8601: "2023-01-15T00:00:00Z")
e.published = strtrim(local_extract_text(text, 'published'));

% doi: prefer <arxiv:doi> tag; fallback to <link title="doi" href="...">
doiTok = regexp(text, '<arxiv:doi[^>]*>([\s\S]*?)</arxiv:doi>', 'tokens', 'once');
if ~isempty(doiTok)
    e.doi = strtrim(string(doiTok{1}));
else
    hrefTok = regexp(text, '<link[^>]*title="doi"[^>]*href="([^"]*)"', 'tokens', 'once');
    if isempty(hrefTok)
        hrefTok = regexp(text, '<link[^>]*href="([^"]*)"[^>]*title="doi"', 'tokens', 'once');
    end
    if ~isempty(hrefTok)
        href    = string(hrefTok{1});
        doiPart = regexp(href, 'doi\.org/(.+)', 'tokens', 'once');
        if ~isempty(doiPart)
            e.doi = string(doiPart{1});
        else
            e.doi = href;
        end
    else
        e.doi = "";
    end
end

% pdf_url: <link title="pdf" href="..."> (attribute order may vary)
pdfTok = regexp(text, '<link[^>]*title="pdf"[^>]*href="([^"]*)"', 'tokens', 'once');
if isempty(pdfTok)
    pdfTok = regexp(text, '<link[^>]*href="([^"]*)"[^>]*title="pdf"', 'tokens', 'once');
end
if ~isempty(pdfTok)
    e.pdf_url = string(pdfTok{1});
else
    e.pdf_url = "";
end

% primary_category: <arxiv:primary_category term="cs.LG" .../>
catTok = regexp(text, '<arxiv:primary_category[^>]*term="([^"]*)"', 'tokens', 'once');
if isempty(catTok)
    % Fallback: first <category term="..."> (may include non-primary categories)
    catTok = regexp(text, '<category[^>]*term="([^"]*)"', 'tokens', 'once');
end
if ~isempty(catTok)
    e.primary_category = string(catTok{1});
else
    e.primary_category = "";
end

% journal_ref: <arxiv:journal_ref>...</arxiv:journal_ref>
jrefTok = regexp(text, '<arxiv:journal_ref[^>]*>([\s\S]*?)</arxiv:journal_ref>', 'tokens', 'once');
if ~isempty(jrefTok)
    e.journal_ref = strtrim(string(jrefTok{1}));
else
    e.journal_ref = "";
end

% authors / affiliations: each <author>...</author> block
[~, authToks] = regexp(text, '<author>([\s\S]*?)</author>', 'match', 'tokens');
authorNames  = strings(0, 1);
authorAffils = strings(0, 1);
for ai = 1:numel(authToks)
    aText   = authToks{ai}{1};
    nameTok = regexp(aText, '<name>([\s\S]*?)</name>', 'tokens', 'once');
    if ~isempty(nameTok)
        authorNames(end+1) = strtrim(string(nameTok{1})); %#ok<AGROW>
        % Affiliation is per-author and optional (self-reported, may be absent)
        affilTok = regexp(aText, '<arxiv:affiliation[^>]*>([\s\S]*?)</arxiv:affiliation>', 'tokens', 'once');
        if ~isempty(affilTok)
            authorAffils(end+1) = strtrim(string(affilTok{1})); %#ok<AGROW>
        else
            authorAffils(end+1) = ""; %#ok<AGROW>
        end
    end
end

if isempty(authorNames)
    e.authors      = "";
    e.affiliations = "";
else
    e.authors      = strjoin(authorNames,  "; ");
    e.affiliations = strjoin(authorAffils, "; ");
end
end

function text = local_extract_text(xmlBlock, tagName)
% Extracts inner text of first matching <tagName>...</tagName>.
tok = regexp(xmlBlock, ['<', tagName, '[^>]*>([\s\S]*?)</', tagName, '>'], ...
    'tokens', 'once');
if isempty(tok)
    text = "";
else
    text = string(tok{1});
end
end

function s = local_clean_whitespace(s)
s = regexprep(string(s), '\s+', ' ');
s = strtrim(s);
end

function xmlText = local_webread_arxiv(url)
% Fetches arXiv API response as text, with retry on 503/429.
wopts     = weboptions('ContentType', 'text', 'Timeout', 30, 'CharacterEncoding', 'UTF-8');
maxRetry  = 3;
baseDelay = 5;
lastEx    = [];
for attempt = 1:maxRetry
    try
        xmlText = webread(char(url), wopts);
        return;
    catch ex
        lastEx = ex;
        msg = string(ex.message);
        isRetryable = contains(msg, "503") || contains(msg, "429") || ...
                      contains(msg, "Service Unavailable") || contains(msg, "Too Many Requests");
        if ~isRetryable || attempt == maxRetry
            rethrow(ex);
        end
        waitSec = baseDelay * (2 ^ (attempt - 1));
        log_warn("arXiv API error (attempt %d/%d). Retry in %.0fs: %s", ...
            attempt, maxRetry, waitSec, msg);
        pause(waitSec);
    end
end
if ~isempty(lastEx)
    rethrow(lastEx);
end
end
