function test_last_author_extraction_smoke()
%TEST_LAST_AUTHOR_EXTRACTION_SMOKE  M14 First/Last Author column addition smoke test
%
%   addpath("src/adapters"); addpath("src/util"); addpath("test/smoke");
%   test_last_author_extraction_smoke();
%
% Target: last_author_name / last_author_institutions columns in openalex_to_normalized_works.m
% What to verify:
%   Case 1: Multiple authors -> first != last is possible (different author names)
%   Case 2: Single author -> first_* = last_* same value (spec: equal when single author)
%   Case 3: No author (empty string) -> last_* should be ""
%   Case 4: last_author_institutions with multiple affiliations delimited by "|"

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', '..', 'src', 'adapters'));
addpath(fullfile(thisDir, '..', '..', 'src', 'util'));

%% -- Case 1: Multiple authors (first != last) ------------------------------
titles    = "Multi-author paper";
abstracts = "Abstract for multi-author paper.";
first_nm  = "Alice Smith";
first_ins = "University A";
last_nm   = "Bob Jones";
last_ins  = "University B";

T1 = table(string(titles), string(abstracts), ...
    string(first_nm), string(first_ins), ...
    string(last_nm),  string(last_ins), ...
    'VariableNames', ["title","abstract","first_author_name","first_author_institutions",...
                      "last_author_name","last_author_institutions"]);

result1 = openalex_to_normalized_works(T1, StrictValidation=false);

assert(ismember("last_author_name", string(result1.Properties.VariableNames)), ...
    "Case1: last_author_name 列が存在しない");
assert(ismember("last_author_institutions", string(result1.Properties.VariableNames)), ...
    "Case1: last_author_institutions 列が存在しない");
assert(string(result1.last_author_name(1)) == "Bob Jones", ...
    "Case1: last_author_name が期待値と異なる: " + string(result1.last_author_name(1)));
assert(string(result1.last_author_institutions(1)) == "University B", ...
    "Case1: last_author_institutions が期待値と異なる: " + string(result1.last_author_institutions(1)));
assert(string(result1.first_author_name(1)) == "Alice Smith", ...
    "Case1: first_author_name が期待値と異なる: " + string(result1.first_author_name(1)));
fprintf("[PASS] Case1: 複数著者 - first_author != last_author\n");

%% -- Case 2: Single author -> first_* = last_* -----------------------------
T2 = table("Single author paper", "Abstract.", ...
    "Carol White", "University C", ...
    "Carol White", "University C", ...
    'VariableNames', ["title","abstract","first_author_name","first_author_institutions",...
                      "last_author_name","last_author_institutions"]);

result2 = openalex_to_normalized_works(T2, StrictValidation=false);

assert(string(result2.first_author_name(1)) == string(result2.last_author_name(1)), ...
    "Case2: 著者1人のとき first_author_name != last_author_name");
assert(string(result2.first_author_institutions(1)) == string(result2.last_author_institutions(1)), ...
    "Case2: 著者1人のとき first_author_institutions != last_author_institutions");
fprintf("[PASS] Case2: 著者1人 - first_* == last_*\n");

%% -- Case 3: No author (empty string) --------------------------------------
T3 = table("No author paper", "Abstract.", ...
    "", "", "", "", ...
    'VariableNames', ["title","abstract","first_author_name","first_author_institutions",...
                      "last_author_name","last_author_institutions"]);

result3 = openalex_to_normalized_works(T3, StrictValidation=false);

assert(string(result3.last_author_name(1)) == "", ...
    "Case3: 著者なしで last_author_name が空でない: " + string(result3.last_author_name(1)));
assert(string(result3.last_author_institutions(1)) == "", ...
    "Case3: 著者なしで last_author_institutions が空でない: " + string(result3.last_author_institutions(1)));
fprintf("[PASS] Case3: 著者なし → last_* が空文字\n");

%% -- Case 4: last_author_institutions with multiple "|"-delimited affiliations
T4 = table("Multi-inst paper", "Abstract.", ...
    "Dave Brown", "Inst A", ...
    "Eve Green", "Inst X | Inst Y", ...
    'VariableNames', ["title","abstract","first_author_name","first_author_institutions",...
                      "last_author_name","last_author_institutions"]);

result4 = openalex_to_normalized_works(T4, StrictValidation=false);

assert(contains(string(result4.last_author_institutions(1)), "|"), ...
    "Case4: last_author_institutions に '|' が含まれない: " + string(result4.last_author_institutions(1)));
fprintf("[PASS] Case4: last_author_institutions の '|' 区切り複数所属\n");

%% -- Column existence check (both first_author_name / last_author_name) ----
expectedCols = ["first_author_name", "first_author_institutions", ...
                "last_author_name",  "last_author_institutions"];
actualCols = string(result1.Properties.VariableNames);
for i = 1:numel(expectedCols)
    assert(ismember(expectedCols(i), actualCols), ...
        "列が存在しない: " + expectedCols(i));
end
fprintf("[PASS] 全4列（first/last × name/institutions）の存在確認\n");

fprintf("\n[ALL PASS] test_last_author_extraction_smoke 完了\n");
end
