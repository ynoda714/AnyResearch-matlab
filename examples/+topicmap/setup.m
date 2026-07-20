function cfg = setup(searchResultsJsonl)
%SETUP Build standalone configuration for topic-map examples.
%
%   cfg = topicmap.setup()
%   cfg = topicmap.setup(searchResultsJsonl)

arguments
    searchResultsJsonl (1,1) string = ""
end

repoRoot = local_repo_root();
baseOutDir = fullfile(repoRoot, "result", "examples", "topicmap");

if strlength(strtrim(searchResultsJsonl)) == 0
    searchResultsJsonl = local_find_latest_jsonl(repoRoot);
    inputSource = "latest_run";
else
    inputSource = "explicit";
end
searchResultsJsonl = local_canonical_path(searchResultsJsonl);

if ~isfile(searchResultsJsonl)
    error("topicmap:setup:SearchResultsNotFound", ...
        "search_results.jsonl not found. Run main_run_pipeline.m first or pass an explicit path: %s", ...
        searchResultsJsonl);
end

cfg = struct();
cfg.repoRoot = string(repoRoot);
cfg.baseOutDir = string(baseOutDir);
cfg.input = struct();
cfg.input.searchResultsJsonl = string(searchResultsJsonl);
cfg.input.runDir = string(fileparts(searchResultsJsonl));
cfg.input.runId = string(local_basename(cfg.input.runDir));
cfg.input.source = inputSource;
cfg.env = topicmap.env_check(cfg);
end

function repoRoot = local_repo_root()
here = fileparts(mfilename("fullpath"));
repoRoot = string(fullfile(here, "..", ".."));
repoRoot = string(char(java.io.File(char(repoRoot)).getCanonicalPath()));
end

function inputPath = local_find_latest_jsonl(repoRoot)
runRoot = fullfile(repoRoot, "result", "runs");
if ~isfolder(runRoot)
    error("topicmap:setup:RunRootNotFound", ...
        "Run root directory not found: %s", runRoot);
end

matches = dir(fullfile(runRoot, "*", "search_results.jsonl"));
if isempty(matches)
    error("topicmap:setup:NoRunsFound", ...
        "No search_results.jsonl files found under %s. Run main_run_pipeline.m first.", ...
        runRoot);
end

[~, order] = sort([matches.datenum], "descend");
latest = matches(order(1));
inputPath = string(fullfile(latest.folder, latest.name));
end

function pathStr = local_canonical_path(pathStr)
pathStr = string(char(java.io.File(char(pathStr)).getCanonicalPath()));
end

function name = local_basename(pathStr)
[~, name, ext] = fileparts(char(pathStr));
name = string([name, ext]);
end
