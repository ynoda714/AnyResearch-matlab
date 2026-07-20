function env = env_check(cfg)
%ENV_CHECK Check local readiness for the standalone topic-map pipeline.

arguments
    cfg (1,1) struct
end

local_validate_cfg(cfg);

jsonlPath = string(cfg.input.searchResultsJsonl);

env = struct();
env.searchResultsJsonl = jsonlPath;
env.hasSearchResultsJsonl = isfile(jsonlPath);
env.baseOutDir = string(cfg.baseOutDir);
env.hasStatisticsToolbox = local_has_toolbox("Statistics and Machine Learning Toolbox");
env.hasTextAnalyticsToolbox = local_has_toolbox("Text Analytics Toolbox");
env.hasDeepLearningToolbox = local_has_toolbox("Deep Learning Toolbox");
env.hasBertFunction = local_has_symbol("bert");
env.hasUmapFunction = local_has_symbol("umap");
env.hasTsneFunction = local_has_symbol("tsne");
env.canUseGpu = exist("canUseGPU", "file") == 2 && canUseGPU();
env.pipelineReady = env.hasSearchResultsJsonl && env.hasStatisticsToolbox && ...
    env.hasTextAnalyticsToolbox && env.hasDeepLearningToolbox && ...
    env.hasBertFunction && env.hasUmapFunction;
env.inputMessage = local_input_message(env.hasSearchResultsJsonl, jsonlPath);
env.pipelineMessage = local_pipeline_message(env);
end

function local_validate_cfg(cfg)
requiredTop = ["input", "baseOutDir"];
for i = 1:numel(requiredTop)
    if ~isfield(cfg, requiredTop(i))
        error("topicmap:env_check:MissingConfigField", ...
            "Missing required cfg field: %s", requiredTop(i));
    end
end

requiredInput = ["searchResultsJsonl"];
for i = 1:numel(requiredInput)
    if ~isfield(cfg.input, requiredInput(i))
        error("topicmap:env_check:MissingInputField", ...
            "Missing required cfg.input field: %s", requiredInput(i));
    end
end
end

function tf = local_has_toolbox(name)
installed = ver();
names = string({installed.Name});
tf = any(strcmp(names, string(name)));
end

function tf = local_has_symbol(name)
tf = ~isempty(which(char(name)));
end

function msg = local_input_message(hasInput, pathStr)
if hasInput
    msg = "Using input: " + pathStr;
else
    msg = "search_results.jsonl not found. Run main_run_pipeline.m first.";
end
end

function msg = local_pipeline_message(env)
if env.pipelineReady
    msg = "Pipeline prerequisites detected.";
    return;
end

missing = strings(0, 1);
if ~env.hasSearchResultsJsonl
    missing(end+1) = "search_results.jsonl";
end
if ~env.hasStatisticsToolbox
    missing(end+1) = "Statistics and Machine Learning Toolbox";
end
if ~env.hasTextAnalyticsToolbox
    missing(end+1) = "Text Analytics Toolbox";
end
if ~env.hasDeepLearningToolbox
    missing(end+1) = "Deep Learning Toolbox";
end
if ~env.hasBertFunction
    missing(end+1) = "bert()";
end
if ~env.hasUmapFunction
    missing(end+1) = "umap()";
end

msg = "Missing prerequisites: " + join(missing, ", ");
end
