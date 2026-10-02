function test_institutions_merge_order_smoke()
%TEST_INSTITUTIONS_MERGE_ORDER_SMOKE  Newly generated candidates come before rows carried over.
%
%   Generating candidates merges the existing institutions list into the new rows. The new
%   (found / not_found) rows used to be sorted in among up to dozens of carried rows, so the
%   reviewer had to hunt for them. Now the rows of this generation come first; carried rows
%   follow. Inside each group the existing order (account, status, include, works) holds.
%   (Found by manual verification of the Batch tab.)

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', '..', 'src', 'openalex'));

vars = ["account" "openalex_institution_id" "display_name" "country_code" "works_count" ...
    "include" "role" "note" "status"];
fresh = table( ...
    ["Mid University"; "Mid University"; "Zeta Institute"], ["I20"; "I21"; ""], ...
    ["Mid University"; "Mid Hospital"; ""], ["JP"; "JP"; ""], [500; 90; 0], ...
    [1; 0; 0], ["main"; "hospital"; ""], [""; ""; ""], ["found"; "found"; "not_found"], ...
    VariableNames=vars);
existing = table( ...
    ["Alpha College"; "Mid University"; "Omega School"], ["I1"; "I22"; "I3"], ...
    ["Alpha College"; "Mid Annex"; "Omega School"], ["JP"; "JP"; "JP"], [10; 5; 7], ...
    [1; 1; 0], ["main"; ""; ""], [""; ""; ""], ["found"; "found"; "found"], ...
    VariableNames=vars);

merged = merge_institutions_review_table(fresh, existing, "2026-10-02");

assert(height(merged) == 6, "expected 3 fresh + 3 carried rows, got %d", height(merged));
assert(isequal(string(merged.Properties.VariableNames), vars), "the nine review columns must stay as they are");

% rows 1-3: this generation, in the usual order (account, then found before not_found, then works)
assert(isequal(merged.openalex_institution_id(1:3), ["I20"; "I21"; ""]), ...
    "the three new rows must come first, got: %s", strjoin(merged.openalex_institution_id(1:3)', ","));
assert(isequal(merged.status(1:3), ["found"; "found"; "not_found"]), "new rows keep found before not_found");

% rows 4-6: carried over, marked as such, ordered by account
assert(isequal(merged.openalex_institution_id(4:6), ["I1"; "I22"; "I3"]), ...
    "carried rows must follow, ordered by account, got: %s", strjoin(merged.openalex_institution_id(4:6)', ","));
assert(all(contains(merged.note(4:6), "not returned by API")), "carried rows keep their note");
assert(all(~contains(merged.note(1:3), "not returned by API")), "new rows have no carried-over note");

% a reviewed decision on a carried row survives, and a matching row keeps its decision too
assert(merged.include(4) == 1 && merged.include(5) == 1, "carried include values must be kept");

fprintf("Smoke test passed: merge order (new rows first)\n");
end
