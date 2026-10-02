function test_legacy_institutions_merge_smoke()
%TEST_LEGACY_INSTITUTIONS_MERGE_SMOKE  A legacy institutions.csv keeps its institutions included.
%
%   The legacy two-column format (Account, openalex_institution_id) has no include
%   column and always meant "every row is a target" (load_institutions_list). When
%   such a file is merged into new candidates, its rows must stay included; before,
%   they became include=0 and a later promotion silently dropped the whole list.
%   (Found by manual verification of the Batch tab.)

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', '..', 'src', 'openalex'));
addpath(fullfile(thisDir, '..', '..', 'src', 'util'));

tmp = fullfile(tempdir, 'smoke_legacy_institutions_merge');
if isfolder(tmp), rmdir(tmp, 's'); end
mkdir(tmp);
cleanup = onCleanup(@() rmdir(tmp, 's')); %#ok<NASGU>

%% Case 1: the legacy format is read as "all included" and reported as legacy
legacyPath = fullfile(tmp, 'legacy.csv');
fid = fopen(legacyPath, 'w', 'n', 'UTF-8');
fprintf(fid, 'Account,openalex_institution_id\n');
fprintf(fid, 'Alpha University,I1\n');
fprintf(fid, 'Alpha University,I2\n');
fprintf(fid, 'Beta Institute,I3\n');
fclose(fid);
[legacy, isLegacy] = read_institutions_review_csv(legacyPath);
assert(isLegacy, 'Case1: a file without an include column must be reported as legacy');
assert(height(legacy) == 3 && all(legacy.include == "1"), ...
    'Case1: every legacy row must read as included (include=1)');
fprintf("[PASS] Case1: legacy format reads as all included\n");

%% Case 2: a reviewed file keeps its own include values (blank means skip)
v2Path = fullfile(tmp, 'reviewed.csv');
fid = fopen(v2Path, 'w', 'n', 'UTF-8');
fprintf(fid, 'account,openalex_institution_id,display_name,include,role,note\n');
fprintf(fid, 'Alpha University,I1,Alpha University,1,main,\n');
fprintf(fid, 'Alpha University,I2,Alpha Hospital,0,hospital,\n');
fprintf(fid, 'Beta Institute,I3,Beta Institute,,,\n');
fclose(fid);
[reviewed, isLegacy] = read_institutions_review_csv(v2Path);
assert(~isLegacy, 'Case2: a file with an include column is not legacy');
assert(isequal(reviewed.include, ["1"; "0"; ""]), 'Case2: include values must be kept as written');
fprintf("[PASS] Case2: reviewed format keeps its include values\n");

%% Case 3: merging legacy rows into fresh candidates
fresh = table( ...
    ["Alpha University"; "Gamma College"], ["I1"; "I9"], ["Alpha University"; "Gamma College"], ...
    ["JP"; "JP"], [100; 50], [1; 1], ["main"; ""], ["" ; ""], ["found"; "found"], ...
    VariableNames=["account" "openalex_institution_id" "display_name" "country_code" "works_count" ...
    "include" "role" "note" "status"]);
merged = merge_institutions_review_table(fresh, legacy, "2026-10-02");

row = @(acc, id) merged(merged.account == acc & merged.openalex_institution_id == id, :);
assert(row("Alpha University", "I1").include == 1, 'Case3: a legacy row matching a fresh candidate stays included');
assert(row("Alpha University", "I2").include == 1, 'Case3: a legacy row the API did not return stays included');
assert(contains(row("Alpha University", "I2").note, "not returned by API"), 'Case3: not-returned rows keep their note');
assert(row("Beta Institute", "I3").include == 1, 'Case3: another legacy account stays included');
assert(row("Gamma College", "I9").include == 0, ...
    'Case3: a brand-new candidate is not included until the reviewer decides');
fprintf("[PASS] Case3: legacy rows survive a merge as included, new candidates start excluded\n");

fprintf("Smoke test passed: legacy institutions.csv merge\n");
end
