function test_run_batch_smoke()
%TEST_RUN_BATCH_SMOKE  Batch input validation and institution-list integration smoke test.
%
%   How to run:
%     addpath("src/pipeline"); addpath("src/util");
%     addpath("test/smoke");
%     test_run_batch_smoke();
%
%   Test coverage:
%     T1. institutions CSV does not exist -> InputNotFound error
%     T2. CSV missing Account/account column -> MissingColumn error
%     T3. CSV missing openalex_institution_id column -> MissingColumn error
%     T4. All rows empty (Account/ID either missing) -> NoRows error
%     T5. Duplicate rows are removed (verify unique processing — no error)
%     T6. reviewed v2 CSV with all include=0 -> NoRows error
%     T7. Batch code uses load_institutions_list, passes resolveInstitutionIds=false, and exposes ledger append options
%     T8. main_run_batch exposes prepareList / Section 0.5 / dryRun / ledger options
%     T9. result struct has required fields
%     T10. run_meta preserves the input institution IDs when resolveInstitutionIds=false
%     T11. multi-ID reviewed v2 target is grouped into 1 batch row and IDs are joined with |
%     T12. dryRun returns preview counts without creating per-run outputs
%     T13. custom ledgerPath is used for appendToCandidates without touching the default ledger path
%         * T9-T12 require network + OpenAlex API key. Skipped if not configured.

fprintf('\n=== test_run_batch_smoke ===\n');
passCount = 0;

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'pipeline'));
addpath(fullfile(projectRoot, 'src', 'util'));
addpath(fullfile(projectRoot, 'src', 'config'));
addpath(fullfile(projectRoot, 'src', 'openalex'));
addpath(fullfile(projectRoot, 'src', 'adapters'));
addpath(fullfile(projectRoot, 'src', 'export'));

tmpDir = fullfile(tempdir, 'smoke_run_batch');
if isfolder(tmpDir)
    rmdir(tmpDir, 's');
elseif isfile(tmpDir)
    delete(tmpDir);
end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

%% T1: institutions CSV not found -> InputNotFound
fprintf('[T1] CSV missing -> InputNotFound ...');
try
    run_batch_from_institutions_list(fullfile(tmpDir, 'nonexistent.csv'), 'test');
    error('T1: error not thrown');
catch ex
    assert(contains(ex.identifier, 'InputNotFound'), ...
        ['T1: unexpected identifier: ' ex.identifier]);
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T2: Account/account column missing -> MissingColumn
fprintf('[T2] Account/account column missing -> MissingColumn ...');
csvNoAccount = fullfile(tmpDir, 'no_account.csv');
writecell({'openalex_institution_id'; 'I12345'}, csvNoAccount);
try
    run_batch_from_institutions_list(csvNoAccount, 'test');
    error('T2: error not thrown');
catch ex
    assert(contains(ex.identifier, 'MissingColumn'), ...
        ['T2: unexpected identifier: ' ex.identifier]);
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T3: openalex_institution_id column missing -> MissingColumn
fprintf('[T3] openalex_institution_id column missing -> MissingColumn ...');
csvNoId = fullfile(tmpDir, 'no_id.csv');
writecell({'Account'; 'TestUniversity'}, csvNoId);
try
    run_batch_from_institutions_list(csvNoId, 'test');
    error('T3: error not thrown');
catch ex
    assert(contains(ex.identifier, 'MissingColumn'), ...
        ['T3: unexpected identifier: ' ex.identifier]);
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T4: all rows empty -> NoRows
fprintf('[T4] all rows empty -> NoRows ...');
csvEmpty = fullfile(tmpDir, 'empty_rows.csv');
writecell({'Account', 'openalex_institution_id'; '', ''}, csvEmpty);
try
    run_batch_from_institutions_list(csvEmpty, 'test');
    error('T4: error not thrown');
catch ex
    assert(contains(ex.identifier, 'NoRows'), ...
        ['T4: unexpected identifier: ' ex.identifier]);
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T5: duplicate row filter -> not a CSV validation failure
fprintf('[T5] duplicate rows -> no CSV validation failure ...');
csvDup = fullfile(tmpDir, 'dup_rows.csv');
writecell({'Account', 'openalex_institution_id'; ...
           'UnivA',   'I111'; ...
           'UnivA',   'I111'; ...
           'UnivA',   'I111'}, csvDup);
try
    run_batch_from_institutions_list(csvDup, 'test', ...
        batchRootDir=fullfile(tmpDir, 'batch_out'));
catch ex
    badIds = {'InputNotFound', 'MissingColumn', 'NoRows'};
    isBadErr = any(cellfun(@(id) contains(ex.identifier, id), badIds));
    assert(~isBadErr, ...
        ['T5: CSV validation should not fail here (identifier=' ex.identifier ')']);
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T6: reviewed v2 with all include=0 -> NoRows
fprintf('[T6] reviewed v2 all include=0 -> NoRows ...');
csvExcluded = fullfile(tmpDir, 'all_excluded_v2.csv');
writecell({'account', 'openalex_institution_id', 'include'; ...
           'SkipMe', 'I12345', '0'}, csvExcluded);
try
    run_batch_from_institutions_list(csvExcluded, 'test');
    error('T6: error not thrown');
catch ex
    assert(contains(ex.identifier, 'NoRows'), ...
        ['T6: unexpected identifier: ' ex.identifier]);
end
fprintf(' PASS\n'); passCount = passCount + 1;

%% T7: source-level guard for loader + resolveInstitutionIds=false + ledger options
fprintf('[T7] uses load_institutions_list / resolveInstitutionIds=false / ledger options ...');
srcText = fileread(fullfile(projectRoot, 'src', 'pipeline', 'run_batch_from_institutions_list.m'));
assert(contains(srcText, 'load_institutions_list'), ...
    'T7: run_batch_from_institutions_list.m does not use load_institutions_list');
assert(contains(srcText, 'resolveInstitutionIds=false'), ...
    'T7: run_batch_from_institutions_list.m does not pass resolveInstitutionIds=false');
assert(contains(srcText, 'options.dryRun'), ...
    'T7: run_batch_from_institutions_list.m does not support dryRun');
assert(contains(srcText, 'options.appendToCandidates'), ...
    'T7: run_batch_from_institutions_list.m does not expose appendToCandidates');
assert(contains(srcText, 'options.ledgerPath'), ...
    'T7: run_batch_from_institutions_list.m does not expose ledgerPath');
assert(contains(srcText, 'appendToCandidates=options.appendToCandidates'), ...
    'T7: run_batch_from_institutions_list.m does not pass appendToCandidates');
assert(contains(srcText, 'ledgerPath=options.ledgerPath'), ...
    'T7: run_batch_from_institutions_list.m does not pass ledgerPath');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T8: main_run_batch front script exposes prepare section and ledger options
fprintf('[T8] main_run_batch exposes prepareList / Section 0.5 / dryRun / ledger options ...');
frontText = fileread(fullfile(projectRoot, 'main_run_batch.m'));
assert(contains(frontText, 'prepareList'), 'T8: main_run_batch.m missing prepareList');
assert(contains(frontText, '%% 0.5) Target list preparation'), 'T8: main_run_batch.m missing Section 0.5');
assert(contains(frontText, 'dryRun'), 'T8: main_run_batch.m missing dryRun');
assert(contains(frontText, 'appendToCandidates'), 'T8: main_run_batch.m missing appendToCandidates');
assert(contains(frontText, 'ledgerPath'), 'T8: main_run_batch.m missing ledgerPath');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T9-T13: network-dependent integration checks
fprintf('[T9-T13] result / run_meta / multi-ID grouping / dryRun / custom ledgerPath (network required) ...');
apiKey = local_load_api_key(projectRoot);
if apiKey == ""
    fprintf(' SKIP (openalex.api_key not configured)\n');
elseif ~local_network_reachable(apiKey)
    fprintf(' SKIP (network unreachable)\n');
else
    try
        %% T9: required result fields
        csvOne = fullfile(tmpDir, 'one_inst.csv');
        writecell({'Account', 'openalex_institution_id'; ...
                   'Test University', 'I4210106694'}, csvOne);
        r9 = run_batch_from_institutions_list(csvOne, 'machine learning', ...
            '2025-01-01', '2025-01-31', ...
            batchRootDir=fullfile(tmpDir, 'batch_t8'), ...
            maxPages=1, requireOpenAccess=false);

        assert(isfield(r9, 'batch_id'), 'T9: batch_id missing');
        assert(isfield(r9, 'batch_dir'), 'T9: batch_dir missing');
        assert(isfield(r9, 'summary_csv'), 'T9: summary_csv missing');
        assert(isfield(r9, 'total_institutions'), 'T9: total_institutions missing');
        assert(isfield(r9, 'success_count'), 'T9: success_count missing');
        assert(isfield(r9, 'failed_count'), 'T9: failed_count missing');
        assert(isfield(r9, 'batch_search_results_jsonl'), 'T9: batch_search_results_jsonl missing');
        assert(isfield(r9, 'batch_search_results_xlsx'), 'T9: batch_search_results_xlsx missing');
        assert(r9.total_institutions == int32(1), 'T9: total_institutions != 1');
        assert(isfile(r9.summary_csv), 'T9: batch_summary.csv missing');

        Tsummary9 = readtable(r9.summary_csv, 'TextType', 'string', ...
            'VariableNamingRule', 'preserve', 'Delimiter', ',');
        expectedCols = ["batch_id", "run_id", "institution_name", ...
                        "openalex_institution_id", "status", "rows_fetched", "error_message"];
        for ci = 1:numel(expectedCols)
            assert(ismember(expectedCols(ci), string(Tsummary9.Properties.VariableNames)), ...
                sprintf('T9: batch_summary.csv missing column "%s"', expectedCols(ci)));
        end
        local_throw_if_rate_limited(Tsummary9);
        assert(height(Tsummary9) == 1, sprintf('T9: batch_summary.csv rows=%d (expected 1)', height(Tsummary9)));
        fprintf(' PASS\n');
        passCount = passCount + 1;

        %% T10: run_meta preserves input IDs
        fprintf('[T10] run_meta preserves input institution IDs ...');
        runDirs = dir(fullfile(r9.batch_dir, 'runs', '*'));
        runDirs = runDirs([runDirs.isdir] & ~startsWith(string({runDirs.name}), "."));
        assert(~isempty(runDirs), 'T10: institution run directory not found');
        runMetaPath = fullfile(runDirs(1).folder, runDirs(1).name, 'logs', 'run_meta.json');
        assert(isfile(runMetaPath), 'T10: run_meta.json not found');
        meta = jsondecode(fileread(runMetaPath));
        assert(isfield(meta, 'first_author_institution_ids'), 'T10: first_author_institution_ids missing');
        assert(string(meta.first_author_institution_ids) == "I4210106694", ...
            'T10: first_author_institution_ids=%s (expected I4210106694)', string(meta.first_author_institution_ids));
        fprintf(' PASS\n');
        passCount = passCount + 1;

        %% T11: reviewed v2 multi-ID target -> 1 batch row with joined IDs
        fprintf('[T11] reviewed v2 multi-ID target -> one batch row ...');
        csvMulti = fullfile(tmpDir, 'reviewed_multi_id.csv');
        writecell({'account', 'openalex_institution_id', 'display_name', 'include', 'role'; ...
                   'Example Medical University', 'I100000001', 'Example Medical University', '1', 'main'; ...
                   'Example Medical University', 'I100000002', 'Example Medical University Hospital', '1', 'hospital'; ...
                   'Example Medical University', 'I9999999999', 'Excluded Candidate', '0', 'other'}, csvMulti);
        r11 = run_batch_from_institutions_list(csvMulti, 'machine learning', ...
            '2025-01-01', '2025-01-31', ...
            batchRootDir=fullfile(tmpDir, 'batch_t10'), ...
            maxPages=1, requireOpenAccess=false);
        assert(r11.total_institutions == int32(1), 'T11: total_institutions != 1');
        Tsummary11 = readtable(r11.summary_csv, 'TextType', 'string', ...
            'VariableNamingRule', 'preserve', 'Delimiter', ',');
        local_throw_if_rate_limited(Tsummary11);
        assert(height(Tsummary11) == 1, 'T11: batch_summary.csv row count != 1');
        assert(Tsummary11.institution_name(1) == "Example Medical University", ...
            'T11: institution_name mismatch');
        assert(Tsummary11.openalex_institution_id(1) == "I100000001|I100000002", ...
            'T11: joined ID text mismatch: %s', Tsummary11.openalex_institution_id(1));
        runDirs11 = dir(fullfile(r11.batch_dir, 'runs', '*'));
        runDirs11 = runDirs11([runDirs11.isdir] & ~startsWith(string({runDirs11.name}), "."));
        assert(~isempty(runDirs11), 'T11: institution run directory not found');
        runMetaPath11 = fullfile(runDirs11(1).folder, runDirs11(1).name, 'logs', 'run_meta.json');
        assert(isfile(runMetaPath11), 'T11: run_meta.json not found');
        meta11 = jsondecode(fileread(runMetaPath11));
        assert(isfield(meta11, 'filter') && contains(string(meta11.filter), ...
            "authorships.institutions.id:I100000001|I100000002"), ...
            'T11: filter string does not contain the joined OR institution IDs');
        fprintf(' PASS\n');
        passCount = passCount + 1;

        %% T12: dryRun -> preview only, no per-run outputs required
        fprintf('[T12] dryRun -> preview counts only ...');
        csvDry = fullfile(tmpDir, 'dry_run.csv');
        writecell({'Account', 'openalex_institution_id'; ...
                   'Test University', 'I4210106694'}, csvDry);
        r12 = run_batch_from_institutions_list(csvDry, 'machine learning', ...
            '2025-01-01', '2025-01-31', ...
            batchRootDir=fullfile(tmpDir, 'batch_t12'), ...
            dryRun=true, requireOpenAccess=false);
        assert(isfield(r12, 'dry_run') && r12.dry_run, 'T12: result.dry_run missing or false');
        assert(isfile(r12.summary_csv), 'T12: summary CSV missing');
        Tsummary12 = readtable(r12.summary_csv, 'TextType', 'string', ...
            'VariableNamingRule', 'preserve', 'Delimiter', ',');
        local_throw_if_rate_limited(Tsummary12);
        assert(isfield(r12, 'dry_run_count') && r12.dry_run_count == int32(1), 'T12: dry_run_count mismatch');
        assert(Tsummary12.status(1) == "dry_run", 'T12: summary status must be dry_run');
        assert(strlength(Tsummary12.error_message(1)) > 0, 'T12: filter text should be recorded');
        fprintf(' PASS\n');
        passCount = passCount + 1;

        %% T13: custom ledgerPath is used for appendToCandidates
        fprintf('[T13] custom ledgerPath is used for appendToCandidates ...');
        csvLedger = fullfile(tmpDir, 'ledger_run.csv');
        writecell({'account', 'openalex_institution_id', 'display_name', 'include', 'role'; ...
                   'Example Medical University', 'I100000001', 'Example Medical University', '1', 'main'; ...
                   'Example Medical University', 'I100000002', 'Example Medical University Hospital', '1', 'hospital'}, csvLedger);
        customLedgerPath = string(fullfile(tmpDir, 'custom_candidates.jsonl'));
        defaultLedgerPath = string(fullfile(projectRoot, 'result', 'candidates', 'candidates.jsonl'));
        defaultExistsBefore = isfile(defaultLedgerPath);
        if defaultExistsBefore
            defaultLedgerInfoBefore = dir(defaultLedgerPath);
        else
            defaultLedgerInfoBefore = [];
        end
        r13 = run_batch_from_institutions_list(csvLedger, 'machine learning', ...
            '2025-01-01', '2025-01-31', ...
            batchRootDir=fullfile(tmpDir, 'batch_t13'), ...
            maxPages=1, requireOpenAccess=false, ...
            appendToCandidates=true, ...
            ledgerPath=customLedgerPath);
        assert(r13.success_count == int32(1), 'T13: success_count != 1');
        assert(isfield(r13, 'candidates_jsonl'), 'T13: result.candidates_jsonl missing');
        assert(isfield(r13, 'candidates_xlsx'), 'T13: result.candidates_xlsx missing');
        assert(isfield(r13, 'candidates_md'), 'T13: result.candidates_md missing');
        assert(string(r13.candidates_jsonl) == customLedgerPath, 'T13: result.candidates_jsonl mismatch');
        assert(isfile(customLedgerPath), 'T13: custom ledgerPath was not created');
        ledger13 = read_jsonl(customLedgerPath);
        assert(height(ledger13) > 0, 'T13: custom ledger is empty');
        assert(isfile(string(r13.candidates_xlsx)), 'T13: candidates xlsx missing');
        assert(isfile(string(r13.candidates_md)), 'T13: candidates markdown missing');
        if defaultExistsBefore
            defaultLedgerInfoAfter = dir(defaultLedgerPath);
            assert(defaultLedgerInfoAfter.datenum == defaultLedgerInfoBefore.datenum && ...
                defaultLedgerInfoAfter.bytes == defaultLedgerInfoBefore.bytes, ...
                'T13: default ledger was modified despite custom ledgerPath');
        else
            assert(~isfile(defaultLedgerPath), ...
                'T13: default ledger was created despite custom ledgerPath');
        end
        fprintf(' PASS\n');
        passCount = passCount + 1;
    catch exNet
        if local_is_network_error(exNet)
            fprintf(' SKIP (network/rate-limit constrained: %s)\n', exNet.message);
        else
            rethrow(exNet);
        end
    end
end

% T1-T8 are mandatory (T9-T12 can be skipped as they depend on network)
assert(passCount >= 8, sprintf('test_run_batch_smoke: T1-T8 are mandatory (passCount=%d/8)', passCount));
fprintf('\n=== test_run_batch_smoke: %d PASSED ===\n\n', passCount);
end

function apiKey = local_load_api_key(projectRoot)
apiKey = "";
jsonPath = fullfile(projectRoot, 'config', 'settings.json');
if isfile(jsonPath)
    try
        cfg = jsondecode(fileread(jsonPath));
        if isfield(cfg, 'openalex') && isfield(cfg.openalex, 'api_key')
            apiKey = strtrim(string(cfg.openalex.api_key));
        end
    catch
    end
end
envKey = strtrim(string(getenv('ANYRESEARCH_OPENALEX_API_KEY')));
if envKey ~= ""
    apiKey = envKey;
end
end

function ok = local_network_reachable(apiKey)
ok = false;
try
    info = get_openalex_rate_limit_status(apiKey, 8);
    enoughCredits = isnan(info.credits_remaining) || info.credits_remaining >= 3;
    ok = info.ok && info.can_query && enoughCredits;
catch
end
end

function tf = local_is_network_error(ex)
msg = string(ex.message);
idf = string(ex.identifier);
tf = contains(msg, "429") || contains(msg, "503") || ...
     contains(msg, "Too Many Requests") || contains(msg, "Service Unavailable") || ...
     contains(msg, "webread") || contains(msg, "urlread") || ...
     contains(msg, "readContentFromWebService") || contains(idf, "MATLAB:webread");
end

function local_throw_if_rate_limited(Tsummary)
if ~istable(Tsummary)
    return;
end
vars = string(Tsummary.Properties.VariableNames);
if ~all(ismember(["status", "error_message"], vars))
    return;
end
statusVals = string(Tsummary.status);
msgVals = string(Tsummary.error_message);
mask = statusVals == "failed" & ...
    (contains(msgVals, "429") | contains(msgVals, "Too Many Requests") | ...
     contains(msgVals, "503") | contains(msgVals, "Service Unavailable"));
if any(mask)
    firstMsg = msgVals(find(mask, 1, "first"));
    error("test_run_batch_smoke:NetworkSkip", "%s", firstMsg);
end
end
