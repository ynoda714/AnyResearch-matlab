function test_abstract_highlight_smoke()
%TEST_ABSTRACT_HIGHLIGHT_SMOKE  L0-6: abstract keyword highlight smoke test
%
%   How to run:
%     addpath("src/export"); addpath("src/util");
%     addpath("test/smoke");
%     test_abstract_highlight_smoke();
%
%   Target: excel_write_overview / excel_write_detail
%               local_highlight_keywords (cfg.query -> wrap with [keyword])
%
%   Test coverage:
%     T1.  Single keyword -> [word] appears in abstract (Overview)
%     T2.  AND search (space-separated) -> highlight multiple keywords
%     T3.  OR search (| separated) -> highlight both
%     T4.  Phrase search (with quotes) -> highlight after removing quotes
%     T5.  Case-insensitive ("Energy" query matches "energy")
%     T6.  cfg.query is empty -> no highlight
%     T7.  abstract column absent -> no error (remains empty string)
%     T8.  Same highlight is applied in the Detail sheet
%     T9.  abstract over 500 chars -> truncate to first 500 chars + "..." then highlight
%     T10. Keyword not in abstract -> no change

fprintf('\n=== test_abstract_highlight_smoke (L0-6) ===\n');
passCount = 0;

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'export'));
addpath(fullfile(projectRoot, 'src', 'util'));

%% T1: Single keyword -> [word] appears in abstract (Overview)
fprintf('[T1] 単一キーワードハイライト (Overview) ...');
T1 = local_make_table('This paper is about renewable energy and solar power.');
cfg1 = struct('query', 'renewable');
spec1 = excel_write_overview(T1, cfg1);
absIdx = 11;  % Overview abstract 列 = 11列目
absVal = char(string(spec1.data{1, absIdx}));
assert(contains(absVal, '【renewable】') || contains(absVal, '【Renewable】'), ...
    sprintf('T1: ハイライトなし: "%s"', absVal));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T2: AND search (space-separated) -> multiple highlights
fprintf('[T2] AND 検索 複数キーワード ...');
T2 = local_make_table('Deep learning and neural networks are used for image classification.');
cfg2 = struct('query', 'deep learning neural');
spec2 = excel_write_overview(T2, cfg2);
absVal2 = char(string(spec2.data{1, 11}));
% Verify each keyword is highlighted individually (case-insensitive)
absLower2 = lower(absVal2);
assert(contains(absLower2, [char(12304) 'deep' char(12305)]), ...
    sprintf('T2: "deep" がハイライトされない: "%s"', absVal2));
assert(contains(absLower2, [char(12304) 'learning' char(12305)]), ...
    sprintf('T2: "learning" がハイライトされない: "%s"', absVal2));
assert(contains(absLower2, [char(12304) 'neural' char(12305)]), ...
    sprintf('T2: "neural" がハイライトされない: "%s"', absVal2));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T3: OR search (| separated) -> highlight both
fprintf('[T3] OR 検索 両方ハイライト ...');
T3 = local_make_table('Solar energy and wind power are renewable resources.');
cfg3 = struct('query', 'solar|wind');
spec3 = excel_write_overview(T3, cfg3);
absVal3 = char(string(spec3.data{1, 11}));
assert(contains(absVal3, '【solar】') || contains(absVal3, '【Solar】'), ...
    sprintf('T3a: solar ハイライトなし: "%s"', absVal3));
assert(contains(absVal3, '【wind】') || contains(absVal3, '【Wind】'), ...
    sprintf('T3b: wind ハイライトなし: "%s"', absVal3));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T4: Phrase search (with quotes) -> highlight after removing quotes
fprintf('[T4] フレーズ検索（引用符除去後にハイライト） ...');
T4 = local_make_table('Machine learning is applied to climate prediction models.');
cfg4 = struct('query', '"machine learning"');
spec4 = excel_write_overview(T4, cfg4);
absVal4 = char(string(spec4.data{1, 11}));
% Quotes removed; "machine" and "learning" each highlighted (case-insensitive)
absLower4 = lower(absVal4);
assert(contains(absLower4, [char(12304) 'machine' char(12305)]), ...
    sprintf('T4: "machine" がハイライトされない: "%s"', absVal4));
assert(contains(absLower4, [char(12304) 'learning' char(12305)]), ...
    sprintf('T4: "learning" がハイライトされない: "%s"', absVal4));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T5: Case-insensitive matching
fprintf('[T5] 大文字小文字非区別 ...');
T5 = local_make_table('This study analyzes Energy consumption in buildings.');
cfg5 = struct('query', 'energy');
spec5 = excel_write_overview(T5, cfg5);
absVal5 = char(string(spec5.data{1, 11}));
assert(contains(absVal5, '【Energy】') || contains(absVal5, '【energy】'), ...
    sprintf('T5: 大文字 Energy がハイライトされない: "%s"', absVal5));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T6: cfg.query is empty -> no highlight
fprintf('[T6] query 空 → ハイライトなし ...');
T6 = local_make_table('Renewable energy study using solar panels.');
cfg6 = struct('query', '');
spec6 = excel_write_overview(T6, cfg6);
absVal6 = char(string(spec6.data{1, 11}));
assert(~contains(absVal6, '【'), ...
    sprintf('T6: query 空でもハイライトが入ってしまった: "%s"', absVal6));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T7: abstract column absent -> no error (remains empty string)
fprintf('[T7] abstract 列不在 → エラーなし ...');
T7 = table(string("Test Title"), string("10.1000/abc"), ...
    'VariableNames', {'title', 'doi'});
cfg7 = struct('query', 'renewable');
try
    spec7 = excel_write_overview(T7, cfg7);
    absVal7 = char(string(spec7.data{1, 11}));
    assert(isempty(absVal7), sprintf('T7: abstract 不在なのに値あり: "%s"', absVal7));
    fprintf(' PASS\n'); passCount = passCount + 1;
catch ex
    fprintf(' FAIL: エラーが発生: %s\n', ex.message);
end

%% T8: Same highlight is applied in the Detail sheet
fprintf('[T8] Detail シートでのハイライト ...');
T8 = local_make_table('Quantum computing accelerates optimization algorithms.');
cfg8 = struct('query', 'quantum computing');
spec8 = excel_write_detail(T8, cfg8);
absIdx8 = 8;  % Detail の abstract も 8列目
absVal8 = char(string(spec8.data{1, absIdx8}));
% "quantum" and "computing" each highlighted individually (case-insensitive)
absLower8 = lower(absVal8);
assert(contains(absLower8, [char(12304) 'quantum' char(12305)]), ...
    sprintf('T8: "quantum" がハイライトされない: "%s"', absVal8));
assert(contains(absLower8, [char(12304) 'computing' char(12305)]), ...
    sprintf('T8: "computing" がハイライトされない: "%s"', absVal8));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T9: abstract over 500 chars -> truncate to 500 chars + "..." + highlight
fprintf('[T9] 500 字超抄録の打ち切り + ハイライト ...');
longAbs = [repmat('x', 1, 480), ' solar energy and renewable power ', repmat('z', 1, 100)];
T9 = local_make_table(longAbs);
cfg9 = struct('query', 'solar');
spec9 = excel_write_overview(T9, cfg9);
absVal9 = char(string(spec9.data{1, 11}));
% "..." is included after truncation
assert(endsWith(absVal9, '...'), ...
    sprintf('T9: 打ち切り "..." がない。末尾: "%s"', absVal9(max(1,end-5):end)));
% "solar" is within the first 500 chars, so it is highlighted even after truncation
% (longAbs: 480x + ' solar energy...' -> 500th char is mid-'renewable' -> 'solar' is at chars 481-486, definitely included)
assert(contains(absVal9, char(12304)), ...
    'T9: 500字以内の "solar" がハイライトされていない');
% Length: 500 + "..."(3) + [] overhead ("solar" 5->9, +4) = 507 chars
assert(length(absVal9) >= 503 && length(absVal9) <= 515, ...
    sprintf('T9: 長さ=%d 字 (expected 503〜515)', length(absVal9)));
fprintf(' PASS\n'); passCount = passCount + 1;

%% T10: Keyword not in abstract -> no change
fprintf('[T10] キーワード不一致 → 変化なし ...');
T10 = local_make_table('This paper studies gravitational waves in astrophysics.');
cfg10 = struct('query', 'renewable energy');
spec10 = excel_write_overview(T10, cfg10);
absVal10 = char(string(spec10.data{1, 11}));
assert(~contains(absVal10, '【'), ...
    sprintf('T10: 不一致なのにハイライトが入った: "%s"', absVal10));
fprintf(' PASS\n'); passCount = passCount + 1;

fprintf('\n[DONE] test_abstract_highlight_smoke: %d/10 PASS\n', passCount);
if passCount == 10
    fprintf('=== ALL PASS ===\n');
else
    error('test_abstract_highlight_smoke: %d/10 のみ PASS\n', passCount);
end
end

% ─── Local helpers ────────────────────────────────────────────────────

function T = local_make_table(abstractText)
%LOCAL_MAKE_TABLE  Create a 1-row test table
T = table( ...
    string("Test Title"), ...
    string("10.1000/test001"), ...
    int32(2024), ...
    int32(10), ...
    true, ...
    string("Journal of Testing"), ...
    string("article"), ...
    string(abstractText), ...
    'VariableNames', {'title','doi','publication_year','cited_by_count', ...
                      'is_oa','source_name','type','abstract'});
end
