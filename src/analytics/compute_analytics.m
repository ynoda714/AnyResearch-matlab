function result = compute_analytics(inputData, options)
% COMPUTE_ANALYTICS  Entry point for all analytics metrics.
%
%   Runs citation_velocity, topic_growth_rate, and institution_dominance
%   on the paper data from search_results JSONL/CSV or a pre-loaded table.
%
%   Usage:
%     result = compute_analytics("path/to/search_results.jsonl")
%     result = compute_analytics(T)              % pass MATLAB table directly
%     result = compute_analytics(..., topN=20)
%
%   Input:
%     inputData — Either:
%       (a) string: path to a JSONL or CSV file (search_results.jsonl preferred)
%       (b) MATLAB table: pre-loaded paper table
%
%   Options:
%     currentYear (double, default: current calendar year)
%     topN        (double, default: 20)  Top N institutions in dominance output
%     paperWeight (double, default: 0.5) Paper vs citation weight for dominance
%     topicCol    (string, default: "topics")  Column for topic-level breakdown
%     minPapersForTopic (double, default: 3)   Minimum papers per topic included
%
%   Output (struct):
%     .citation_velocity    struct from citation_velocity()
%     .topic_growth_rate    struct from topic_growth_rate()
%     .institution_dominance struct from institution_dominance()
%     .n_papers             double: total rows in input
%     .computed_at          string: ISO 8601 timestamp

arguments
    inputData
    options.currentYear       (1,1) double = year(datetime('today'))
    options.topN              (1,1) double = 20
    options.paperWeight       (1,1) double = 0.5
    options.topicCol          (1,1) string = "topics"
    options.minPapersForTopic (1,1) double = 3
end

% ── Load data ────────────────────────────────────────────────────────────
if ischar(inputData) || isstring(inputData)
    inputPath = string(inputData);
    if ~isfile(inputPath)
        error('compute_analytics:FileNotFound', 'Input file not found: %s', inputPath);
    end
    [~, ~, ext] = fileparts(inputPath);
    if lower(ext) == ".jsonl"
        T = read_jsonl(inputPath);
    else
        T = readtable(inputPath, 'TextType', 'string', ...
            'VariableNamingRule', 'preserve', 'Delimiter', ',');
    end
elseif istable(inputData)
    T = inputData;
else
    error('compute_analytics:InvalidInput', ...
        'inputData must be a file path (string) or a MATLAB table.');
end

% ── Run analytics ─────────────────────────────────────────────────────────
cvResult  = citation_velocity(T, currentYear=options.currentYear);
tgrResult = topic_growth_rate(T, ...
    topicCol=options.topicCol, minPapers=options.minPapersForTopic);
idResult  = institution_dominance(T, ...
    topN=options.topN, paperWeight=options.paperWeight);

% ── Assemble result ───────────────────────────────────────────────────────
result                      = struct();
result.citation_velocity    = cvResult;
result.topic_growth_rate    = tgrResult;
result.institution_dominance = idResult;
result.n_papers             = height(T);
result.computed_at          = string(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));

end
