function works = read_search_results(inputPath)
%READ_SEARCH_RESULTS Read AnyResearch search_results.jsonl for examples.
%
%   works = topicmap.read_search_results()
%   works = topicmap.read_search_results(inputPath)
%
%   Input:
%     inputPath : Path to search_results.jsonl. When omitted or empty, the
%                 latest JSONL under result/runs is used.
%
%   Output:
%     works : table with a stable minimal schema for the topic-map examples:
%             work_id, openalex_id, title, abstract, text, year, topics, type

arguments
    inputPath (1,1) string = ""
end

repoRoot = local_repo_root();
utilDir = fullfile(repoRoot, "src", "util");
if isfolder(utilDir)
    addpath(utilDir);
end

if strlength(strtrim(inputPath)) == 0
    inputPath = local_find_latest_jsonl(repoRoot);
end
inputPath = local_canonical_path(inputPath);

if ~isfile(inputPath)
    error("topicmap:read_search_results:NotFound", ...
        "search_results.jsonl not found: %s", inputPath);
end

if exist("read_jsonl", "file") ~= 2
    error("topicmap:read_search_results:MissingReadJsonl", ...
        "read_jsonl.m is not on the MATLAB path.");
end

raw = read_jsonl(inputPath);
if isempty(raw)
    works = local_empty_output();
    return;
end

vars = string(raw.Properties.VariableNames);
if ~ismember("title", vars)
    error("topicmap:read_search_results:MissingTitle", ...
        "title column is required in: %s", inputPath);
end
if ~ismember("openalex_id", vars)
    error("topicmap:read_search_results:MissingOpenAlexId", ...
        "openalex_id column is required in: %s", inputPath);
end

titleVals = topicmap.clean_text(string(raw.title));
abstractVals = topicmap.clean_text(local_optional_string_column(raw, "abstract", height(raw)));
topicVals = topicmap.clean_text(local_optional_string_column(raw, "topics", height(raw)));
typeVals = topicmap.clean_text(local_optional_string_column(raw, "type", height(raw)));
openalexIds = string(raw.openalex_id);
years = local_optional_numeric_column(raw, "publication_year", height(raw));

workIds = strings(height(raw), 1);
for i = 1:height(raw)
    workIds(i) = local_work_id(openalexIds(i), i);
end

textVals = topicmap.extract_text(table(titleVals, abstractVals, ...
    'VariableNames', ["title", "abstract"]));

works = table( ...
    workIds, ...
    openalexIds, ...
    titleVals, ...
    abstractVals, ...
    textVals, ...
    years, ...
    topicVals, ...
    typeVals, ...
    'VariableNames', ["work_id", "openalex_id", "title", "abstract", "text", "year", "topics", "type"]);
end

function repoRoot = local_repo_root()
here = fileparts(mfilename("fullpath"));
repoRoot = string(fullfile(here, "..", ".."));
repoRoot = string(char(java.io.File(char(repoRoot)).getCanonicalPath()));
end

function inputPath = local_find_latest_jsonl(repoRoot)
runRoot = fullfile(repoRoot, "result", "runs");
if ~isfolder(runRoot)
    error("topicmap:read_search_results:RunRootNotFound", ...
        "Run root directory not found: %s", runRoot);
end

matches = dir(fullfile(runRoot, "*", "search_results.jsonl"));
if isempty(matches)
    error("topicmap:read_search_results:NoRunsFound", ...
        "No search_results.jsonl files found under: %s", runRoot);
end

[~, order] = sort([matches.datenum], "descend");
latest = matches(order(1));
inputPath = string(fullfile(latest.folder, latest.name));
end

function pathStr = local_canonical_path(pathStr)
pathStr = string(char(java.io.File(char(pathStr)).getCanonicalPath()));
end

function out = local_optional_string_column(T, name, nRows)
if ismember(name, string(T.Properties.VariableNames))
    out = string(T.(name));
else
    out = repmat("", nRows, 1);
end
out(ismissing(out)) = "";
end

function out = local_optional_numeric_column(T, name, nRows)
if ismember(name, string(T.Properties.VariableNames))
    vals = T.(name);
    if isnumeric(vals)
        out = double(vals);
    else
        out = str2double(string(vals));
    end
else
    out = NaN(nRows, 1);
end
end

function workId = local_work_id(openalexId, rowIndex)
id = strtrim(string(openalexId));
if strlength(id) == 0
    workId = "row_" + string(rowIndex);
    return;
end

parts = split(id, "/");
parts = parts(strlength(parts) > 0);
if isempty(parts)
    workId = id;
else
    workId = parts(end);
end
end

function T = local_empty_output()
T = table( ...
    strings(0,1), strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    NaN(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', ["work_id", "openalex_id", "title", "abstract", "text", "year", "topics", "type"]);
end
