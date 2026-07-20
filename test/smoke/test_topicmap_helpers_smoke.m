function test_topicmap_helpers_smoke()
%TEST_TOPICMAP_HELPERS_SMOKE Unit-style smoke coverage for topicmap helpers.

thisDir = fileparts(mfilename("fullpath"));
projectRoot = fullfile(thisDir, "..", "..");
addpath(fullfile(projectRoot, "examples"));

%% Case 1: build_term_matrix returns expected vocabulary and counts
texts = [
    "alpha beta beta"
    "beta gamma"
    "gamma delta"
];
[countMatrix, vocab, docFrequency] = topicmap.build_term_matrix(texts, ...
    maxTerms=10, minDocFrequency=1);
assert(size(countMatrix, 1) == 3, "Case2: row count mismatch");
assert(numel(vocab) >= 3, "Case2: expected at least 3 terms");
assert(ismember("beta", vocab), "Case2: beta missing from vocab");
betaIdx = find(vocab == "beta", 1, "first");
assert(~isempty(betaIdx), "Case2: beta index missing");
assert(countMatrix(1, betaIdx) == 2, "Case2: beta count mismatch");
assert(docFrequency(betaIdx) == 2, "Case2: beta document frequency mismatch");

%% Case 2: build_term_matrix honors minDocFrequency and maxTerms
[countMatrix2, vocab2] = topicmap.build_term_matrix(texts, ...
    maxTerms=1, minDocFrequency=2);
assert(size(countMatrix2, 2) == 1, "Case3: maxTerms not applied");
assert(vocab2(1) == "beta" || vocab2(1) == "gamma", ...
    "Case3: unexpected surviving term");

%% Case 2b: build_term_matrix filters stopwords and normalizes plurals
textsStop = [
    "the matlab models improve cells"
    "matlab model improves cell"
    "the models and cells"
];
[countMatrixStop, vocabStop, docFreqStop] = topicmap.build_term_matrix(textsStop, ...
    maxTerms=10, minDocFrequency=1, ...
    stopWords=topicmap.default_stopwords(), normalizePlural=true);
assert(~ismember("the", vocabStop) && ~ismember("and", vocabStop), ...
    "Case3: stopwords should be removed");
assert(ismember("matlab", vocabStop), "Case3: matlab must survive stopword filtering");
assert(ismember("model", vocabStop) && ~ismember("models", vocabStop), ...
    "Case3: plural normalization failed for model");
assert(ismember("cell", vocabStop) && ~ismember("cells", vocabStop), ...
    "Case3: plural normalization failed for cell");
modelIdx = find(vocabStop == "model", 1, "first");
assert(~isempty(modelIdx) && docFreqStop(modelIdx) == 3, ...
    "Case3: normalized model doc frequency mismatch");
assert(size(countMatrixStop, 2) >= 3, "Case3: expected surviving non-stopword vocabulary");

%% Case 3: compute_tfidf preserves size and zero rows
tfidfMatrix = topicmap.compute_tfidf([2 0 1; 0 0 0; 1 1 0]);
assert(isequal(size(tfidfMatrix), [3 3]), "Case4: tfidf size mismatch");
assert(all(tfidfMatrix(2, :) == 0), "Case4: zero row should remain zero");
assert(all(tfidfMatrix(1, [1 3]) > 0), "Case4: nonzero TF-IDF entries expected");

%% Case 4: reduce_layout rejects unknown methods
try
    topicmap.reduce_layout(rand(4, 3), "bogus");
    error("Case4: expected unknown-method error");
catch ex
    assert(strcmp(ex.identifier, "topicmap:reduce_layout:UnknownMethod"), ...
        "Case4: unexpected error id: %s", ex.identifier);
end

%% Case 5: reduce_layout pca path supports arbitrary target dimensions
coordsPca = topicmap.reduce_layout(rand(6, 4), "pca", 3);
assert(isequal(size(coordsPca), [6 3]), "Case5: pca output size mismatch");
coordsOne = topicmap.reduce_layout([1; 3; 5], "pca", 2);
assert(isequal(size(coordsOne), [3 2]), "Case5: one-column pca size mismatch");
assert(all(coordsOne(:, 2) == 0), "Case5: one-column pca second dimension should be zero");

%% Case 6: reduce_layout tsne path returns requested dimensions
coordsTsne = topicmap.reduce_layout(rand(6, 4), "tsne", 2);
assert(isequal(size(coordsTsne), [6 2]), "Case6: tsne output size mismatch");

%% Case 7: summarize_clusters returns expected columns
clusterIds = [1; 1; 2];
embeddings = [1 0 0; 0.9 0.1 0; 0 1 0];
titles = ["Alpha Study"; "Beta Study"; "Gamma Study"];
summaryTbl = topicmap.summarize_clusters(clusterIds, embeddings, texts, titles, ...
    z5=[1 0; 0.9 0.1; 0 1], z2=[0 0; 0.1 0; 1 1], ...
    types=["article"; "preprint"; "dataset"], ...
    topTermCount=2, representativeCount=2, maxTerms=10, minDocFrequency=1);
assert(isequal(string(summaryTbl.Properties.VariableNames), ...
    ["cluster", "n_docs", "top_terms", "representative_titles", ...
    "silhouette_5d", "silhouette_2d", "lexical_coherence", "top_terms_overlap", ...
    "dominant_type", "type_purity", "duplicate_title_rate"]), ...
    "Case7: summary columns mismatch");
assert(height(summaryTbl) == 2, "Case7: cluster row count mismatch");
assert(summaryTbl.n_docs(1) == 2 && summaryTbl.n_docs(2) == 1, ...
    "Case7: cluster document counts mismatch");
assert(contains(summaryTbl.top_terms(1), "beta"), ...
    "Case7: expected top term missing from cluster 1");
assert(contains(summaryTbl.representative_titles(1), "Alpha Study"), ...
    "Case7: representative title selection mismatch");
assert(all(summaryTbl.type_purity >= 0 & summaryTbl.type_purity <= 1), ...
    "Case7: type purity out of range");

%% Case 7a: summarize_clusters removes stopwords from top_terms only
clusterIdsStop = [1; 1; 1; 2; 2];
embeddingsStop = [1 0; 0.9 0.1; 0.85 0.15; 0 1; 0.1 0.9];
textsCluster = [
    "the matlab models for cells"
    "and matlab model for cell"
    "matlab models support cell analysis"
    "neural networks for imaging"
    "neural network imaging"
];
titlesCluster = [
    "Cluster A1"
    "Cluster A2"
    "Cluster A2"
    "Cluster B1"
    "Cluster B2"
];
summaryStop = topicmap.summarize_clusters(clusterIdsStop, embeddingsStop, ...
    textsCluster, titlesCluster, z5=embeddingsStop, z2=embeddingsStop, ...
    types=["software"; "software"; "software"; "article"; "article"], ...
    topTermCount=3, representativeCount=2, ...
    maxTerms=10, minDocFrequency=1);
assert(contains(summaryStop.top_terms(1), "matlab"), ...
    "Case7a: matlab should remain in top terms");
assert(~contains(summaryStop.top_terms(1), "the") && ~contains(summaryStop.top_terms(1), "and"), ...
    "Case7a: stopwords leaked into top terms");
assert(~contains(summaryStop.top_terms(1), "models") && contains(summaryStop.top_terms(1), "model"), ...
    "Case7a: plural normalization should appear in top terms");
assert(contains(summaryStop.representative_titles(1), "Cluster A"), ...
    "Case7a: representative titles should still be populated");
assert(~contains(summaryStop.representative_titles(1), "Cluster A2 | Cluster A2"), ...
    "Case7a: duplicate representative titles should be removed");
assert(summaryStop.dominant_type(1) == "software" && summaryStop.type_purity(1) == 1, ...
    "Case7a: dominant type stats mismatch");
assert(summaryStop.duplicate_title_rate(1) > 0, ...
    "Case7a: duplicate title rate should detect repeated titles");

%% Case 7b: summarize_clusters rejects size mismatches
try
    topicmap.summarize_clusters(clusterIds(1:2), embeddings, texts, titles);
    error("Case7b: expected size-mismatch error");
catch ex
    assert(strcmp(ex.identifier, "topicmap:summarize_clusters:SizeMismatch"), ...
        "Case7b: unexpected error id: %s", ex.identifier);
end

%% Case 8: write_utf8_csv writes a BOM and creates parent folders
tmpDir = fullfile(tempdir, "topicmap_helper_smoke");
if ~isfolder(tmpDir)
    mkdir(tmpDir);
end
csvPath = fullfile(tmpDir, "nested", "summary.csv");
topicmap.write_utf8_csv(summaryTbl, csvPath);
fid = fopen(csvPath, "r");
bytes = fread(fid, 3, "*uint8");
fclose(fid);
assert(isequal(bytes(:)', uint8([239 187 191])), "Case8: UTF-8 BOM missing");
csvText = fileread(csvPath);
assert(contains(csvText, "cluster"), "Case8: CSV header missing");
assert(contains(csvText, "Alpha Study"), "Case8: CSV payload missing");

%% Case 9: plot_topic_map writes a PNG for synthetic coordinates
pngPath = fullfile(tmpDir, "map.png");
topicmap.plot_topic_map(rand(3, 2), clusterIds, pngPath, titleText="Smoke");
assert(isfile(pngPath), "Case9: map PNG was not written");
pngInfo = dir(pngPath);
assert(pngInfo.bytes > 0, "Case9: map PNG is empty");

%% Case 9b: plot_topic_map rejects invalid input shapes
try
    topicmap.plot_topic_map(rand(3, 3), clusterIds, fullfile(tmpDir, "bad.png"));
    error("Case9b: expected 2D-coordinate error");
catch ex
    assert(strcmp(ex.identifier, "topicmap:plot_topic_map:Expected2D"), ...
        "Case9b: unexpected error id: %s", ex.identifier);
end
try
    topicmap.plot_topic_map(rand(2, 2), clusterIds, fullfile(tmpDir, "bad2.png"));
    error("Case9b: expected size-mismatch error");
catch ex
    assert(strcmp(ex.identifier, "topicmap:plot_topic_map:SizeMismatch"), ...
        "Case9b: unexpected error id: %s", ex.identifier);
end

%% Case 10: embed_documents returns BERT embeddings and truncation metadata when available
if exist("bert", "file") == 2
    try
        [E, meta] = topicmap.embed_documents(["alpha"; "gamma delta epsilon zeta eta theta"], ...
            batchSize=2, maxChars=200, progressEvery=1, useGpu=false);
        assert(isequal(size(E), [2 768]), "Case10: expected 2x768 BERT embeddings");
        assert(meta.batchSize == 2, "Case10: batchSize metadata mismatch");
        assert(meta.maxChars == 200, "Case10: maxChars metadata mismatch");
        assert(meta.useGpu == false, "Case10: useGpu metadata mismatch");
    catch ex
        if ~strcmp(ex.identifier, "topicmap:embed_documents:MissingBertBaseSupport")
            rethrow(ex);
        end
    end
end

%% Case 11: embed_documents rejects unavailable explicit GPU requests
if exist("canUseGPU", "file") ~= 2 || ~canUseGPU()
    try
        topicmap.embed_documents(["alpha beta"], useGpu=true);
        error("Case11: expected GPU-unavailable error");
    catch ex
        if exist("bert", "file") == 2 && ~strcmp(ex.identifier, "topicmap:embed_documents:MissingBertBaseSupport")
            assert(strcmp(ex.identifier, "topicmap:embed_documents:GpuUnavailable"), ...
                "Case11: unexpected error id: %s", ex.identifier);
        end
    end
end

fprintf("Smoke test passed: topicmap helper functions\n");
end
