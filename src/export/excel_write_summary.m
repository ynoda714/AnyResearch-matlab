function spec = excel_write_summary(T, cfg)
%EXCEL_WRITE_SUMMARY  Builds the data specification (spec) for the Summary sheet.
%
%   spec = excel_write_summary(T, cfg)
%
%   T   — MATLAB table (data loaded from search_results JSONL or CSV)
%   cfg — Runtime config struct (cfg.top_n specifies Top N count; default 10)
%
%   Returns spec:
%     .sheetName    (string)       — 'Summary'
%     .headers      (cell 1xN)    — Header row (padded to nCols=6)
%     .data         (cell nRowsxN)— Vertically stacked data of Sections 1-3
%     .hyperlinks   (struct array) — empty
%     .nCols        (double)       — 6
%     .sectionRows  (double array) — Full-data row numbers (1-indexed) where bold style is applied
%
%   Sheet layout (3 Sections):
%     [Section 1] Annual Statistics
%       year / paper_count / avg_cited_by_count / max_cited_by_count / oa_count
%     [blank row]
%     [Section 2] Top N Papers by Citations  (L0-4)
%       rank / title / doi / publication_year / cited_by_count / source_name
%     [blank row]
%     [Section 3] Top N Journals by Paper Count  (L0-5)
%       rank / source_name / paper_count / avg_cited_by_count / oa_count

arguments
    T   table
    cfg struct = struct()
end

% topN: get from cfg.top_n (default 10)
topN = 10;
if isfield(cfg, 'top_n') && isnumeric(cfg.top_n) && cfg.top_n > 0
    topN = round(cfg.top_n);
end

% nCols=8: Section 1 has 8 columns (year/paper_count/avg_cited/max_cited/oa_count/
%           avg_citation_velocity/growth_rate_pct/empty); other sections padded to 8.
nCols      = 8;
hyperlinks = struct('row', {}, 'col', {}, 'url', {}, 'display', {});

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  Pre-compute analytics (citation_velocity / topic_growth_rate)
%  from cfg.analytics (populated by export_excel_workbook) or fallback
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
cvResult = struct('per_paper', table(), 'by_year', table());
tgrResult = struct('by_year', table());
if isfield(cfg, 'analytics')
    if isfield(cfg.analytics, 'citation_velocity')
        cvResult  = cfg.analytics.citation_velocity;
    end
    if isfield(cfg.analytics, 'topic_growth_rate')
        tgrResult = cfg.analytics.topic_growth_rate;
    end
end

% Build year -> avg_citation_velocity map from cvResult.by_year
cvYearMap  = containers.Map('KeyType','double','ValueType','double');
tgrYearMap = containers.Map('KeyType','double','ValueType','double');
if istable(cvResult.by_year) && height(cvResult.by_year) > 0 && ...
        ismember('avg_citation_velocity', cvResult.by_year.Properties.VariableNames)
    byYearCV = cvResult.by_year;
    for ri = 1:height(byYearCV)
        yrKey = double(byYearCV.year(ri));
        val   = double(byYearCV.avg_citation_velocity(ri));
        if ~isnan(yrKey) && ~isnan(val)
            cvYearMap(yrKey) = val;
        end
    end
end
if istable(tgrResult.by_year) && height(tgrResult.by_year) > 0 && ...
        ismember('growth_rate_pct', tgrResult.by_year.Properties.VariableNames)
    byYearTGR = tgrResult.by_year;
    for ri = 1:height(byYearTGR)
        yrKey = double(byYearTGR.year(ri));
        val   = double(byYearTGR.growth_rate_pct(ri));
        if ~isnan(yrKey)
            tgrYearMap(yrKey) = val;
        end
    end
end

% Build openalex_id -> citation_velocity map from cvResult.per_paper
cvPerPaperMap = containers.Map('KeyType','char','ValueType','double');
if istable(cvResult.per_paper) && height(cvResult.per_paper) > 0 && ...
        ismember('openalex_id', cvResult.per_paper.Properties.VariableNames) && ...
        ismember('citation_velocity', cvResult.per_paper.Properties.VariableNames)
    pPaper = cvResult.per_paper;
    for ri = 1:height(pPaper)
        k = char(string(pPaper.openalex_id(ri)));
        v = double(pPaper.citation_velocity(ri));
        if ~isempty(k) && ~isnan(v)
            cvPerPaperMap(k) = v;
        end
    end
end

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  Section 1: Annual Statistics
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
headers = {'year', 'paper_count', 'avg_cited_by_count', 'max_cited_by_count', ...
           'oa_count', 'avg_citation_velocity', 'growth_rate_pct', ''};

hasOa    = ismember('is_oa',            T.Properties.VariableNames);
hasCited = ismember('cited_by_count',   T.Properties.VariableNames);
hasYear  = ismember('publication_year', T.Properties.VariableNames);
hasSrc   = ismember('source_name',      T.Properties.VariableNames);
hasTitle = ismember('title',            T.Properties.VariableNames);
hasDoi   = ismember('doi',              T.Properties.VariableNames);
hasOaId  = ismember('openalex_id',      T.Properties.VariableNames);

if hasYear
    years = T.publication_year;
    if iscell(years)
        years = cell2mat(years);
    end
    years = double(years);
    validYears = sort(unique(years(~isnan(years))));
else
    validYears = [];
end

if ~hasYear || isempty(validYears)
    sec1Data = {'(no publication_year column)', '', '', '', '', '', '', ''};
    nY = 1;
else
    nY   = numel(validYears);
    sec1Data = cell(nY, nCols);

    for i = 1:nY
        yr   = validYears(i);
        mask = (years == yr);
        cnt  = nnz(mask);

        if hasCited
            cited = double(T.cited_by_count(mask));
            cited = cited(~isnan(cited));
            avgC = local_safe_mean(cited);
            maxC = local_safe_max(cited);
        else
            avgC = '';  maxC = '';
        end

        oaCnt = local_oa_count(T, mask, hasOa);

        % avg_citation_velocity from analytics
        if isKey(cvYearMap, double(yr))
            avgVel = round(cvYearMap(double(yr)), 2);
        else
            avgVel = '';
        end
        % growth_rate_pct from analytics
        if isKey(tgrYearMap, double(yr))
            growthPct = round(tgrYearMap(double(yr)), 1);
        else
            growthPct = '';
        end

        sec1Data{i,1} = yr;   sec1Data{i,2} = cnt;
        sec1Data{i,3} = avgC; sec1Data{i,4} = maxC;
        sec1Data{i,5} = oaCnt;
        sec1Data{i,6} = avgVel;
        sec1Data{i,7} = growthPct;
        sec1Data{i,8} = '';
    end

    % Total row
    if hasCited
        allCited = double(T.cited_by_count);
        allCited = allCited(~isnan(allCited));
        totalAvg = local_safe_mean(allCited);
        totalMax = local_safe_max(allCited);
    else
        totalAvg = '';  totalMax = '';
    end
    totalOa = local_oa_count(T, true(height(T),1), hasOa);
    % Overall avg_citation_velocity (all years combined)
    if ~isempty(cvYearMap)
        allCV = cell2mat(values(cvYearMap));
        totalAvgVel = round(mean(allCV), 2);
    else
        totalAvgVel = '';
    end
    sec1Data(end+1,:) = {'Total', height(T), totalAvg, totalMax, totalOa, totalAvgVel, '', ''};
    nY = nY + 1;  % Update row count including total row
end

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  Section 2: Top N Papers by Citations
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sec2SubHeader = {'rank', 'title', 'doi', 'publication_year', 'cited_by_count', ...
                 'citation_velocity', 'source_name', ''};

if hasCited && height(T) > 0
    citedAll = double(T.cited_by_count);
    [~, sortIdx] = sort(citedAll, 'descend', 'MissingPlacement','last');
    topIdx = sortIdx(1:min(topN, numel(sortIdx)));
    topN2  = numel(topIdx);
    sec2Data = cell(topN2, nCols);
    for i = 1:topN2
        ri = topIdx(i);
        sec2Data{i,1} = i;
        sec2Data{i,2} = local_get_str(T, 'title',            ri, hasTitle);
        sec2Data{i,3} = local_get_str(T, 'doi',              ri, hasDoi);
        sec2Data{i,4} = local_get_num(T, 'publication_year', ri, hasYear);
        sec2Data{i,5} = local_get_num(T, 'cited_by_count',   ri, hasCited);
        % citation_velocity from per-paper map
        oaId = '';
        if hasOaId
            oaId = char(string(T.openalex_id(ri)));
        end
        if ~isempty(oaId) && isKey(cvPerPaperMap, oaId)
            sec2Data{i,6} = round(cvPerPaperMap(oaId), 2);
        else
            sec2Data{i,6} = '';
        end
        sec2Data{i,7} = local_get_str(T, 'source_name', ri, hasSrc);
        sec2Data{i,8} = '';
    end
else
    sec2Data = {'(no cited_by_count data)', '', '', '', '', '', '', ''};
    topN2 = 1;
end

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  Section 3: Top N Journals by Paper Count
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sec3SubHeader = {'rank', 'source_name', 'paper_count', 'avg_cited_by_count', 'oa_count', '', '', ''};

if hasSrc && height(T) > 0
    srcNames = string(T.source_name);
    srcNames(srcNames == "" | ismissing(srcNames)) = "(unknown)";
    uSrc = unique(srcNames, 'stable');
    jData = cell(numel(uSrc), 4);
    for i = 1:numel(uSrc)
        mask = (srcNames == uSrc(i));
        cnt  = nnz(mask);
        if hasCited
            cited = double(T.cited_by_count(mask));
            cited = cited(~isnan(cited));
            avgC = local_safe_mean(cited);
        else
            avgC = '';
        end
        oaCnt = local_oa_count(T, mask, hasOa);
        jData{i,1} = uSrc(i);
        jData{i,2} = cnt;
        jData{i,3} = avgC;
        jData{i,4} = oaCnt;
    end
    cnts = cell2mat(jData(:,2));
    [~, jIdx] = sort(cnts, 'descend');
    jIdx = jIdx(1:min(topN, numel(jIdx)));
    topN3 = numel(jIdx);
    sec3Data = cell(topN3, nCols);
    for i = 1:topN3
        ji = jIdx(i);
        sec3Data{i,1} = i;
        sec3Data{i,2} = jData{ji,1};
        sec3Data{i,3} = jData{ji,2};
        sec3Data{i,4} = jData{ji,3};
        sec3Data{i,5} = jData{ji,4};
        sec3Data{i,6} = ''; sec3Data{i,7} = ''; sec3Data{i,8} = '';
    end
else
    sec3Data = {'(no source_name data)', '', '', '', '', '', '', ''};
    topN3 = 1;
end

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  Section 4: Top N Papers by Citation Velocity
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sec4SubHeader = {'rank', 'title', 'doi', 'publication_year', 'cited_by_count', ...
                 'citation_velocity', 'source_name', ''};

hasCvData = istable(cvResult.per_paper) && height(cvResult.per_paper) > 0 && ...
            ismember('citation_velocity', cvResult.per_paper.Properties.VariableNames);

if hasCvData && height(T) > 0
    % Join velocity back to T rows via openalex_id
    velocities = nan(height(T), 1);
    if hasOaId
        oaIds = string(T.openalex_id);
        for ri = 1:height(T)
            k = char(oaIds(ri));
            if ~isempty(k) && isKey(cvPerPaperMap, k)
                velocities(ri) = cvPerPaperMap(k);
            end
        end
    end
    validVelMask = ~isnan(velocities);
    if any(validVelMask)
        [~, velSortIdx] = sort(velocities, 'descend', 'MissingPlacement','last');
        velTopIdx = velSortIdx(1:min(topN, nnz(validVelMask)));
        topN4 = numel(velTopIdx);
        sec4Data = cell(topN4, nCols);
        for i = 1:topN4
            ri = velTopIdx(i);
            sec4Data{i,1} = i;
            sec4Data{i,2} = local_get_str(T, 'title',            ri, hasTitle);
            sec4Data{i,3} = local_get_str(T, 'doi',              ri, hasDoi);
            sec4Data{i,4} = local_get_num(T, 'publication_year', ri, hasYear);
            sec4Data{i,5} = local_get_num(T, 'cited_by_count',   ri, hasCited);
            sec4Data{i,6} = round(velocities(ri), 2);
            sec4Data{i,7} = local_get_str(T, 'source_name',      ri, hasSrc);
            sec4Data{i,8} = '';
        end
    else
        sec4Data = {'(no citation_velocity data)', '', '', '', '', '', '', ''};
        topN4 = 1;
    end
else
    sec4Data = {'(citation_velocity not computed)', '', '', '', '', '', '', ''};
    topN4 = 1;
end

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  Stack all data and calculate sectionRows
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
emptyRow  = repmat({''}, 1, nCols);
sec2Label = [sprintf('Top %d Papers by Citations', topN), repmat({''}, 1, nCols-1)];
sec3Label = [sprintf('Top %d Journals by Paper Count', topN), repmat({''}, 1, nCols-1)];
sec4Label = [sprintf('Top %d Papers by Citation Velocity', topN), repmat({''}, 1, nCols-1)];

data = [
    sec1Data;
    emptyRow;
    sec2Label;
    sec2SubHeader;
    sec2Data;
    emptyRow;
    sec3Label;
    sec3SubHeader;
    sec3Data;
    emptyRow;
    sec4Label;
    sec4SubHeader;
    sec4Data
];

% fullData row numbers (1-indexed; headers = row 1, so data row number + 1)
sec2LabelRow = 1 + nY + 1 + 1;
sec2SubHdrRow = sec2LabelRow + 1;
sec3LabelRow  = sec2SubHdrRow + topN2 + 1 + 1;
sec3SubHdrRow = sec3LabelRow + 1;
sec4LabelRow  = sec3SubHdrRow + topN3 + 1 + 1;
sec4SubHdrRow = sec4LabelRow + 1;

sectionRows = [sec2LabelRow, sec2SubHdrRow, sec3LabelRow, sec3SubHdrRow, ...
               sec4LabelRow, sec4SubHdrRow];

spec = struct();
spec.sheetName   = 'Summary';
spec.headers     = headers;
spec.data        = data;
spec.hyperlinks  = hyperlinks;
spec.nCols       = nCols;
spec.sectionRows = sectionRows;
end

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  Local helpers
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function v = local_safe_mean(arr)
if isempty(arr);  v = '';  return;  end
v = round(mean(arr), 1);
end

function v = local_safe_max(arr)
if isempty(arr);  v = '';  return;  end
v = max(arr);
end

function cnt = local_oa_count(T, mask, hasOa)
if ~hasOa;  cnt = '';  return;  end
oaVals = T.is_oa(mask);
if islogical(oaVals) || isnumeric(oaVals)
    cnt = nnz(oaVals == 1 | oaVals == true);
elseif isstring(oaVals) || iscell(oaVals)
    sv = lower(strtrim(string(oaVals)));
    cnt = nnz(sv == "true" | sv == "1");
else
    cnt = '';
end
end

function v = local_get_str(T, col, rowIdx, hasCol)
if ~hasCol;  v = '';  return;  end
raw = T.(col)(rowIdx);
if (isstring(raw) || iscell(raw)) && all(ismissing(raw))
    v = '';
else
    v = char(string(raw));
end
end

function v = local_get_num(T, col, rowIdx, hasCol)
if ~hasCol;  v = '';  return;  end
raw = T.(col)(rowIdx);
if isnumeric(raw)
    v = double(raw);
elseif isstring(raw) || ischar(raw)
    n = str2double(string(raw));
    v = n;
else
    v = '';
end
end
