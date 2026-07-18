function spec = excel_write_overview(T, cfg)
%EXCEL_WRITE_OVERVIEW  Build the data specification (spec) for the Overview sheet
%
%   spec = excel_write_overview(T, cfg)
%
%   T   — MATLAB table (data loaded from search_results JSONL or CSV)
%   cfg — Runtime configuration struct (referenced only by this function)
%
%   Return value spec:
%     .sheetName  (string)       — 'Overview'
%     .headers    (cell 1×N)     — Header row (char values)
%     .data       (cell nRows×N) — Data (char / double, NaN→'')
%     .hyperlinks (struct array) — {row, col, url, display} (DOI links)
%
%   Column definition (11 columns):
%     title / DOI / publication_year / cited_by_count / fwci /
%     citation_percentile / repro_signal_score / is_oa / source_name / type / abstract
%
%   Notes:
%     - is_oa / source_name / type may not be present in the current pipeline output;
%       in that case they are displayed as empty strings
%     - Abstract is truncated to the first 500 characters (Overview is for quick browsing)

arguments
    T   table
    cfg struct = struct()
end

ABSTRACT_MAX = 500;
n = height(T);
keywords = local_extract_keywords(cfg);

headers = {'title', 'DOI', 'publication_year', 'cited_by_count', 'fwci', 'citation_percentile', 'repro_signal_score', 'is_oa', 'source_name', 'type', 'abstract'};
nCols   = numel(headers);
data    = cell(n, nCols);
hyperlinks = struct('row', {}, 'col', {}, 'url', {}, 'display', {});

for r = 1:n
    % 1: Title
    data{r,1} = local_str(T, 'title', r);

    % 2: DOI (hyperlink)
    doiVal = local_str(T, 'doi', r);
    data{r,2} = doiVal;
    if numel(doiVal) > 0
        hyperlinks(end+1) = struct( ...
            'row',     r + 1, ...
            'col',     2, ...
            'url',     ['https://doi.org/' doiVal], ...
            'display', doiVal); %#ok<AGROW>
    end

    % 3: Publication year
    data{r,3} = local_num(T, 'publication_year', r);

    % 4: Citation count
    data{r,4} = local_num(T, 'cited_by_count', r);

    % 5: FWCI
    data{r,5} = local_num(T, 'fwci', r);

    % 6: Citation percentile
    data{r,6} = local_num(T, 'citation_percentile', r);

    % 7: Repro signal score
    data{r,7} = local_num(T, 'repro_signal_score', r);

    % 8: OA flag
    data{r,8} = local_is_oa(T, r);

    % 9: Journal name (use source_dataset if source_name is absent)
    srcName = local_str(T, 'source_name', r);
    if isempty(srcName)
        srcName = local_str(T, 'source_dataset', r);
    end
    data{r,9} = srcName;

    % 10: Type
    data{r,10} = local_str(T, 'type', r);

    % 11: Abstract (first ABSTRACT_MAX chars, with keyword highlighting)
    absTxt = local_str(T, 'abstract', r);
    if length(absTxt) > ABSTRACT_MAX
        absTxt = [absTxt(1:ABSTRACT_MAX), '...'];
    end
    absTxt = local_highlight_keywords(absTxt, keywords);
    data{r,11} = absTxt;
end

spec = struct();
spec.sheetName  = 'Overview';
spec.headers    = headers;
spec.data       = data;
spec.hyperlinks = hyperlinks;
spec.nCols      = nCols;
end

% ─── Local helpers ────────────────────────────────────────────────

function v = local_str(T, col, row)
% Returns the value at column col, row row as char ('' if column is absent or value is missing)
v = '';
if ~ismember(col, T.Properties.VariableNames)
    return;
end
raw = T.(col)(row);
if isstring(raw)
    if ~ismissing(raw)
        v = char(raw);
    end
elseif ischar(raw)
    v = raw;
elseif isnumeric(raw) || islogical(raw)
    if ~isnan(double(raw))
        v = char(string(raw));
    end
end
end

function v = local_num(T, col, row)
% Return the numeric value at row 'row' in the specified column as double ('' if column absent or NaN)
v = '';
if ~ismember(col, T.Properties.VariableNames)
    return;
end
raw = T.(col)(row);
if isnumeric(raw) && isscalar(raw) && ~isnan(raw)
    v = double(raw);
elseif islogical(raw) && isscalar(raw)
    v = double(raw);
end
end

function keywords = local_extract_keywords(cfg)
% Extract keyword list from cfg.query (for highlighting)
keywords = {};
if ~isfield(cfg, 'query') || isempty(cfg.query)
    return;
end
q = strtrim(char(string(cfg.query)));
if isempty(q)
    return;
end
% Split by | for OR → split by space for AND → remove quotation marks
orParts = strsplit(q, '|');
for i = 1:numel(orParts)
    words = strsplit(strtrim(orParts{i}), ' ');
    for j = 1:numel(words)
        w = strtrim(words{j});
        w = regexprep(w, '^"|"|^''|''$', '');  % Remove quotation marks
        if length(w) >= 2
            keywords{end+1} = w; %#ok<AGROW>
        end
    end
end
keywords = unique(keywords, 'stable');
end

function txt = local_highlight_keywords(txt, keywords)
% Surround keywords in abstract text with 《keyword》 (case-insensitive)
if isempty(txt) || isempty(keywords)
    return;
end
for i = 1:numel(keywords)
    kw = keywords{i};
    if isempty(kw); continue; end
    % Escape special regex characters
    kw_esc = regexprep(kw, '([\\\^\$\.\|\?\*\+\(\)\{\}\[\]])', '\\$1');
    txt = regexprep(txt, ['(?i)(' kw_esc ')'], [char(12304) '$1' char(12305)]);
end
end

function s = local_is_oa(T, row)
% Convert the is_oa column to 'Yes' / 'No' / ''
s = '';
if ~ismember('is_oa', T.Properties.VariableNames)
    return;
end
raw = T.is_oa(row);
if islogical(raw)
    if raw; s = 'Yes'; else; s = 'No'; end
elseif isnumeric(raw)
    if raw == 1; s = 'Yes'; elseif raw == 0; s = 'No'; end
elseif isstring(raw) || ischar(raw)
    sv = lower(strtrim(char(string(raw))));
    if any(strcmp(sv, {'true','1','yes'}))
        s = 'Yes';
    elseif numel(sv) > 0
        s = 'No';
    end
end
end
