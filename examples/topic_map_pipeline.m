%% Topic Map Pipeline
% Standalone example pipeline:
% search_results.jsonl -> BERT 768 -> UMAP 5D -> k-means -> UMAP 2D

%% 0. Parameters
searchResultsJsonl = "D:\workspace\20260207_ML_MCP\20260329_AnyResearch_dev\result\runs\20260720_210648\search_results.jsonl";
maxDocs = 0;
K = 20;
nDim5 = 5;
batchSize = 64;
maxChars = 1000;
seed = 0;
summaryTopTerms = 8;
summaryTopTitles = 3;

%% 1. Setup
thisDir = fileparts(mfilename("fullpath"));
addpath(thisDir);
rng(seed, "twister");

cfg = topicmap.setup(searchResultsJsonl);
runDir = topicmap.make_run_dir(cfg, "topic_map_pipeline");

fprintf("[topicmap] %s\n", cfg.env.inputMessage);
fprintf("[topicmap] %s\n", cfg.env.pipelineMessage);
if ~cfg.env.pipelineReady
    error("topicmap:pipeline:MissingPrerequisites", ...
        "Topic-map pipeline prerequisites are not satisfied. %s", cfg.env.pipelineMessage);
end

%% 2. Data Collection
timerAll = tic;
sectionTimer = tic;
works = topicmap.read_search_results(cfg.input.searchResultsJsonl);
if maxDocs > 0 && height(works) > maxDocs
    works = works(1:maxDocs, :);
end
if height(works) < 2
    error("topicmap:pipeline:NotEnoughRows", ...
        "At least two rows are required for topic-map generation.");
end
if K > height(works)
    error("topicmap:pipeline:InvalidClusterCount", ...
        "K=%d exceeds the number of available documents (%d).", K, height(works));
end
texts = topicmap.extract_text(works(:, ["title", "abstract"]), maxChars=maxChars);
timings.dataCollectionSeconds = toc(sectionTimer);

%% 3. BERT Processing
sectionTimer = tic;
[E, embeddingMeta] = topicmap.embed_documents(texts, ...
    batchSize=batchSize, maxChars=maxChars);
timings.bertSeconds = toc(sectionTimer);

%% 4. UMAP -> 5D
sectionTimer = tic;
Z5 = topicmap.reduce_layout(double(E), "umap", nDim5, seed=seed);
timings.umap5dSeconds = toc(sectionTimer);

%% 5a. k-means on 5D coordinates
sectionTimer = tic;
clusterIds = kmeans(Z5, K, Replicates=5, Start="plus");
timings.kmeansSeconds = toc(sectionTimer);

%% 5b. UMAP -> 2D for plotting
sectionTimer = tic;
Z2 = topicmap.reduce_layout(Z5, "umap", 2, seed=seed);
timings.umap2dSeconds = toc(sectionTimer);

%% 5c. Outputs
sectionTimer = tic;
summaryTbl = topicmap.summarize_clusters(clusterIds, double(E), texts, works.title, ...
    z5=Z5, z2=Z2, types=works.type, ...
    topTermCount=summaryTopTerms, representativeCount=summaryTopTitles);

coordTbl = table( ...
    works.work_id, works.openalex_id, works.title, clusterIds, ...
    Z5(:, 1), Z5(:, 2), Z5(:, 3), Z5(:, 4), Z5(:, 5), ...
    Z2(:, 1), Z2(:, 2), ...
    'VariableNames', ["work_id", "openalex_id", "title", "cluster_id", ...
    "umap5_1", "umap5_2", "umap5_3", "umap5_4", "umap5_5", "umap_x", "umap_y"]);

coordCsvPath = fullfile(runDir, "topic_map_points.csv");
summaryCsvPath = fullfile(runDir, "topic_map_clusters.csv");
pngPath = fullfile(runDir, "topic_map.png");
metaPath = fullfile(runDir, "topic_map_run_meta.json");

topicmap.write_utf8_csv(coordTbl, coordCsvPath);
topicmap.write_utf8_csv(summaryTbl, summaryCsvPath);
topicmap.plot_topic_map(Z2, clusterIds, pngPath, ...
    titleText=sprintf("Topic Map (K=%d, N=%d)", K, height(works)));

timings.outputSeconds = toc(sectionTimer);
timings.totalSeconds = toc(timerAll);

meta = struct();
meta.input = struct( ...
    "searchResultsJsonl", string(cfg.input.searchResultsJsonl), ...
    "source", string(cfg.input.source), ...
    "nDocs", height(works));
meta.parameters = struct( ...
    "K", K, ...
    "nDim5", nDim5, ...
    "batchSize", batchSize, ...
    "maxChars", maxChars, ...
    "seed", seed, ...
    "summaryTopTerms", summaryTopTerms, ...
    "summaryTopTitles", summaryTopTitles, ...
    "maxDocs", maxDocs);
meta.timings = timings;
meta.embedding = embeddingMeta;
meta.clusterDiagnostics = local_cluster_meta(summaryTbl, works.type);
meta.outputs = struct( ...
    "runDir", string(runDir), ...
    "pointsCsv", string(coordCsvPath), ...
    "clustersCsv", string(summaryCsvPath), ...
    "mapPng", string(pngPath));
local_write_json(metaPath, meta);

fprintf("[topicmap] Wrote %s\n", coordCsvPath);
fprintf("[topicmap] Wrote %s\n", summaryCsvPath);
fprintf("[topicmap] Wrote %s\n", pngPath);
fprintf("[topicmap] Wrote %s\n", metaPath);

function stats = local_cluster_meta(summaryTbl, types)
stats = struct();
stats.nClusters = height(summaryTbl);
stats.meanSilhouette5d = mean(summaryTbl.silhouette_5d, "omitnan");
stats.meanSilhouette2d = mean(summaryTbl.silhouette_2d, "omitnan");
stats.meanLexicalCoherence = mean(summaryTbl.lexical_coherence, "omitnan");
stats.totalTopTermsOverlap = sum(summaryTbl.top_terms_overlap, "omitnan");
stats.meanTypePurity = mean(summaryTbl.type_purity, "omitnan");
stats.meanDuplicateTitleRate = mean(summaryTbl.duplicate_title_rate, "omitnan");
stats.typeCounts = local_type_counts(types);
end

function typeCounts = local_type_counts(types)
types = strtrim(string(types(:)));
types(strlength(types) == 0) = "(unknown)";
[groups, ~, idx] = unique(types, "stable");
counts = accumarray(idx, 1);
typeCounts = struct([]);
for i = 1:numel(groups)
    typeCounts(i).type = groups(i); %#ok<AGROW>
    typeCounts(i).count = counts(i); %#ok<AGROW>
end
end

function local_write_json(filePath, value)
jsonText = jsonencode(value, PrettyPrint=true);
fid = fopen(filePath, "w", "n", "UTF-8");
if fid < 0
    error("topicmap:pipeline:MetaOpenFailed", ...
        "Failed to open metadata file: %s", filePath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonText);
end
