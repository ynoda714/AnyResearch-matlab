function test_arxiv_smoke()
%TEST_ARXIV_SMOKE  Smoke tests for arXiv integration (E-1c / E-1d).
%
%   How to run:
%     addpath("src/openalex"); addpath("src/adapters"); addpath("src/util");
%     addpath("test/smoke");
%     test_arxiv_smoke();
%
%   Test coverage (network-free: T4-T8, plus merge-compat T9):
%     T4. arxiv_to_normalized_works: exactly 25 columns, all values correct
%         -- includes matlab_mentioned, source_name, type, single-author edge case,
%            empty-arxiv_id fallback record_id, and 0-row input schema
%     T5. arxiv_to_normalized_works: doi_normalized is lowercase+trim;
%         raw doi column preserved as-is (not auto-trimmed)
%     T6. arxiv_to_normalized_works: source_dataset = "arxiv" for all rows
%     T7. arxiv_to_normalized_works: all fixed values
%         -- cited_by_count=NaN, is_oa=1.0(double), type="preprint", language=""
%     T8. Dedup logic: 3 scenarios (mixed / all-kept / all-removed)
%     T9. normalized works merge compatibility with table-first pipeline
%
%   Network-required tests (skipped here):
%     T1. fetch_arxiv_works: searchQuery only, >= 1 result returned
%     T2. fetch_arxiv_works: category filter reduces results
%     T3. fetch_arxiv_works: fromDate/toDate narrows result set
%     T10. useArxiv=false: no arXiv call invoked (requires run_pipeline E-1e)

fprintf('\n=== test_arxiv_smoke ===\n');
passCount = 0;

thisDir     = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'openalex'));
addpath(fullfile(projectRoot, 'src', 'adapters'));
addpath(fullfile(projectRoot, 'src', 'config'));
addpath(fullfile(projectRoot, 'src', 'util'));

mockArxiv = local_mock_arxiv_table();

%% T4: exactly 20 columns, all field values correct
fprintf('[T4] arxiv_to_normalized_works: schema completeness + values ...');
result4 = arxiv_to_normalized_works(mockArxiv);
requiredCols = { ...
    'record_id', 'title', 'abstract', 'openalex_id', 'doi', 'doi_normalized', ...
    'publication_year', 'cited_by_count', 'source_dataset', ...
    'first_author_name', 'first_author_institutions', ...
    'last_author_name', 'last_author_institutions', ...
    'mentions_dataset', 'mentions_code', 'mentions_library', 'mentions_metrics', 'repro_signal_score', ...
    'matlab_mentioned', 'is_oa', 'type', 'source_name', 'open_access_url', ...
    'topics', 'language'};
% Column count: must be exactly 25 (no extra columns)
assert(width(result4) == 25, ...
    sprintf('T4: expected 25 columns, got %d', width(result4)));
for ci = 1:numel(requiredCols)
    assert(ismember(requiredCols{ci}, result4.Properties.VariableNames), ...
        ['T4: missing column: ', requiredCols{ci}]);
end
% Row count
assert(height(result4) == 2, 'T4: row count mismatch');
% record_id / openalex_id format
assert(result4.record_id(1) == "arxiv:2301.00001",   'T4: record_id row1');
assert(result4.openalex_id(1) == "arxiv:2301.00001", 'T4: openalex_id row1');
% publication_year from ISO 8601
assert(result4.publication_year(1) == 2023, 'T4: publication_year row1');
assert(result4.publication_year(2) == 2022, 'T4: publication_year row2');
% source_name: row1=journal_ref, row2=fallback "preprint"
assert(result4.source_name(1) == "Nature 2023", 'T4: source_name uses journal_ref');
assert(result4.source_name(2) == "preprint",    'T4: source_name fallback for empty journal_ref');
% open_access_url = pdf_url (both rows)
assert(result4.open_access_url(1) == "https://arxiv.org/pdf/2301.00001", 'T4: open_access_url row1');
assert(result4.open_access_url(2) == "https://arxiv.org/pdf/2301.00002", 'T4: open_access_url row2');
% doi_normalized: lowercase + trim applied to row1; row2 empty doi -> empty
assert(result4.doi_normalized(1) == "10.1000/testdoi.001", 'T4: doi_normalized row1 (lowercase+trim)');
assert(result4.doi_normalized(2) == "", 'T4: doi_normalized row2 (empty -> empty)');
% topics = primary_category
assert(result4.topics(1) == "cs.CL",   'T4: topics row1');
assert(result4.topics(2) == "quant-ph", 'T4: topics row2');
% language: always empty (arXiv does not provide language info)
assert(all(result4.language == ""), 'T4: language must be empty for all rows');
% Multi-author row1
assert(result4.first_author_name(1) == "Alice Wang", 'T4: first_author_name row1');
assert(result4.last_author_name(1)  == "Bob Smith",  'T4: last_author_name row1 (trailing)');
assert(result4.first_author_institutions(1) == "MIT",      'T4: first_author_inst row1');
assert(result4.last_author_institutions(1)  == "Stanford", 'T4: last_author_inst row1');
% Single-author row2 -- last_author must equal first_author
assert(result4.first_author_name(2) == "Carol Lee", 'T4: first_author_name row2 (single author)');
assert(result4.last_author_name(2)  == "Carol Lee", 'T4: last_author_name row2 = first (single author)');
assert(result4.first_author_institutions(2) == "", 'T4: first_author_inst row2 (no affiliation)');
assert(result4.last_author_institutions(2)  == "", 'T4: last_author_inst row2 (no affiliation)');
% matlab_mentioned: row1 abstract contains "MATLAB" -> true; row2 abstract empty -> false
assert(result4.matlab_mentioned(1) == true,  'T4: matlab_mentioned row1 (MATLAB in abstract)');
assert(result4.matlab_mentioned(2) == false, 'T4: matlab_mentioned row2 (empty abstract)');
assert(result4.mentions_library(1) == true, 'T4: mentions_library row1');
assert(result4.repro_signal_score(1) >= 1, 'T4: repro_signal_score row1');
% type
assert(all(result4.type == "preprint"), 'T4: type must be "preprint"');
% 0-row input: schema must be correct
emptyArxiv  = local_mock_arxiv_table();
emptyArxiv  = emptyArxiv([], :);
result4zero = arxiv_to_normalized_works(emptyArxiv);
assert(height(result4zero) == 0,  'T4: 0-row input must return empty table');
assert(width(result4zero)  == 25, 'T4: 0-row input must have 25 columns');
% empty arxiv_id: record_id must fallback to "row_N"
mockWithEmptyId = local_mock_arxiv_table();
mockWithEmptyId.arxiv_id(2) = "";
resultFallback = arxiv_to_normalized_works(mockWithEmptyId);
assert(startsWith(resultFallback.record_id(2), "row_"), ...
    'T4: empty arxiv_id must produce record_id = "row_N"');
assert(resultFallback.openalex_id(2) == "", ...
    'T4: empty arxiv_id must produce empty openalex_id');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T5: doi_normalized is lowercase+trim; raw doi preserved as-is
fprintf('[T5] arxiv_to_normalized_works: doi_normalized vs raw doi ...');
result5 = arxiv_to_normalized_works(mockArxiv);
% Raw doi(1): must be the exact original value (uppercase + trailing space)
assert(result5.doi(1) == "10.1000/TestDOI.001 ", ...
    'T5: raw doi(1) must preserve original case and trailing space');
% row2 has no DOI: both doi and doi_normalized must be empty
assert(result5.doi(2) == "", 'T5: raw doi(2) must be empty');
assert(result5.doi_normalized(2) == "", 'T5: empty doi -> empty doi_normalized');
% Normalized: lowercase + trim applied
assert(result5.doi_normalized(1) == "10.1000/testdoi.001", ...
    'T5: doi_normalized must be lowercase+trimmed');
% Explicit independence check: raw doi differs from normalized
assert(result5.doi(1) ~= result5.doi_normalized(1), ...
    'T5: raw doi must differ from doi_normalized (case/space preserved in doi col)');
assert(lower(strtrim(result5.doi(1))) == result5.doi_normalized(1), ...
    'T5: lower+strtrim(doi) must equal doi_normalized');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T6: source_dataset = "arxiv" for all rows
fprintf('[T6] arxiv_to_normalized_works: source_dataset ...');
result6 = arxiv_to_normalized_works(mockArxiv);
assert(all(result6.source_dataset == "arxiv"), 'T6: source_dataset must be "arxiv" for all rows');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T7: all fixed values correct (cited_by_count, is_oa, type, language)
fprintf('[T7] arxiv_to_normalized_works: fixed values ...');
result7 = arxiv_to_normalized_works(mockArxiv);
% cited_by_count: NaN for all (arXiv does not provide citation data)
assert(all(isnan(result7.cited_by_count)), ...
    'T7: cited_by_count must be NaN for all rows');
% is_oa: double 1.0 (not logical) for CSV round-trip consistency
assert(isa(result7.is_oa, 'double'), ...
    'T7: is_oa must be double (not logical) for CSV round-trip consistency');
assert(all(result7.is_oa == 1.0), ...
    'T7: is_oa must be 1.0 for all arXiv rows');
% type: fixed "preprint"
assert(all(result7.type == "preprint"), ...
    'T7: type must be "preprint" for all arXiv rows');
% language: fixed "" (arXiv does not provide language info)
assert(all(result7.language == ""), ...
    'T7: language must be "" for all arXiv rows');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T8: Dedup logic -- 3 scenarios covering mixed / all-kept / all-removed
fprintf('[T8] Dedup logic: 3 scenarios ...');
T_oa = table( ...
    ["10.1000/dup.001"; "10.2000/dup.002"], ...
    'VariableNames', {'doi_normalized'});

% Scenario A: mixed -- 1 dup removed, 1 empty-DOI kept, 1 unique kept
T_ax_a = table(["10.1000/dup.001"; ""; "10.3000/ax.003"], 'VariableNames', {'doi_normalized'});
hasArxivDoi = strlength(T_ax_a.doi_normalized) > 0;
isDuplicate = hasArxivDoi & ismember(T_ax_a.doi_normalized, T_oa.doi_normalized);
T_dedup_a   = T_ax_a(~isDuplicate, :);
assert(height(T_dedup_a) == 2, ...
    'T8-A: expected 2 rows (empty-DOI + unique)');
assert(~ismember("10.1000/dup.001", T_dedup_a.doi_normalized), ...
    'T8-A: duplicate DOI must be removed');
assert(ismember("", T_dedup_a.doi_normalized), ...
    'T8-A: empty-DOI row must be kept');
assert(ismember("10.3000/ax.003", T_dedup_a.doi_normalized), ...
    'T8-A: unique DOI row must be kept');

% Scenario B: no overlaps -- all arXiv rows kept
T_ax_b = table(["10.9001/ax.new"; "10.9002/ax.new2"], 'VariableNames', {'doi_normalized'});
hasB = strlength(T_ax_b.doi_normalized) > 0;
isDupB = hasB & ismember(T_ax_b.doi_normalized, T_oa.doi_normalized);
T_dedup_b = T_ax_b(~isDupB, :);
assert(height(T_dedup_b) == 2, 'T8-B: all rows kept when no DOI overlap');
assert(ismember("10.9001/ax.new",  T_dedup_b.doi_normalized), 'T8-B: row1 DOI must be kept');
assert(ismember("10.9002/ax.new2", T_dedup_b.doi_normalized), 'T8-B: row2 DOI must be kept');

% Scenario C: all duplicates -- all arXiv rows removed
T_ax_c = table(["10.1000/dup.001"; "10.2000/dup.002"], 'VariableNames', {'doi_normalized'});
hasC = strlength(T_ax_c.doi_normalized) > 0;
isDupC = hasC & ismember(T_ax_c.doi_normalized, T_oa.doi_normalized);
T_dedup_c = T_ax_c(~isDupC, :);
assert(height(T_dedup_c) == 0, 'T8-C: all rows removed when all DOIs are duplicates');

fprintf(' PASS\n'); passCount = passCount + 1;

%% T9: Merge logic compatible with E-1e (local_align_table: type cast + column order)
fprintf('[T9] Merge + type alignment: logical matlab_mentioned -> double, vertcat stable ...');
% Simulate T_oa as loaded from CSV (matlab_mentioned is double 0/1, is_oa is double)
T_oa9 = table( ...
    ["openalex:W1"; "openalex:W2"], ...
    ["OA Title 1"; "OA Title 2"], ...
    ["OA Abstract 1"; "OA Abstract 2"], ...
    ["W1"; "W2"], ...
    ["10.1000/oa.001"; "10.1000/oa.002"], ...
    ["10.1000/oa.001"; "10.1000/oa.002"], ...
    [2023; 2022], ...
    [10.0; 5.0], ...
    ["openalex"; "openalex"], ...
    ["Auth A"; "Auth B"], ...
    ["Inst A"; "Inst B"], ...
    ["Auth A"; "Auth B"], ...
    ["Inst A"; "Inst B"], ...
    [0.0; 0.0], ...   % mentions_dataset
    [0.0; 0.0], ...   % mentions_code
    [1.0; 0.0], ...   % mentions_library
    [0.0; 0.0], ...   % mentions_metrics
    [1.0; 0.0], ...   % repro_signal_score
    [1.0; 0.0], ...   % matlab_mentioned: double (CSV round-trip)
    [1.0; 0.0], ...   % is_oa: double
    ["article"; "review"], ...
    ["Jrnl A"; "Jrnl B"], ...
    ["https://a"; "https://b"], ...
    ["cs.AI"; "ML"], ...
    ["en"; "en"], ...
    'VariableNames', {'record_id','title','abstract','openalex_id','doi','doi_normalized', ...
        'publication_year','cited_by_count','source_dataset','first_author_name', ...
        'first_author_institutions','last_author_name','last_author_institutions', ...
        'mentions_dataset','mentions_code','mentions_library','mentions_metrics','repro_signal_score', ...
        'matlab_mentioned','is_oa','type','source_name','open_access_url','topics','language'} ...
    );
% Simulate T_arxiv from arxiv_to_normalized_works (matlab_mentioned is logical)
T_ax9 = table( ...
    ["arxiv:2301.10"; "arxiv:2301.11"], ...
    ["arXiv Title 1"; "arXiv Title 2"], ...
    ["arXiv Abstract 1"; "arXiv Abstract 2"], ...
    ["arxiv:2301.10"; "arxiv:2301.11"], ...
    ["10.1000/oa.001"; ""], ...   % row1 DOI duplicates OA; row2 empty -> kept
    ["10.1000/oa.001"; ""], ...
    [2023; 2022], ...
    [NaN; NaN], ...
    ["arxiv"; "arxiv"], ...
    ["Auth X"; "Auth Y"], ...
    ["MIT"; ""], ...
    ["Auth X"; "Auth Y"], ...
    ["MIT"; ""], ...
    logical([false; false]), ...  % mentions_dataset
    logical([false; false]), ...  % mentions_code
    logical([true; false]), ...   % mentions_library
    logical([false; false]), ...  % mentions_metrics
    [1.0; 0.0], ...
    logical([true; false]), ...   % matlab_mentioned: logical (NOT double)
    [1.0; 1.0], ...
    ["preprint"; "preprint"], ...
    ["preprint"; "preprint"], ...
    ["https://arxiv.org/pdf/1"; "https://arxiv.org/pdf/2"], ...
    ["cs.CL"; "physics"], ...
    [""; ""], ...
    'VariableNames', {'record_id','title','abstract','openalex_id','doi','doi_normalized', ...
        'publication_year','cited_by_count','source_dataset','first_author_name', ...
        'first_author_institutions','last_author_name','last_author_institutions', ...
        'mentions_dataset','mentions_code','mentions_library','mentions_metrics','repro_signal_score', ...
        'matlab_mentioned','is_oa','type','source_name','open_access_url','topics','language'} ...
    );
% Dedup (same logic as run_pipeline E-1e)
hasArxivDoi9 = strlength(T_ax9.doi_normalized) > 0;
isDuplicate9 = hasArxivDoi9 & ismember(T_ax9.doi_normalized, T_oa9.doi_normalized);
T_ax9_dedup  = T_ax9(~isDuplicate9, :);
assert(height(T_ax9_dedup) == 1, 'T9: dedup must remove row with duplicate DOI');
assert(T_ax9_dedup.doi_normalized(1) == "", 'T9: surviving row must be empty-DOI row');
% Type alignment: logical -> double (mirrors local_align_table in run_pipeline)
assert(isa(T_ax9_dedup.matlab_mentioned, 'logical'), 'T9: pre-align matlab_mentioned must be logical');
T_ax9_dedup.matlab_mentioned = double(T_ax9_dedup.matlab_mentioned);
assert(isa(T_ax9_dedup.matlab_mentioned, 'double'), 'T9: post-align matlab_mentioned must be double');
% vertcat: must succeed with same column names
T_merged9 = [T_oa9; T_ax9_dedup];
assert(height(T_merged9) == 3,             'T9: 2 OA + 1 arXiv = 3 rows');
assert(width(T_merged9)  == 25,            'T9: merged table must keep 25 columns');
% OA rows must remain the first 2 rows
assert(all(T_merged9.source_dataset(1:2) == "openalex"), 'T9: first 2 rows must be from openalex');
assert(T_merged9.record_id(1) == "openalex:W1",   'T9: row1 record_id preserved');
assert(T_merged9.record_id(2) == "openalex:W2",   'T9: row2 record_id preserved');
% arXiv row appended last
assert(T_merged9.source_dataset(3) == "arxiv",    'T9: 3rd row source_dataset must be arxiv');
assert(T_merged9.record_id(3) == "arxiv:2301.11", 'T9: 3rd row must be the surviving arXiv record');
assert(isnan(T_merged9.cited_by_count(3)),         'T9: arXiv row cited_by_count must be NaN');
% matlab_mentioned must be consistently double across all rows after cast
assert(isa(T_merged9.matlab_mentioned, 'double'), 'T9: merged matlab_mentioned must be double throughout');
assert(T_merged9.matlab_mentioned(3) == 0.0,      'T9: arXiv row matlab_mentioned kept (false->0.0)');
fprintf(' PASS\n'); passCount = passCount + 1;

fprintf('\n=== test_arxiv_smoke: %d/6 (network-free tests) PASSED ===\n', passCount);
end

% ─── Local helper ─────────────────────────────────────────────────────────────

function T = local_mock_arxiv_table()
% Returns a 2-row mock table matching fetch_arxiv_works output schema.
% Row 1: full data
%   - DOI with uppercase + trailing space (verifies normalization is applied to
%     doi_normalized only; raw doi is preserved)
%   - multi-author with affiliations
%   - MATLAB in abstract (matlab_mentioned should be true)
%   - journal_ref present (source_name = journal_ref, not "preprint")
% Row 2: minimal data
%   - no DOI, no journal_ref (source_name = "preprint")
%   - single author, no affiliation (last_author = first_author)
%   - empty abstract (matlab_mentioned = false)
T = table( ...
    ["2301.00001"; "2301.00002"], ...
    ["Deep Learning for NLP"; "Quantum Computing Survey"], ...
    ["We propose a new MATLAB-based method for NLP."; ""], ...
    ["2023-01-15T00:00:00Z"; "2022-06-01T00:00:00Z"], ...
    ["10.1000/TestDOI.001 "; ""], ...
    ["https://arxiv.org/pdf/2301.00001"; "https://arxiv.org/pdf/2301.00002"], ...
    ["cs.CL"; "quant-ph"], ...
    ["Nature 2023"; ""], ...
    ["Alice Wang; Bob Smith"; "Carol Lee"], ...
    ["MIT; Stanford"; ""], ...
    'VariableNames', {'arxiv_id','title','abstract','published','doi','pdf_url', ...
        'primary_category','journal_ref','authors','affiliations'} ...
    );
end
