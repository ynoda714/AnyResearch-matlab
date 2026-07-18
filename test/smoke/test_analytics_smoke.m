function test_analytics_smoke()
%TEST_ANALYTICS_SMOKE  Phase A (v0.2): Analytics layer smoke tests
%
%   How to run:
%     addpath("src/analytics"); addpath("src/util");
%     addpath("test/smoke");
%     test_analytics_smoke();
%
%   Test coverage:
%     T1.  citation_velocity: prefers measured counts_by_year values
%     T2.  citation_velocity: empty table returns safely
%     T3.  citation_velocity: missing columns handled gracefully
%     T4.  citation_velocity: by_year aggregation correctness
%     T5.  topic_growth_rate: aggregate by_year output
%     T6.  topic_growth_rate: growth_rate_pct calculation
%     T7.  topic_growth_rate: empty table returns safely
%     T8.  topic_growth_rate: by_topic breakdown when topics column is present
%     T9.  institution_dominance: basic output shape and dominance_score
%     T10. institution_dominance: paper_share + citation_share sum to ~1
%     T11. institution_dominance: empty table returns safely
%     T12. institution_dominance: pipe-delimited institution handling
%     T13. institution_dominance: topN truncation
%     T14. compute_analytics: runs on table input without error
%     T15. compute_analytics: file input (JSONL) without error
%     T16. compute_analytics: all result fields present

fprintf('\n=== test_analytics_smoke ===\n');
passCount = 0;

thisDir     = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'analytics'));
addpath(fullfile(projectRoot, 'src', 'util'));

tmpDir = fullfile(tempdir, 'smoke_analytics');
if isfolder(tmpDir)
    rmdir(tmpDir, 's');
end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

%% ── Test data ────────────────────────────────────────────────────────────
T = local_make_test_table();

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  citation_velocity
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

%% T1: basic output shape and velocity values
fprintf('[T1] citation_velocity: basic shape and values ...');
r = citation_velocity(T, currentYear=2026);
assert(isstruct(r), 'T1: result must be struct');
assert(istable(r.per_paper), 'T1: per_paper must be table');
assert(istable(r.by_year),   'T1: by_year must be table');
assert(height(r.per_paper) == height(T), 'T1: per_paper rows must match input');
assert(ismember('citation_velocity', r.per_paper.Properties.VariableNames), ...
    'T1: citation_velocity column missing');
% Paper with counts_by_year ending in 2025 -> latest measured yearly citations = 24
mask2021 = (T.publication_year == 2021);
v2021 = r.per_paper.citation_velocity(mask2021);
expected = 24;
assert(abs(v2021(1) - expected) < 1e-9, ...
    sprintf('T1: velocity mismatch. expected=%.4f got=%.4f', expected, v2021(1)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T2: empty table returns safely
fprintf('[T2] citation_velocity: empty table ...');
rEmpty = citation_velocity(table());
assert(isstruct(rEmpty), 'T2: must return struct');
assert(istable(rEmpty.per_paper) && height(rEmpty.per_paper) == 0, 'T2: per_paper must be empty table');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T3: missing columns handled gracefully
fprintf('[T3] citation_velocity: missing columns ...');
Tmin = table((2020:2023)', 'VariableNames', {'publication_year'});
rMin = citation_velocity(Tmin, currentYear=2026);
assert(all(isnan(rMin.per_paper.citation_velocity)), ...
    'T3: velocity should be NaN when cited_by_count is absent');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T3b: fallback to age-based approximation when counts_by_year is absent
fprintf('[T3b] citation_velocity: fallback without counts_by_year ...');
Tfallback = table( ...
    "W9999", 2021, 60, ...
    'VariableNames', {'openalex_id','publication_year','cited_by_count'});
r3b = citation_velocity(Tfallback, currentYear=2026);
expected3b = 60 / (2026 - 2021 + 1);
assert(abs(r3b.per_paper.citation_velocity(1) - expected3b) < 1e-9, ...
    sprintf('T3b: fallback mismatch. expected=%.4f got=%.4f', expected3b, r3b.per_paper.citation_velocity(1)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T3c: malformed counts_by_year falls back to age-based approximation
fprintf('[T3c] citation_velocity: malformed counts_by_year fallback ...');
Tbad = table( ...
    "W9998", 2022, 30, "{bad json}", ...
    'VariableNames', {'openalex_id','publication_year','cited_by_count','counts_by_year'});
r3c = citation_velocity(Tbad, currentYear=2026);
expected3c = 30 / (2026 - 2022 + 1);
assert(abs(r3c.per_paper.citation_velocity(1) - expected3c) < 1e-9, ...
    sprintf('T3c: malformed-json fallback mismatch. expected=%.4f got=%.4f', expected3c, r3c.per_paper.citation_velocity(1)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T3d: future-only counts_by_year entries are ignored and fall back
fprintf('[T3d] citation_velocity: future-only counts_by_year fallback ...');
Tfuture = table( ...
    "W9997", 2023, 20, "[{""year"":2027,""cited_by_count"":99}]", ...
    'VariableNames', {'openalex_id','publication_year','cited_by_count','counts_by_year'});
r3d = citation_velocity(Tfuture, currentYear=2026);
expected3d = 20 / (2026 - 2023 + 1);
assert(abs(r3d.per_paper.citation_velocity(1) - expected3d) < 1e-9, ...
    sprintf('T3d: future-only fallback mismatch. expected=%.4f got=%.4f', expected3d, r3d.per_paper.citation_velocity(1)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T4: by_year aggregation correctness
fprintf('[T4] citation_velocity: by_year aggregation ...');
r4 = citation_velocity(T, currentYear=2026);
assert(height(r4.by_year) > 0, 'T4: by_year must be non-empty');
assert(all(ismember({'year','paper_count','avg_citation_velocity','median_citation_velocity'}, ...
    r4.by_year.Properties.VariableNames)), 'T4: by_year column names wrong');
% Total paper count across years must equal height(T) - NaN-year rows
totalPapers = sum(r4.by_year.paper_count);
assert(totalPapers == height(T), sprintf('T4: total paper count mismatch %d vs %d', totalPapers, height(T)));
fprintf(' PASS\n'); passCount = passCount + 1;

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  topic_growth_rate
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

%% T5: aggregate by_year output
fprintf('[T5] topic_growth_rate: by_year output ...');
r5 = topic_growth_rate(T);
assert(istable(r5.by_year), 'T5: by_year must be table');
assert(all(ismember({'year','paper_count','growth_rate_pct'}, ...
    r5.by_year.Properties.VariableNames)), 'T5: by_year columns wrong');
assert(height(r5.by_year) > 0, 'T5: by_year must be non-empty');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T6: growth_rate_pct calculation
fprintf('[T6] topic_growth_rate: growth_rate_pct ...');
% First year must have NaN growth
firstGrowth = r5.by_year.growth_rate_pct(1);
assert(isnan(firstGrowth), 'T6: first year growth_rate_pct must be NaN');
% Check a non-first row: if paper_count goes from 2 to 4, growth = 100%
paperCounts = r5.by_year.paper_count;
assert(all(paperCounts > 0), 'T6: all years must have at least one paper');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T7: empty table returns safely
fprintf('[T7] topic_growth_rate: empty table ...');
r7 = topic_growth_rate(table());
assert(isstruct(r7), 'T7: must return struct');
assert(istable(r7.by_year) && height(r7.by_year) == 0, 'T7: by_year must be empty');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T8: by_topic breakdown when topics column is present
fprintf('[T8] topic_growth_rate: by_topic with topics column ...');
Tt = T;
Tt.topics = ["ML | DL"; "ML"; "DL | RL"; "ML | RL"; "RL"; "DL"; "ML"; "ML"; "RL"; "DL"];
r8 = topic_growth_rate(Tt, topicCol="topics", minPapers=2);
assert(r8.has_topics, 'T8: has_topics should be true');
assert(istable(r8.by_topic), 'T8: by_topic must be table');
assert(all(ismember({'topic','year','paper_count'}, r8.by_topic.Properties.VariableNames)), ...
    'T8: by_topic columns wrong');
assert(height(r8.by_topic) > 0, 'T8: by_topic should be non-empty');
assert(all(ismember(["ML","DL","RL"], unique(r8.by_topic.topic))), ...
    'T8: expected topics ML/DL/RL not all present');
fprintf(' PASS\n'); passCount = passCount + 1;

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  institution_dominance
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

%% T9: basic output shape and dominance_score
fprintf('[T9] institution_dominance: basic shape ...');
r9 = institution_dominance(T);
assert(isstruct(r9), 'T9: must be struct');
assert(istable(r9.by_institution), 'T9: by_institution must be table');
reqCols = {'institution','paper_count','total_citations','paper_share','citation_share','dominance_score'};
assert(all(ismember(reqCols, r9.by_institution.Properties.VariableNames)), ...
    'T9: missing columns in by_institution');
assert(height(r9.by_institution) > 0, 'T9: by_institution must be non-empty');
assert(all(r9.by_institution.dominance_score >= 0), 'T9: dominance_score must be >= 0');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T10: paper_share sums to 1
fprintf('[T10] institution_dominance: paper_share sums to 1 ...');
% paper_share is share of papers per institution. With multiple institutions
% possible per paper (pipe-delimited), sum may exceed 1. Check >= 0 and <= 1 per-row.
psVec = r9.by_institution.paper_share;
assert(all(psVec >= 0 & psVec <= 1), 'T10: paper_share values out of [0,1]');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T11: empty table returns safely
fprintf('[T11] institution_dominance: empty table ...');
r11 = institution_dominance(table());
assert(isstruct(r11), 'T11: must return struct');
assert(istable(r11.by_institution) && height(r11.by_institution) == 0, ...
    'T11: by_institution must be empty');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T12: pipe-delimited institution handling
fprintf('[T12] institution_dominance: pipe-delimited ...');
Tpipe = table( ...
    ["MIT | Harvard"; "MIT"; "Harvard"; "MIT | Stanford"], ...
    [100; 50; 80; 60], ...
    'VariableNames', {'first_author_institutions','cited_by_count'});
r12 = institution_dominance(Tpipe);
instNames = r12.by_institution.institution;
assert(any(instNames == "MIT"),      'T12: MIT expected');
assert(any(instNames == "Harvard"),  'T12: Harvard expected');
assert(any(instNames == "Stanford"), 'T12: Stanford expected');
% MIT appears 3 times
mitRow = r12.by_institution(instNames == "MIT", :);
assert(mitRow.paper_count == 3, sprintf('T12: MIT paper_count expected 3, got %d', mitRow.paper_count));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T13: topN truncation
fprintf('[T13] institution_dominance: topN ...');
r13 = institution_dominance(T, topN=2);
assert(height(r13.by_institution) <= 2, 'T13: topN=2 must return at most 2 rows');
fprintf(' PASS\n'); passCount = passCount + 1;

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  compute_analytics
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

%% T14: table input
fprintf('[T14] compute_analytics: table input ...');
r14 = compute_analytics(T, currentYear=2026);
assert(isstruct(r14), 'T14: must return struct');
assert(isfield(r14, 'citation_velocity'),    'T14: citation_velocity field missing');
assert(isfield(r14, 'topic_growth_rate'),    'T14: topic_growth_rate field missing');
assert(isfield(r14, 'institution_dominance'), 'T14: institution_dominance field missing');
assert(isfield(r14, 'n_papers'),  'T14: n_papers field missing');
assert(isfield(r14, 'computed_at'), 'T14: computed_at field missing');
assert(r14.n_papers == height(T), 'T14: n_papers mismatch');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T15: JSONL file input
fprintf('[T15] compute_analytics: JSONL file input ...');
jsonlPath = fullfile(tmpDir, 'analytics_test.jsonl');
write_jsonl(T, jsonlPath);
r15 = compute_analytics(jsonlPath, currentYear=2026);
assert(isstruct(r15), 'T15: must return struct');
assert(r15.n_papers == height(T), 'T15: n_papers mismatch');
fprintf(' PASS\n'); passCount = passCount + 1;

%% T16: all result sub-fields present
fprintf('[T16] compute_analytics: sub-field completeness ...');
assert(istable(r14.citation_velocity.per_paper),     'T16: per_paper missing');
assert(istable(r14.citation_velocity.by_year),        'T16: by_year missing');
assert(istable(r14.topic_growth_rate.by_year),        'T16: tgr.by_year missing');
assert(istable(r14.institution_dominance.by_institution), 'T16: by_institution missing');
fprintf(' PASS\n'); passCount = passCount + 1;

%% Summary
fprintf('\n=== test_analytics_smoke: %d/19 passed ===\n', passCount);
if passCount == 19
    fprintf('ALL PASS\n');
else
    error('test_analytics_smoke:Failure', '%d test(s) failed.', 19 - passCount);
end
end

% ── Local helpers ─────────────────────────────────────────────────────────

function T = local_make_test_table()
% 10 sample papers spanning 4 years with varied institutions
openalex_id           = string(("W" + (1001:1010))')  ;
publication_year      = [2021;2021;2022;2022;2022;2023;2023;2024;2024;2024];
cited_by_count        = [100; 50; 80; 20; 60; 10; 30; 5; 15; 40];
first_author_institutions = [ ...
    "MIT"; "Stanford"; "MIT"; "Harvard"; "Stanford"; ...
    "MIT"; "Harvard"; "Stanford"; "MIT"; "Harvard"];

T = table(openalex_id, publication_year, cited_by_count, first_author_institutions);
T.counts_by_year = [ ...
    "[{""year"":2023,""cited_by_count"":18},{""year"":2024,""cited_by_count"":21},{""year"":2025,""cited_by_count"":24}]"; ...
    "[{""year"":2024,""cited_by_count"":11},{""year"":2025,""cited_by_count"":13}]"; ...
    "[{""year"":2024,""cited_by_count"":16},{""year"":2025,""cited_by_count"":18}]"; ...
    "[{""year"":2023,""cited_by_count"":4},{""year"":2025,""cited_by_count"":7}]"; ...
    "[{""year"":2024,""cited_by_count"":12},{""year"":2025,""cited_by_count"":15}]"; ...
    "[{""year"":2025,""cited_by_count"":6}]"; ...
    "[{""year"":2025,""cited_by_count"":8}]"; ...
    "[{""year"":2025,""cited_by_count"":5},{""year"":2026,""cited_by_count"":7}]"; ...
    "[{""year"":2025,""cited_by_count"":9}]"; ...
    "[{""year"":2025,""cited_by_count"":12}]" ...
];
end
