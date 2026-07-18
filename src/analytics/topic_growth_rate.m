function result = topic_growth_rate(T, options)
% TOPIC_GROWTH_RATE  Year-over-year publication volume growth for the corpus.
%
%   Computes the annual paper count and its year-over-year growth rate, which
%   serves as a proxy for research volume trend in the search results.
%
%   When a 'topics' column is present (pipe-delimited topic names per paper),
%   also computes per-topic growth broken down by year.
%
%   Note: True topic-level growth requires the 'topics' field to be stored in
%   the pipeline output. If absent, only aggregate growth is computed.
%
%   Usage:
%     result = topic_growth_rate(T)
%     result = topic_growth_rate(T, topicCol="topics", minPapers=3)
%
%   Input:
%     T — MATLAB table containing:
%           publication_year (numeric)
%         Optional column:
%           topics (string, pipe-delimited topic names per paper)
%
%   Options:
%     topicCol  (string, default: "topics")
%               Name of the column containing topic labels.
%     minPapers (double, default: 3)
%               Minimum total papers for a topic to appear in by_topic output.
%
%   Output (struct):
%     .by_year    table: year | paper_count | growth_rate_pct
%                 (growth_rate_pct = NaN for the first year)
%     .by_topic   table: topic | year | paper_count
%                 (empty table if topics column is absent or all-blank)
%     .has_topics logical: true when topic-level breakdown is available

arguments
    T table
    options.topicCol  (1,1) string = "topics"
    options.minPapers (1,1) double = 3
end

result = struct();
result.by_year   = table();
result.by_topic  = table();
result.has_topics = false;

if height(T) == 0
    return;
end

n       = height(T);
hasYear = ismember('publication_year', T.Properties.VariableNames);

if ~hasYear
    return;
end

pubYear = double(T.publication_year);
if iscell(pubYear)
    pubYear = cell2mat(pubYear);
end

validYears = sort(unique(pubYear(~isnan(pubYear))));
nY = numel(validYears);
if nY == 0
    return;
end

% ── Aggregate by_year ────────────────────────────────────────────────────
yr_vec    = nan(nY, 1);
cnt_vec   = nan(nY, 1);
growthPct = nan(nY, 1);

for i = 1:nY
    yr_vec(i)  = validYears(i);
    cnt_vec(i) = nnz(pubYear == validYears(i));
end

for i = 2:nY
    prev = cnt_vec(i-1);
    if prev > 0
        growthPct(i) = (cnt_vec(i) - prev) / prev * 100;
    end
end

result.by_year = table( ...
    yr_vec, cnt_vec, growthPct, ...
    'VariableNames', {'year','paper_count','growth_rate_pct'});

% ── Per-topic breakdown (only when topics column is available) ───────────
hasTopicCol = ismember(options.topicCol, T.Properties.VariableNames);
if ~hasTopicCol
    return;
end

topicRaw = string(T.(options.topicCol));
topicRaw(ismissing(topicRaw)) = "";

% Build (topic, year) count map
topicSet = containers.Map('KeyType','char','ValueType','any');

for i = 1:n
    yr = pubYear(i);
    if isnan(yr)
        continue;
    end
    parts = strtrim(strsplit(topicRaw(i), '|'));
    for k = 1:numel(parts)
        tp = char(parts(k));
        if isempty(tp)
            continue;
        end
        if isKey(topicSet, tp)
            m = topicSet(tp);
        else
            m = containers.Map('KeyType','double','ValueType','int32');
        end
        yrKey = double(yr);
        if isKey(m, yrKey)
            m(yrKey) = m(yrKey) + int32(1);
        else
            m(yrKey) = int32(1);
        end
        topicSet(tp) = m;
    end
end

if isempty(topicSet)
    return;
end

% Expand to flat table, filter by minPapers
topics   = {};
years    = [];
pCounts  = [];

tNames = keys(topicSet);
for k = 1:numel(tNames)
    tp = tNames{k};
    m  = topicSet(tp);
    total = sum(cell2mat(values(m)));
    if total < options.minPapers
        continue;
    end
    yrKeys = cell2mat(keys(m));
    for j = 1:numel(yrKeys)
        topics{end+1}  = tp;       %#ok<AGROW>
        years(end+1)   = yrKeys(j); %#ok<AGROW>
        pCounts(end+1) = double(m(yrKeys(j))); %#ok<AGROW>
    end
end

if isempty(topics)
    return;
end

result.by_topic = table( ...
    string(topics(:)), years(:), pCounts(:), ...
    'VariableNames', {'topic','year','paper_count'});
result.has_topics = true;

end
