function result = institution_dominance(T, options)
% INSTITUTION_DOMINANCE  Institution-level paper share and citation dominance.
%
%   Scores each institution appearing in the corpus by its share of papers
%   (paper_share) and share of total citations (citation_share), then
%   combines both into a composite dominance_score:
%
%     dominance_score = paperWeight * paper_share
%                     + (1 - paperWeight) * citation_share
%
%   Usage:
%     result = institution_dominance(T)
%     result = institution_dominance(T, institutionCol="first_author_institutions", topN=20)
%
%   Input:
%     T — MATLAB table containing:
%           first_author_institutions (string, pipe-delimited when multiple)
%         Optional:
%           cited_by_count (numeric)
%
%   Options:
%     institutionCol (string, default: "first_author_institutions")
%                    Column to use for institution extraction.
%     topN           (double, default: 20)
%                    Maximum number of institutions returned in the output table
%                    (sorted by dominance_score descending).
%     paperWeight    (double, default: 0.5)
%                    Weight of paper_share in composite dominance_score.
%                    citation_share weight = 1 - paperWeight.
%
%   Output (struct):
%     .by_institution table: institution | paper_count | total_citations |
%                            paper_share | citation_share | dominance_score
%     .n_institutions double: total distinct institutions found
%     .n_papers       double: total papers with a non-empty institution

arguments
    T table
    options.institutionCol (1,1) string = "first_author_institutions"
    options.topN           (1,1) double = 20
    options.paperWeight    (1,1) double = 0.5
end

result = struct();
result.by_institution = table();
result.n_institutions = 0;
result.n_papers       = 0;

if height(T) == 0
    return;
end

n        = height(T);
hasInst  = ismember(options.institutionCol, T.Properties.VariableNames);
hasCited = ismember('cited_by_count', T.Properties.VariableNames);

if ~hasInst
    return;
end

instRaw  = string(T.(options.institutionCol));
instRaw(ismissing(instRaw)) = "";

citedCount = zeros(n, 1);
if hasCited
    raw = T.cited_by_count;
    if iscell(raw)
        raw = cell2mat(raw);
    end
    v = double(raw);
    v(isnan(v)) = 0;
    citedCount = v;
end

% Accumulate paper count and total citations per institution
instPapers   = containers.Map('KeyType','char','ValueType','double');
instCitations = containers.Map('KeyType','char','ValueType','double');

nPapersWithInst = 0;
for i = 1:n
    raw = strtrim(instRaw(i));
    if raw == ""
        continue;
    end
    nPapersWithInst = nPapersWithInst + 1;

    % Support both pipe-delimited and plain single-institution values
    parts = strtrim(strsplit(raw, '|'));
    for k = 1:numel(parts)
        inst = char(strtrim(parts(k)));
        if isempty(inst)
            continue;
        end
        if isKey(instPapers, inst)
            instPapers(inst)    = instPapers(inst)    + 1;
            instCitations(inst) = instCitations(inst) + citedCount(i);
        else
            instPapers(inst)    = 1;
            instCitations(inst) = citedCount(i);
        end
    end
end

result.n_papers = nPapersWithInst;

nInst = instPapers.Count;
result.n_institutions = double(nInst);

if nInst == 0
    return;
end

instNames = keys(instPapers);
nI        = numel(instNames);

paperCnt  = zeros(nI, 1);
citedSum  = zeros(nI, 1);
for i = 1:nI
    paperCnt(i) = instPapers(instNames{i});
    citedSum(i) = instCitations(instNames{i});
end

totalPapers  = sum(paperCnt);
totalCited   = sum(citedSum);

paperShare    = paperCnt  / max(1, totalPapers);
citationShare = citedSum  / max(1, totalCited);

w = options.paperWeight;
dominanceScore = w .* paperShare + (1 - w) .* citationShare;

instNamesStr = string(instNames(:));
tbl = table( ...
    instNamesStr, paperCnt, citedSum, paperShare, citationShare, dominanceScore, ...
    'VariableNames', {'institution','paper_count','total_citations', ...
                      'paper_share','citation_share','dominance_score'});

% Sort by dominance_score descending, truncate to topN
[~, sortIdx] = sort(tbl.dominance_score, 'descend');
tbl = tbl(sortIdx, :);
if height(tbl) > options.topN
    tbl = tbl(1:options.topN, :);
end

result.by_institution = tbl;

end
