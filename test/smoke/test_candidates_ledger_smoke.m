function test_candidates_ledger_smoke()
%TEST_CANDIDATES_LEDGER_SMOKE  Phase L candidate ledger append/export smoke test.
%
%   The append engine is schema-agnostic: it protects any pre-existing column
%   (other than the managed run-id columns) across re-appends, without knowing
%   the column names. This test therefore uses neutral dummy columns
%   (extra_a .. extra_i, extra_num) to verify that protection, rather than any
%   domain-specific schema.

fprintf('\n=== test_candidates_ledger_smoke ===\n');

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'util'));
addpath(fullfile(projectRoot, 'src', 'export'));

tmpDir = tempname(tempdir);
mkdir(tmpDir);
cleanupObj = onCleanup(@() local_cleanup_tmpdir(tmpDir)); %#ok<NASGU>

ledgerPath = string(fullfile(tmpDir, 'candidates.jsonl'));
xlsxPath = string(fullfile(tmpDir, 'candidates.xlsx'));
mdPath = string(fullfile(tmpDir, 'repro_candidates.md'));

run1Dir = fullfile(tmpDir, 'run_001');
mkdir(run1Dir);
T1 = local_make_run_table();
write_jsonl(T1, fullfile(run1Dir, 'search_results.jsonl'));

fprintf('[T1] append first run ...');
r1 = append_to_candidates(string(run1Dir), ledgerPath=ledgerPath);
assert(r1.rows_appended == 2, 'T1: expected 2 appended rows');
ledger1 = read_jsonl(ledgerPath);
assert(height(ledger1) == 2, 'T1: ledger row count must be 2');
assert(all(ledger1.status == "new"), 'T1: initial status must be new');
fprintf(' PASS\n');

fprintf('[T2] dedup repeated append ...');
r2 = append_to_candidates(string(run1Dir), ledgerPath=ledgerPath);
ledger2 = read_jsonl(ledgerPath);
assert(r2.rows_appended == 0, 'T2: repeated append must not add rows');
assert(height(ledger2) == 2, 'T2: row count must stay 2');
fprintf(' PASS\n');

fprintf('[T3] preserve existing extra columns while refreshing metadata ...');
ledger2.status(1) = "reviewed";
ledger2.note(1) = "keep note";
ledger2.extra_a(1) = "preserved_a";
ledger2.extra_b(1) = "preserved_b";
ledger2.extra_c(1) = "preserved_c";
ledger2.extra_d(1) = "preserved_d";
ledger2.extra_e(1) = "preserved_e";
ledger2.extra_f(1) = "preserved_f";
ledger2.extra_g(1) = "preserved_g";
ledger2.extra_h(1) = "preserved_h";
ledger2.extra_i(1) = "preserved_i";
ledger2.extra_num(1) = 5;
write_jsonl(ledger2, ledgerPath);

T2 = T1;
T2.title(1) = "Updated candidate title";
T2.fwci(1) = 9.9;
T2.extra_a = [""; "incoming_a"];
T2.extra_b = [""; "incoming_b"];
T2.extra_c = [""; "incoming_c"];
T2.extra_d = [""; "incoming_d"];
T2.extra_e = [""; "incoming_e"];
T2.extra_f = [""; "incoming_f"];
T2.extra_g = [""; "incoming_g"];
T2.extra_h = [""; "incoming_h"];
T2.extra_i = [""; "incoming_i"];
T2.extra_num = [NaN; 3];
Tnew = T2(1, :);
Tnew.openalex_id = "W3";
Tnew.title = "Fresh candidate";
Tnew.doi = "10.1000/new003";
Tnew.doi_normalized = "10.1000/new003";
Tnew.publication_year = 2026;
Tnew.cited_by_count = 12;
Tnew.fwci = 3.1;
Tnew.repro_signal_score = 4;
Tnew.extra_a = "";
Tnew.extra_b = "";
Tnew.extra_c = "";
Tnew.extra_d = "";
Tnew.extra_e = "";
Tnew.extra_f = "";
Tnew.extra_g = "";
Tnew.extra_h = "";
Tnew.extra_i = "";
Tnew.extra_num = NaN;
T2 = [T2; Tnew];

append_to_candidates(T2, ledgerPath=ledgerPath, runId="run_002");
ledger3 = read_jsonl(ledgerPath);
row1 = ledger3(strcmp(ledger3.doi_normalized, "10.1000/existing001"), :);
assert(height(ledger3) == 3, 'T3: total rows must become 3');
assert(string(row1.status) == "reviewed", 'T3: status must be preserved');
assert(string(row1.note) == "keep note", 'T3: note must be preserved');
assert(string(row1.extra_a) == "preserved_a", 'T3: extra_a must be preserved');
assert(string(row1.extra_b) == "preserved_b", 'T3: extra_b must be preserved');
assert(string(row1.extra_c) == "preserved_c", 'T3: extra_c must be preserved');
assert(string(row1.extra_d) == "preserved_d", 'T3: extra_d must be preserved');
assert(string(row1.extra_e) == "preserved_e", 'T3: extra_e must be preserved');
assert(string(row1.extra_f) == "preserved_f", 'T3: extra_f must be preserved');
assert(string(row1.extra_g) == "preserved_g", 'T3: extra_g must be preserved');
assert(string(row1.extra_h) == "preserved_h", 'T3: extra_h must be preserved');
assert(string(row1.extra_i) == "preserved_i", 'T3: extra_i must be preserved');
assert(row1.extra_num == 5, 'T3: extra_num must be preserved');
assert(string(row1.title) == "Updated candidate title", 'T3: latest metadata must overwrite title');
assert(string(row1.last_seen_run_id) == "run_002", 'T3: last_seen_run_id must update');
row2 = ledger3(strcmp(ledger3.openalex_id, "W2"), :);
assert(string(row2.extra_a) == "incoming_a", 'T3: non-empty incoming extra_a must update blank existing value');
assert(string(row2.extra_b) == "incoming_b", 'T3: non-empty incoming extra_b must update blank existing value');
assert(row2.extra_num == 3, 'T3: non-empty incoming extra_num must update blank existing value');
newRow = ledger3(strcmp(ledger3.doi_normalized, "10.1000/new003"), :);
assert(string(newRow.extra_a) == "", 'T3: appended row extra_a must stay blank');
assert(isnan(newRow.extra_num), 'T3: appended row extra_num must stay NaN');
fprintf(' PASS\n');

fprintf('[T4] export xlsx / markdown ...');
export_candidates_xlsx(ledgerPath, xlsxPath);
export_candidates_md(ledgerPath, mdPath);
assert(isfile(xlsxPath), 'T4: candidates.xlsx was not generated');
assert(isfile(mdPath), 'T4: repro_candidates.md was not generated');
mdText = string(fileread(mdPath));
assert(contains(mdText, "| RP番号 | 論文 | DOI | Tier | 状態 | 特記 |"), 'T4: markdown header mismatch');
assert(contains(mdText, "Updated candidate title"), 'T4: reviewed row missing from markdown');
assert(contains(mdText, "[10.1000/existing001](https://doi.org/10.1000/existing001)"), 'T4: DOI link missing');
fprintf(' PASS\n');

fprintf('[T5] update ledger status/note helper ...');
res5 = update_candidates_ledger( ...
    ledgerPath=ledgerPath, ...
    doiNormalized="10.1000/new003", ...
    status="reviewed", ...
    note="promoted");
assert(res5.rows_updated == 1, 'T5: expected 1 updated row');
ledger5 = read_jsonl(ledgerPath);
row5 = ledger5(strcmp(string(ledger5.doi_normalized), "10.1000/new003"), :);
assert(height(row5) == 1, 'T5: target row missing');
assert(string(row5.status) == "reviewed", 'T5: status not updated');
assert(string(row5.note) == "promoted", 'T5: note not updated');
fprintf(' PASS\n');

fprintf('[T6] DOI/OpenAlex normalization and status validation ...');
T6 = T2(1:2, :);
T6.openalex_id = ["https://openalex.org/W10"; "W20"];
T6.title = ["Title A"; "Title B"];
T6.doi = ["https://doi.org/10.1000/ABC"; ""];
T6.doi_normalized = ["https://doi.org/10.1000/ABC"; ""];
T6.publication_year = [2025; 2025];
T6.cited_by_count = [1; 2];
T6.fwci = [1.5; 2.5];
T6.repro_signal_score = [1; 2];
T6.extra_a = [""; ""];
T6.extra_b = [""; ""];
T6.extra_c = [""; ""];
T6.extra_d = [""; ""];
T6.extra_e = [""; ""];
T6.extra_f = [""; ""];
T6.extra_g = [""; ""];
T6.extra_h = [""; ""];
T6.extra_i = [""; ""];
T6.extra_num = [NaN; NaN];
append_to_candidates(T6, ledgerPath=ledgerPath, runId="run_003");
ledger6 = read_jsonl(ledgerPath);
row6a = ledger6(strcmp(string(ledger6.openalex_id), "W10"), :);
assert(height(row6a) == 1, 'T6: openalex_id URL should normalize to short ID');
assert(string(row6a.doi_normalized) == "10.1000/abc", 'T6: DOI URL should normalize to DOI body');
res6 = update_candidates_ledger( ...
    ledgerPath=ledgerPath, ...
    doiNormalized="doi:10.1000/ABC", ...
    status="registered_RP12");
assert(res6.rows_updated == 1, 'T6: normalized DOI selector should match');
row6b = read_jsonl(ledgerPath);
row6b = row6b(strcmp(string(row6b.doi_normalized), "10.1000/abc"), :);
assert(string(row6b.status(1)) == "registered_RP12", 'T6: registered_RPxx status not applied');
try
    update_candidates_ledger(ledgerPath=ledgerPath, doiNormalized="10.1000/abc", status="done");
    error('T6: invalid status must error');
catch ex
    assert(contains(string(ex.identifier), "InvalidStatus"), 'T6: wrong error for invalid status');
end
oldPath = path;
cleanupPath = onCleanup(@() path(oldPath)); %#ok<NASGU>
utilDir = fullfile(projectRoot, 'src', 'util');
if contains(path, utilDir)
    rmpath(utilDir);
end
export_candidates_md(ledgerPath, mdPath);
export_candidates_xlsx(ledgerPath, xlsxPath);
assert(isfile(mdPath) && isfile(xlsxPath), 'T6: export helpers must self-resolve util path');
fprintf(' PASS\n');

fprintf('[T7] extra columns are independent and explicitly validated ...');
res7 = update_candidates_ledger( ...
    ledgerPath=ledgerPath, ...
    openalexId="W20", ...
    updateColumns="extra_g", ...
    updateValues="value_one");
assert(res7.rows_updated == 1, 'T7: expected one extra-column update');
ledger7 = read_jsonl(ledgerPath);
row7 = ledger7(strcmp(string(ledger7.openalex_id), "W20"), :);
assert(height(row7) == 1, 'T7: target row missing');
assert(string(row7.status) == "new", 'T7: status must not change when only extra columns are updated');
assert(string(row7.extra_g) == "value_one", 'T7: extra_g not updated');
res7b = update_candidates_ledger( ...
    ledgerPath=ledgerPath, ...
    openalexId="W20", ...
    status="reviewed", ...
    updateColumns=["extra_g"; "extra_h"], ...
    updateValues=["value_two"; "value_three"]);
ledger7b = read_jsonl(ledgerPath);
row7b = ledger7b(strcmp(string(ledger7b.openalex_id), "W20"), :);
assert(string(row7b.status) == "reviewed", 'T7: status update failed');
assert(string(row7b.extra_g) == "value_two", 'T7: extra_g update failed');
assert(string(row7b.extra_h) == "value_three", 'T7: extra_h update failed');
try
    update_candidates_ledger( ...
        ledgerPath=ledgerPath, ...
        openalexId="W20", ...
        updateColumns=["extra_g"; "extra_h"], ...
        updateValues="only_one_value");
    error('T7: mismatched extra-column update must error');
catch ex
    assert(contains(string(ex.identifier), "UpdateSizeMismatch"), 'T7: wrong error for mismatched extra-column update');
end
fprintf(' PASS\n');

fprintf('[T8] legacy ledger migration keeps extra columns optional ...');
legacyLedger = table( ...
    ["W90"], ...
    ["Legacy candidate"], ...
    ["10.1000/legacy"], ...
    ["10.1000/legacy"], ...
    ["legacy_run"], ...
    ["legacy_run"], ...
    ["reviewed"], ...
    ["keep"], ...
    'VariableNames', { ...
    'openalex_id', 'title', 'doi', 'doi_normalized', ...
    'first_seen_run_id', 'last_seen_run_id', 'status', 'note'});
write_jsonl(legacyLedger, ledgerPath);
append_to_candidates(legacyLedger, ledgerPath=ledgerPath, runId="run_legacy");
ledger8 = read_jsonl(ledgerPath);
assert(~ismember("extra_a", ledger8.Properties.VariableNames), 'T8: legacy ledger should not gain extra_a by default');
assert(~ismember("extra_num", ledger8.Properties.VariableNames), 'T8: legacy ledger should not gain extra_num by default');
res8 = update_candidates_ledger( ...
    ledgerPath=ledgerPath, ...
    openalexId="W90", ...
    updateColumns="extra_h", ...
    updateValues="legacy_value");
assert(res8.rows_updated == 1, 'T8: legacy extra-column update should succeed');
ledger8b = read_jsonl(ledgerPath);
row8b = ledger8b(strcmp(string(ledger8b.openalex_id), "W90"), :);
assert(string(row8b.extra_h) == "legacy_value", 'T8: legacy ledger must gain extra_h on update');
assert(string(row8b.status) == "reviewed", 'T8: legacy status must stay unchanged');
fprintf(' PASS\n');

fprintf('=== All tests passed ===\n\n');
end

function T = local_make_run_table()
T = table( ...
    ["W1"; "W2"], ...
    ["Existing candidate"; "ID-only candidate"], ...
    ["10.1000/existing001"; ""], ...
    ["10.1000/existing001"; ""], ...
    [2025; 2024], ...
    [20; 5], ...
    [2.5; 1.1], ...
    [3; 1], ...
    'VariableNames', { ...
    'openalex_id', 'title', 'doi', 'doi_normalized', ...
    'publication_year', 'cited_by_count', 'fwci', 'repro_signal_score'});
end

function local_cleanup_tmpdir(tmpDir)
if isfolder(tmpDir)
    rmdir(tmpDir, 's');
end
end
