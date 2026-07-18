function [snippets, positions] = find_contexts_lines(text, queryText, contextLines, maxN)
% Case-insensitive search with N-line surrounding context extraction and deduplication
lines = splitlines(string(text));
nLines = numel(lines);
hitIdx = [];
for i = 1:nLines
    if contains(lines(i), queryText, 'IgnoreCase', true)
        hitIdx(end+1) = i; %#ok<AGROW>
    end
end
if isempty(hitIdx)
    snippets = strings(0,1);
    positions = zeros(0,1);
    return;
end
snippets = strings(0,1);
positions = zeros(0,1);
for i = 1:numel(hitIdx)
    idx = hitIdx(i);
    s = max(1, idx - contextLines);
    e = min(nLines, idx + contextLines);
    snippet = strjoin(lines(s:e), " ");
    snippets(end+1) = snippet; %#ok<AGROW>
    positions(end+1) = idx; %#ok<AGROW>
end
% Deduplication
[snippets, ia] = unique(snippets, 'stable');
positions = positions(ia);
% Maximum count limit
if numel(snippets) > maxN
    snippets = snippets(1:maxN);
    positions = positions(1:maxN);
end
end
