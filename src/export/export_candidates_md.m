function outputPath = export_candidates_md(inputPath, outputPath)
%EXPORT_CANDIDATES_MD  Export reviewed candidate rows as an EasyMolKit-ready Markdown table.

arguments
    inputPath  (1,1) string = "result/candidates/candidates.jsonl"
    outputPath (1,1) string = "result/candidates/repro_candidates.md"
end

local_addpath_util(mfilename('fullpath'));
if ~isfile(inputPath)
    error("export_candidates_md:InputNotFound", "Input file not found: %s", inputPath);
end

T = read_jsonl(inputPath);
if ~ismember("status", T.Properties.VariableNames)
    T.status = repmat("", height(T), 1);
end

reviewedMask = strtrim(lower(string(T.status))) == "reviewed";
T = T(reviewedMask, :);
T = local_sort_candidates(T);

lines = strings(0, 1);
lines(end+1, 1) = "| RP番号 | 論文 | DOI | Tier | 状態 | 特記 |";
lines(end+1, 1) = "|---|---|---|---|---|---|";

for i = 1:height(T)
    rpNo = "";
    title = local_safe_text(T, "title", i);
    doi = local_safe_doi(T, i);
    if doi == ""
        doiCell = "";
    else
        doiCell = "[" + doi + "](https://doi.org/" + doi + ")";
    end
    tier = local_estimate_tier(T, i);
    status = local_safe_text(T, "status", i);
    note = local_safe_text(T, "note", i);
    lines(end+1, 1) = "| " + local_escape_md(rpNo) + " | " + local_escape_md(title) + ...
        " | " + local_escape_md(doiCell) + " | " + local_escape_md(tier) + ...
        " | " + local_escape_md(status) + " | " + local_escape_md(note) + " |"; %#ok<AGROW>
end

parentDir = fileparts(outputPath);
if strlength(parentDir) > 0 && ~isfolder(parentDir)
    mkdir(parentDir);
end

fid = fopen(outputPath, "w", "n", "UTF-8");
if fid < 0
    error("export_candidates_md:OpenFailed", "Cannot open file: %s", outputPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
for i = 1:numel(lines)
    fprintf(fid, "%s\n", lines(i));
end
end

function T = local_sort_candidates(T)
if isempty(T)
    return;
end

sortVars = strings(0, 1);
sortDirs = strings(0, 1);
preferred = ["repro_signal_score", "fwci", "cited_by_count", "publication_year"];
for i = 1:numel(preferred)
    if ismember(preferred(i), T.Properties.VariableNames)
        sortVars(end+1, 1) = preferred(i); %#ok<AGROW>
        sortDirs(end+1, 1) = "descend"; %#ok<AGROW>
    end
end
if ~isempty(sortVars)
    T = sortrows(T, cellstr(sortVars), cellstr(sortDirs));
end
end

function textVal = local_safe_text(T, varName, rowIdx)
if ~ismember(varName, T.Properties.VariableNames)
    textVal = "";
    return;
end

value = T.(varName)(rowIdx, :);
if isstring(value)
    textVal = value;
elseif isnumeric(value) && isscalar(value)
    if isnan(value)
        textVal = "";
    else
        textVal = string(value);
    end
else
    textVal = string(value);
end
textVal = strtrim(textVal);
end

function doi = local_safe_doi(T, rowIdx)
doi = local_safe_text(T, "doi_normalized", rowIdx);
if doi == ""
    doi = local_safe_text(T, "doi", rowIdx);
end
doi = normalize_candidate_doi(doi);
end

function tier = local_estimate_tier(T, rowIdx)
tier = "C";
if ~ismember("repro_signal_score", T.Properties.VariableNames)
    return;
end

score = T.repro_signal_score(rowIdx);
if ~isnumeric(score) || ~isscalar(score) || isnan(score)
    return;
end

if score >= 3
    tier = "A";
elseif score >= 2
    tier = "B";
end
end

function out = local_escape_md(textVal)
out = replace(string(textVal), newline, " ");
out = replace(out, "|", "\|");
end

function local_addpath_util(thisFileFullPath)
srcDir = fileparts(thisFileFullPath);
utilDir = fullfile(srcDir, '..', 'util');
if isfolder(utilDir) && ~any(strcmp(strsplit(path, pathsep), char(string(utilDir))))
    addpath(char(utilDir));
end
end
