function test_topicmap_p2_smoke()
%TEST_TOPICMAP_P2_SMOKE Smoke test for Phase Q topic-map pipeline setup.

thisDir = fileparts(mfilename("fullpath"));
projectRoot = fullfile(thisDir, "..", "..");
addpath(fullfile(projectRoot, "examples"));

cfg = topicmap.setup();

assert(isstruct(cfg), "Case1: setup must return a struct");
assert(isfield(cfg, "repoRoot"), "Case1: repoRoot missing");
assert(isfield(cfg, "baseOutDir"), "Case1: baseOutDir missing");
assert(isfield(cfg, "input"), "Case1: input missing");
assert(isfield(cfg, "env"), "Case1: env missing");

assert(~isfield(cfg, "hubRoot"), "Case2: legacy hubRoot must not exist");
assert(~isfield(cfg, "pipelineRoot"), "Case2: legacy pipelineRoot must not exist");
assert(~isfield(cfg, "normalizeRoot"), "Case2: legacy normalizeRoot must not exist");
assert(~isfield(cfg, "mode"), "Case2: legacy mode must not exist");

assert(isfield(cfg.input, "searchResultsJsonl"), "Case3: searchResultsJsonl missing");
assert(isfile(cfg.input.searchResultsJsonl), "Case3: searchResultsJsonl must exist");
assert(contains(cfg.baseOutDir, fullfile("result", "examples", "topicmap")), ...
    "Case3: baseOutDir must be under result/examples/topicmap");
assert(cfg.input.source == "latest_run", "Case3: default input source must be latest_run");

env = cfg.env;
assert(isfield(env, "hasBertFunction"), "Case4: hasBertFunction missing");
assert(isfield(env, "hasUmapFunction"), "Case4: hasUmapFunction missing");
assert(isfield(env, "pipelineReady"), "Case4: pipelineReady missing");
assert(contains(env.inputMessage, "Using input:"), "Case4: input message must describe active input");
assert(strlength(env.pipelineMessage) > 0, "Case4: pipeline message must not be empty");
expectedReady = env.hasSearchResultsJsonl && env.hasStatisticsToolbox && ...
    env.hasTextAnalyticsToolbox && env.hasDeepLearningToolbox && ...
    env.hasBertFunction && env.hasUmapFunction;
assert(env.pipelineReady == expectedReady, "Case4: pipelineReady logic drift");

pipelinePath = fullfile(projectRoot, "examples", "topic_map_pipeline.m");
assert(isfile(pipelinePath), "Case5: topic_map_pipeline.m must exist");
assert(~isfile(fullfile(projectRoot, "examples", "topic_map_ch00.m")), ...
    "Case5: legacy chapter script should be deleted");
pipelineText = fileread(pipelinePath);
assert(contains(pipelineText, "pipelineReady"), ...
    "Case5: pipeline should explicitly gate on env.pipelineReady");
assert(contains(pipelineText, "InvalidClusterCount"), ...
    "Case5: pipeline should guard K against document count");

cleaned = topicmap.clean_text(["  alpha" + newline + "beta  "; missing]);
assert(cleaned(1) == "alpha beta", "Case6: clean_text whitespace normalization failed");
assert(cleaned(2) == "", "Case6: clean_text missing handling failed");

runDir = topicmap.make_run_dir(cfg, "smoke / label");
assert(isfolder(runDir), "Case7: make_run_dir must create a directory");
assert(startsWith(runDir, cfg.baseOutDir), "Case7: runDir must stay under baseOutDir");
assert(contains(runDir, "_smoke___label"), "Case7: label sanitization failed");

cfgExplicit = topicmap.setup(cfg.input.searchResultsJsonl);
assert(cfgExplicit.input.source == "explicit", "Case8: explicit input source expected");

fakeCfg = cfg;
fakeCfg.input.searchResultsJsonl = fullfile(projectRoot, "tmp", "no_such_search_results.jsonl");
fakeEnv = topicmap.env_check(fakeCfg);
assert(fakeEnv.hasSearchResultsJsonl == false, "Case9: fake env must report missing input");
assert(fakeEnv.inputMessage == "search_results.jsonl not found. Run main_run_pipeline.m first.", ...
    "Case9: missing-input message mismatch");
assert(contains(fakeEnv.pipelineMessage, "search_results.jsonl"), ...
    "Case9: pipeline message should mention missing input");
assert(fakeEnv.pipelineReady == false, "Case9: missing input must disable pipelineReady");

try
    topicmap.env_check(struct());
    error("Case10: expected missing config error");
catch ex
    assert(strcmp(ex.identifier, "topicmap:env_check:MissingConfigField"), ...
        "Case10: unexpected error id: %s", ex.identifier);
end

exampleFiles = dir(fullfile(projectRoot, "examples", "**", "*.m"));
for i = 1:numel(exampleFiles)
    filePath = fullfile(exampleFiles(i).folder, exampleFiles(i).name);
    bytes = uint8(fileread(filePath));
    assert(all(bytes <= 127), "Case11: non-ASCII text found in %s", filePath);
end

fprintf("Smoke test passed: topicmap Phase P-2 skeleton\n");
end
