function test_topicmap_p0_smoke()
%TEST_TOPICMAP_P0_SMOKE Smoke test for Phase P-0 topic-map input adapter.

thisDir = fileparts(mfilename("fullpath"));
projectRoot = fullfile(thisDir, "..", "..");
addpath(fullfile(projectRoot, "src", "util"));
addpath(fullfile(projectRoot, "examples"));

tmpDir = fullfile(tempdir, "smoke_topicmap_p0");
if isfolder(tmpDir)
    rmdir(tmpDir, "s");
end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, "s"));

runDir = fullfile(tmpDir, "result", "runs", "20260720_120000");
mkdir(runDir);

T = table( ...
    ["https://openalex.org/W1"; "https://openalex.org/W2"], ...
    ["Title One"; "Title Two"], ...
    ["Abstract One"; ""], ...
    [2024; 2025], ...
    ["Topic A"; "Topic B"], ...
    'VariableNames', ["openalex_id", "title", "abstract", "publication_year", "topics"]);

jsonlPath = fullfile(runDir, "search_results.jsonl");
write_jsonl(T, jsonlPath);

works = topicmap.read_search_results(string(jsonlPath));
assert(istable(works), "Case1: output must be a table");
assert(height(works) == height(T), "Case1: row count mismatch");
assert(all(works.year == [2024; 2025]), "Case1: year extraction failed");

lines = splitlines(string(fileread(jsonlPath)));
lines = strtrim(lines);
lines = lines(strlength(lines) > 0);
assert(height(works) == numel(lines), "Case1: JSONL line count mismatch");

assert(all(works.work_id == ["W1"; "W2"]), "Case2: work_id extraction failed");
assert(works.text(1) == "Title One" + newline + "Abstract One", ...
    "Case3: text should include title and abstract");
assert(works.text(2) == "Title Two", ...
    "Case4: empty abstract should fall back to title only");
assert(works.topics(1) == "Topic A", "Case4: topics extraction failed");

textOnly = topicmap.extract_text(table(["A"; "B"], [""; "Body"], ...
    'VariableNames', ["title", "abstract"]));
assert(textOnly(1) == "A", "Case5: empty abstract fallback failed");
assert(textOnly(2) == "B" + newline + "Body", "Case5: title + abstract join failed");

minimalJsonl = fullfile(runDir, "search_results_minimal.jsonl");
Tminimal = table( ...
    [""; "https://openalex.org/W9"], ...
    ["  Title X  "; "Title Y"], ...
    'VariableNames', ["openalex_id", "title"]);
write_jsonl(Tminimal, minimalJsonl);
minimalWorks = topicmap.read_search_results(string(minimalJsonl));
assert(minimalWorks.work_id(1) == "row_1", "Case6: blank openalex_id fallback failed");
assert(minimalWorks.text(1) == "Title X", "Case6: title cleanup failed");
assert(isnan(minimalWorks.year(1)), "Case6: missing year must become NaN");
assert(minimalWorks.abstract(1) == "", "Case6: missing abstract must become empty string");
assert(minimalWorks.topics(1) == "", "Case6: missing topics must become empty string");

badJsonl = fullfile(runDir, "search_results_bad.jsonl");
Tbad = table(["W1"], 'VariableNames', ["openalex_id"]);
write_jsonl(Tbad, badJsonl);
try
    topicmap.read_search_results(string(badJsonl));
    error("Case7: expected missing title error");
catch ex
    assert(strcmp(ex.identifier, "topicmap:read_search_results:MissingTitle"), ...
        "Case7: unexpected error id: %s", ex.identifier);
end

try
    topicmap.extract_text("not_a_table");
    error("Case8: expected table-required error");
catch ex
    assert(strcmp(ex.identifier, "topicmap:extract_text:TableRequired"), ...
        "Case8: unexpected error id: %s", ex.identifier);
end

exampleFiles = dir(fullfile(projectRoot, "examples", "**", "*.m"));
for i = 1:numel(exampleFiles)
    filePath = fullfile(exampleFiles(i).folder, exampleFiles(i).name);
    text = fileread(filePath);
    assert(~contains(text, "raw/"), "Case9: raw/ reference found in %s", filePath);
    assert(~contains(text, "abstract_inverted_index"), ...
        "Case9: abstract_inverted_index reference found in %s", filePath);
    assert(~contains(text, "reconstruct_abstract"), ...
        "Case9: reconstruct_abstract reference found in %s", filePath);
end

fprintf("Smoke test passed: topicmap Phase P-0 adapter\n");
end
