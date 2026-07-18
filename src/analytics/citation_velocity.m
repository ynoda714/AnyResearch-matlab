function result = citation_velocity(T, options)
% CITATION_VELOCITY  Per-paper and corpus-level citation velocity metrics.
%
%   Citation velocity prefers measured OpenAlex yearly citation counts:
%     velocity_i = latest counts_by_year.cited_by_count at or before currentYear
%
%   When counts_by_year is absent or not parseable, it falls back to:
%     cited_by_count_i / max(1, currentYear - publication_year_i + 1)
%
%   Usage:
%     result = citation_velocity(T)
%     result = citation_velocity(T, currentYear=2025)
%
%   Input:
%     T — MATLAB table containing at minimum:
%           publication_year (numeric)
%           cited_by_count   (numeric)
%         Optional column:
%           openalex_id      (string)
%           counts_by_year   (string JSON array from OpenAlex)
%
%   Options:
%     currentYear  (double, default: current calendar year)
%                  Reference year for computing paper age.
%
%   Output (struct):
%     .per_paper    table: openalex_id | publication_year | cited_by_count |
%                          citation_velocity
%     .by_year      table: year | paper_count | avg_citation_velocity |
%                          median_citation_velocity
%     .current_year double: reference year used

arguments
    T table
    options.currentYear (1,1) double = year(datetime('today'))
end

result = struct();
result.current_year = options.currentYear;
result.per_paper    = table();
result.by_year      = table();

if height(T) == 0
    return;
end

n         = height(T);
hasYear   = ismember('publication_year', T.Properties.VariableNames);
hasCited  = ismember('cited_by_count',   T.Properties.VariableNames);
hasId     = ismember('openalex_id',      T.Properties.VariableNames);
hasCounts = ismember('counts_by_year',   T.Properties.VariableNames);

pubYear    = local_numeric_col(T, 'publication_year', hasYear, n);
citedCount = local_numeric_col(T, 'cited_by_count',   hasCited, n);
opId       = local_string_col(T,  'openalex_id',      hasId,   n);
countsJson = local_string_col(T,  'counts_by_year',   hasCounts, n);

age      = max(1, options.currentYear - pubYear + 1);
velocity = citedCount ./ age;

for i = 1:n
    measuredVelocity = local_latest_yearly_citations(countsJson(i), options.currentYear);
    if ~isnan(measuredVelocity)
        velocity(i) = measuredVelocity;
    end
end

% Mark rows where either input is missing
invalidMask = isnan(citedCount) | isnan(pubYear);
velocity(invalidMask) = NaN;

result.per_paper = table( ...
    opId, pubYear, citedCount, velocity, ...
    'VariableNames', {'openalex_id','publication_year','cited_by_count','citation_velocity'});

% Corpus-level by_year
validYears = sort(unique(pubYear(~isnan(pubYear))));
nY = numel(validYears);
if nY == 0
    return;
end

yr_vec  = nan(nY, 1);
cnt_vec = nan(nY, 1);
avg_vel = nan(nY, 1);
med_vel = nan(nY, 1);

for i = 1:nY
    yr   = validYears(i);
    mask = (pubYear == yr);
    v    = velocity(mask);
    v    = v(~isnan(v));

    yr_vec(i)  = yr;
    cnt_vec(i) = nnz(mask);
    if ~isempty(v)
        avg_vel(i) = mean(v);
        med_vel(i) = median(v);
    end
end

result.by_year = table( ...
    yr_vec, cnt_vec, avg_vel, med_vel, ...
    'VariableNames', {'year','paper_count','avg_citation_velocity','median_citation_velocity'});

end

% ── Local helpers ────────────────────────────────────────────────────────

function v = local_numeric_col(T, colName, hasCol, n)
if hasCol
    raw = T.(colName);
    if iscell(raw)
        raw = cell2mat(raw);
    end
    v = double(raw);
else
    v = nan(n, 1);
end
end

function v = local_string_col(T, colName, hasCol, n)
if hasCol
    v = string(T.(colName));
else
    v = repmat("", n, 1);
end
end

function v = local_latest_yearly_citations(countsJson, currentYear)
v = NaN;
txt = strtrim(string(countsJson));
if txt == "" || ismissing(txt)
    return;
end

try
    rows = jsondecode(char(txt));
catch
    return;
end

if isempty(rows)
    return;
end

latestYear = -inf;
latestCount = NaN;
for i = 1:numel(rows)
    row = rows(i);
    if ~isstruct(row) || ~isfield(row, 'year') || ~isfield(row, 'cited_by_count')
        continue;
    end
    yr = double(row.year);
    ct = double(row.cited_by_count);
    if isnan(yr) || isnan(ct) || yr > currentYear
        continue;
    end
    if yr > latestYear
        latestYear = yr;
        latestCount = ct;
    end
end

if isfinite(latestYear)
    v = latestCount;
end
end
