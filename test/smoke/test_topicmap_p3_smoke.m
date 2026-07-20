function test_topicmap_p3_smoke()
%TEST_TOPICMAP_P3_SMOKE Smoke test for the Phase Q pipeline surface.

thisDir = fileparts(mfilename("fullpath"));
projectRoot = fullfile(thisDir, "..", "..");
addpath(fullfile(projectRoot, "examples"));

pipelinePath = fullfile(projectRoot, "examples", "topic_map_pipeline.m");
assert(isfile(pipelinePath), "Case1: topic_map_pipeline.m is missing");
pipelineText = fileread(pipelinePath);
assert(~contains(pipelineText, ".mlx"), "Case2: .mlx reference found in topic_map_pipeline.m");
assert(contains(pipelineText, "Z5 ="), "Case2: 5-D intermediate should be explicit");
assert(contains(pipelineText, "kmeans(Z5"), "Case2: kmeans must run on Z5");
assert(contains(pipelineText, "topic_map_points.csv"), "Case2: points CSV output missing");
assert(contains(pipelineText, "topic_map_clusters.csv"), "Case2: cluster CSV output missing");
assert(contains(pipelineText, "topic_map_run_meta.json"), "Case2: run meta output missing");
assert(contains(pipelineText, "MissingPrerequisites"), "Case2: prerequisite guard missing");

legacyFiles = [ ...
    "topic_map_ch00.m"
    "topic_map_ch01.m"
    "topic_map_ch02.m"
    "topic_map_ch03.m"
    "topic_map_ch04.m"
    "topic_map_ch05.m"
];
for i = 1:numel(legacyFiles)
    assert(~isfile(fullfile(projectRoot, "examples", legacyFiles(i))), ...
        "Case3: legacy chapter file still exists: %s", legacyFiles(i));
end

tmpDir = fullfile(tempdir, "topicmap_p3_smoke");
if isfolder(tmpDir)
    rmdir(tmpDir, "s");
end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, "s"));

clusterIds = [1; 1; 2; 2];
coords = rand(4, 2);
pngPath = fullfile(tmpDir, "topic_map.png");
csvPath = fullfile(tmpDir, "topic_map_clusters.csv");

summaryTbl = topicmap.summarize_clusters(clusterIds, rand(4, 768), ...
    ["alpha beta"; "alpha gamma"; "delta epsilon"; "delta zeta"], ...
    ["Paper A"; "Paper B"; "Paper C"; "Paper D"]);
topicmap.write_utf8_csv(summaryTbl, csvPath);
topicmap.plot_topic_map(coords, clusterIds, pngPath);

assert(isfile(csvPath), "Case4: cluster summary CSV missing");
assert(isfile(pngPath), "Case5: topic map PNG missing");
csvText = fileread(csvPath);
assert(contains(csvText, "representative_titles"), "Case4: cluster summary header missing");
assert(contains(csvText, "Paper A"), "Case4: representative title payload missing");
pngInfo = dir(pngPath);
assert(pngInfo.bytes > 0, "Case5: topic map PNG is empty");

fprintf("Smoke test passed: topicmap Phase P-3 chapters\n");
end
