function summaryTbl = summarize_clusters(clusterIds, embeddings, texts, titles, opts)
%SUMMARIZE_CLUSTERS Build a cluster summary table for the topic-map pipeline.

arguments
    clusterIds (:,1) double
    embeddings double
    texts (:,1) string
    titles (:,1) string
    opts.z5 double = zeros(numel(clusterIds), 0)
    opts.z2 double = zeros(numel(clusterIds), 0)
    opts.types (:,1) string = repmat("", numel(clusterIds), 1)
    opts.topTermCount (1,1) double {mustBePositive, mustBeInteger} = 8
    opts.representativeCount (1,1) double {mustBePositive, mustBeInteger} = 3
    opts.maxTerms (1,1) double {mustBePositive, mustBeInteger} = 500
    opts.minDocFrequency (1,1) double {mustBePositive, mustBeInteger} = 2
end

nDocs = numel(clusterIds);
if size(embeddings, 1) ~= nDocs || numel(texts) ~= nDocs || numel(titles) ~= nDocs
    error("topicmap:summarize_clusters:SizeMismatch", ...
        "clusterIds, embeddings, texts, and titles must have matching row counts.");
end

clusterIds = double(clusterIds(:));
texts = string(texts(:));
titles = string(titles(:));
types = string(opts.types(:));
if numel(types) ~= nDocs
    error("topicmap:summarize_clusters:SizeMismatch", ...
        "opts.types must match the row count of clusterIds.");
end

z5 = double(opts.z5);
if ~isempty(z5) && size(z5, 1) ~= nDocs
    error("topicmap:summarize_clusters:SizeMismatch", ...
        "opts.z5 must match the row count of clusterIds.");
end

z2 = double(opts.z2);
if ~isempty(z2) && size(z2, 1) ~= nDocs
    error("topicmap:summarize_clusters:SizeMismatch", ...
        "opts.z2 must match the row count of clusterIds.");
end

uniqueClusters = unique(clusterIds, "sorted");
nClusters = numel(uniqueClusters);

cluster = zeros(nClusters, 1);
nDocsPerCluster = zeros(nClusters, 1);
topTerms = strings(nClusters, 1);
representativeTitles = strings(nClusters, 1);
silhouette5d = nan(nClusters, 1);
silhouette2d = nan(nClusters, 1);
lexicalCoherence = zeros(nClusters, 1);
topTermsOverlap = zeros(nClusters, 1);
dominantType = strings(nClusters, 1);
typePurity = zeros(nClusters, 1);
duplicateTitleRate = zeros(nClusters, 1);

pointSilhouette5d = local_silhouette_scores(z5, clusterIds);
pointSilhouette2d = local_silhouette_scores(z2, clusterIds);

for i = 1:nClusters
    thisCluster = uniqueClusters(i);
    mask = clusterIds == thisCluster;
    cluster(i) = thisCluster;
    nDocsPerCluster(i) = sum(mask);
    topTerms(i) = local_top_terms(texts(mask), opts);
    representativeTitles(i) = local_representative_titles(embeddings(mask, :), titles(mask), opts.representativeCount);
    silhouette5d(i) = local_mean_or_nan(pointSilhouette5d(mask));
    silhouette2d(i) = local_mean_or_nan(pointSilhouette2d(mask));
    lexicalCoherence(i) = local_lexical_coherence(texts(mask), opts);
    [dominantType(i), typePurity(i)] = local_type_stats(types(mask));
    duplicateTitleRate(i) = local_duplicate_title_rate(titles(mask));
end

topTermsOverlap = local_top_terms_overlap(topTerms);

summaryTbl = table(cluster, nDocsPerCluster, topTerms, representativeTitles, ...
    silhouette5d, silhouette2d, lexicalCoherence, topTermsOverlap, ...
    dominantType, typePurity, duplicateTitleRate, ...
    'VariableNames', ["cluster", "n_docs", "top_terms", "representative_titles", ...
    "silhouette_5d", "silhouette_2d", "lexical_coherence", "top_terms_overlap", ...
    "dominant_type", "type_purity", "duplicate_title_rate"]);
end

function topTerms = local_top_terms(texts, opts)
% Note: TF-IDF here is cluster-local. Stopword filtering keeps labels readable
% without changing the current scoring design.
[countMatrix, vocab] = topicmap.build_term_matrix(texts, ...
    maxTerms=opts.maxTerms, ...
    minDocFrequency=opts.minDocFrequency, ...
    stopWords=topicmap.default_stopwords(), ...
    normalizePlural=true);
if isempty(vocab)
    topTerms = "";
    return;
end

tfidfMatrix = topicmap.compute_tfidf(countMatrix);
scores = mean(tfidfMatrix, 1);
[~, order] = sort(scores, "descend");
keep = min(opts.topTermCount, numel(order));
chosen = vocab(order(1:keep));
topTerms = join(chosen, ", ");
end

function titlesStr = local_representative_titles(embeddings, titles, topN)
if isempty(embeddings)
    titlesStr = "";
    return;
end

X = double(embeddings);
rowNorms = sqrt(sum(X.^2, 2));
rowNorms(rowNorms == 0) = 1;
Xn = X ./ rowNorms;

centroid = mean(Xn, 1);
centroidNorm = norm(centroid);
if centroidNorm == 0
    centroidNorm = 1;
end
centroid = centroid ./ centroidNorm;

similarity = Xn * centroid';
[~, order] = sort(similarity, "descend");
ordered = topicmap.clean_text(string(titles(order)));
chosen = strings(0, 1);
seen = strings(0, 1);
for i = 1:numel(ordered)
    title = ordered(i);
    if strlength(title) == 0 || any(seen == title)
        continue;
    end
    seen(end + 1, 1) = title; %#ok<AGROW>
    chosen(end + 1, 1) = title; %#ok<AGROW>
    if numel(chosen) >= topN
        break;
    end
end
if isempty(chosen)
    chosen = ordered(1:min(topN, numel(ordered)));
end
titlesStr = join(chosen, " | ");
end

function scores = local_silhouette_scores(X, clusterIds)
if isempty(X) || size(X, 2) == 0 || numel(unique(clusterIds)) < 2
    scores = nan(numel(clusterIds), 1);
    return;
end
scores = silhouette(X, clusterIds);
scores = double(scores(:));
end

function value = local_mean_or_nan(x)
if isempty(x) || all(isnan(x))
    value = NaN;
else
    value = mean(x, "omitnan");
end
end

function score = local_lexical_coherence(texts, opts)
[countMatrix, ~] = topicmap.build_term_matrix(texts, ...
    maxTerms=opts.maxTerms, ...
    minDocFrequency=1, ...
    stopWords=topicmap.default_stopwords(), ...
    normalizePlural=true);
if size(countMatrix, 1) < 2 || size(countMatrix, 2) == 0
    score = 0;
    return;
end

X = double(countMatrix);
rowNorms = sqrt(sum(X.^2, 2));
rowNorms(rowNorms == 0) = 1;
Xn = X ./ rowNorms;
similarity = Xn * Xn';
upperMask = triu(true(size(similarity)), 1);
values = similarity(upperMask);
if isempty(values)
    score = 0;
else
    score = mean(values, "omitnan");
end
end

function overlap = local_top_terms_overlap(topTerms)
nClusters = numel(topTerms);
termLists = cell(nClusters, 1);
for i = 1:nClusters
    parts = split(string(topTerms(i)), ",");
    parts = strtrim(parts);
    parts = parts(strlength(parts) > 0);
    termLists{i} = unique(parts, "stable");
end

overlap = zeros(nClusters, 1);
for i = 1:nClusters
    current = termLists{i};
    if isempty(current)
        continue;
    end
    otherTerms = strings(0, 1);
    for j = 1:nClusters
        if j == i
            continue;
        end
        otherTerms = [otherTerms; termLists{j}(:)]; %#ok<AGROW>
    end
    otherTerms = unique(otherTerms, "stable");
    overlap(i) = sum(ismember(current, otherTerms));
end
end

function [name, purity] = local_type_stats(types)
types = strtrim(string(types(:)));
types(strlength(types) == 0) = "(unknown)";
[groups, ~, idx] = unique(types, "stable");
counts = accumarray(idx, 1);
[maxCount, order] = max(counts);
name = groups(order);
purity = maxCount / max(numel(types), 1);
end

function rate = local_duplicate_title_rate(titles)
titles = topicmap.clean_text(string(titles(:)));
titles = titles(strlength(titles) > 0);
if isempty(titles)
    rate = 0;
    return;
end
[~, ~, idx] = unique(titles, "stable");
counts = accumarray(idx, 1);
duplicateMask = counts(idx) > 1;
rate = sum(duplicateMask) / numel(titles);
end
