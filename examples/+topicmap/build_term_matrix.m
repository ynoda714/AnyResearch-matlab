function [countMatrix, vocab, docFrequency] = build_term_matrix(texts, opts)
%BUILD_TERM_MATRIX Build a simple document-term count matrix.

arguments
    texts (:,1) string
    opts.maxTerms (1,1) double = 200
    opts.minDocFrequency (1,1) double = 2
    opts.stopWords (:,1) string = strings(0, 1)
    opts.normalizePlural (1,1) logical = false
end

texts = topicmap.clean_text(texts);
nDocs = numel(texts);
tokenRows = cell(nDocs, 1);
globalCounts = containers.Map("KeyType", "char", "ValueType", "double");
docCounts = containers.Map("KeyType", "char", "ValueType", "double");

for i = 1:nDocs
    tokens = local_tokenize(texts(i), opts.stopWords, opts.normalizePlural);
    tokenRows{i} = tokens;
    if isempty(tokens)
        continue;
    end

    seen = containers.Map("KeyType", "char", "ValueType", "logical");
    for j = 1:numel(tokens)
        key = char(tokens(j));
        if isKey(globalCounts, key)
            globalCounts(key) = globalCounts(key) + 1;
        else
            globalCounts(key) = 1;
        end

        if ~isKey(seen, key)
            seen(key) = true;
            if isKey(docCounts, key)
                docCounts(key) = docCounts(key) + 1;
            else
                docCounts(key) = 1;
            end
        end
    end
end

allTerms = string(keys(globalCounts))';
if isempty(allTerms)
    countMatrix = zeros(nDocs, 0);
    vocab = strings(0, 1);
    docFrequency = zeros(0, 1);
    return;
end

termTotals = zeros(numel(allTerms), 1);
termDocs = zeros(numel(allTerms), 1);
for i = 1:numel(allTerms)
    key = char(allTerms(i));
    termTotals(i) = globalCounts(key);
    termDocs(i) = docCounts(key);
end

keep = termDocs >= opts.minDocFrequency;
allTerms = allTerms(keep);
termTotals = termTotals(keep);
termDocs = termDocs(keep);

if isempty(allTerms)
    countMatrix = zeros(nDocs, 0);
    vocab = strings(0, 1);
    docFrequency = zeros(0, 1);
    return;
end

[~, order] = sort(termTotals, "descend");
allTerms = allTerms(order);
termDocs = termDocs(order);
limit = min(opts.maxTerms, numel(allTerms));
vocab = allTerms(1:limit);
docFrequency = termDocs(1:limit);

termIndex = containers.Map("KeyType", "char", "ValueType", "double");
for i = 1:numel(vocab)
    termIndex(char(vocab(i))) = i;
end

countMatrix = zeros(nDocs, numel(vocab));
for i = 1:nDocs
    tokens = tokenRows{i};
    for j = 1:numel(tokens)
        key = char(tokens(j));
        if isKey(termIndex, key)
            col = termIndex(key);
            countMatrix(i, col) = countMatrix(i, col) + 1;
        end
    end
end
end

function tokens = local_tokenize(text, stopWords, normalizePlural)
text = lower(char(text));
text = regexprep(text, "[^a-z0-9 ]", " ");
parts = split(string(text));
parts = strtrim(parts);
parts = parts(strlength(parts) >= 2);
if normalizePlural
    for i = 1:numel(parts)
        parts(i) = local_normalize_plural(parts(i));
    end
end
parts = parts(strlength(parts) >= 2);
if ~isempty(stopWords)
    parts = parts(~ismember(parts, stopWords));
end
tokens = parts(:);
end

function token = local_normalize_plural(token)
if strlength(token) <= 3
    return;
end

if endsWith(token, "ies") && strlength(token) > 4
    token = extractBefore(token, strlength(token) - 2) + "y";
    return;
end

if endsWith(token, ["sses", "shes", "ches", "xes", "zes"]) && strlength(token) > 4
    token = extractBefore(token, strlength(token) - 1);
    return;
end

if endsWith(token, "s") && ...
        ~endsWith(token, ["ss", "us", "is"]) && ...
        strlength(token) > 3
    token = extractBefore(token, strlength(token));
end
end
