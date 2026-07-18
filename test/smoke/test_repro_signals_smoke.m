function test_repro_signals_smoke()
%TEST_REPRO_SIGNALS_SMOKE  K-3 repro signal detection smoke test
%
%   addpath("src/adapters"); addpath("src/config"); addpath("test/smoke");
%   test_repro_signals_smoke();

fprintf('\n=== test_repro_signals_smoke ===\n');

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'adapters'));
addpath(fullfile(projectRoot, 'src', 'config'));

tmpDir = fullfile(tempdir, 'smoke_repro_signals');
if isfolder(tmpDir)
    rmdir(tmpDir, 's');
end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

%% Case 1: default dictionary hits all major categories
titles1 = ["DeepChem benchmark on ESOL"];
abstracts1 = ["Code available at github.com using PyTorch with RMSE evaluation."];
r1 = detect_repro_signals(titles1, abstracts1);
assert(r1.mentions_dataset(1) == true,  'Case1: mentions_dataset expected true');
assert(r1.mentions_code(1) == true,     'Case1: mentions_code expected true');
assert(r1.mentions_library(1) == true,  'Case1: mentions_library expected true');
assert(r1.mentions_metrics(1) == true,  'Case1: mentions_metrics expected true');
assert(r1.repro_signal_score(1) == 4,   'Case1: repro_signal_score expected 4');
fprintf('[PASS] Case1: default dictionary detection\n');

%% Case 2: MATLAB mention remains separate and integrated
titles2 = ["MATLAB workflow for molecular analysis"];
abstracts2 = ["A practical tutorial."];
r2 = detect_repro_signals(titles2, abstracts2);
assert(r2.matlab_mentioned(1) == true, 'Case2: matlab_mentioned expected true');
assert(r2.mentions_library(1) == true, 'Case2: mentions_library expected true via MATLAB term');
fprintf('[PASS] Case2: MATLAB integration\n');

%% Case 3: custom JSON overrides default terms
customPath = fullfile(tmpDir, 'repro_signals.json');
customJson = [
    '{', newline, ...
    '  "mentions_dataset": ["CustomSet"],', newline, ...
    '  "mentions_code": ["gitlab.com"],', newline, ...
    '  "mentions_library": ["Julia"],', newline, ...
    '  "mentions_metrics": ["F1-score"],', newline, ...
    '  "matlab_terms": ["Simulink"]', newline, ...
    '}'];
fid = fopen(customPath, 'w', 'n', 'UTF-8');
assert(fid >= 0, 'Case3: failed to open custom repro_signals.json');
fwrite(fid, customJson, 'char');
fclose(fid);

r3 = detect_repro_signals( ...
    "CustomSet benchmark in Simulink", ...
    "Results on gitlab.com use Julia and F1-score.", ...
    ConfigPath=customPath);
assert(r3.mentions_dataset(1) == true,  'Case3: custom dataset term not applied');
assert(r3.mentions_code(1) == true,     'Case3: custom code term not applied');
assert(r3.mentions_library(1) == true,  'Case3: custom library term not applied');
assert(r3.mentions_metrics(1) == true,  'Case3: custom metrics term not applied');
assert(r3.matlab_mentioned(1) == true,  'Case3: custom matlab_terms not applied');
assert(r3.repro_signal_score(1) == 4,   'Case3: custom repro_signal_score expected 4');
fprintf('[PASS] Case3: custom JSON override\n');

%% Case 4: adapter-level config override propagates through normalized works
src4 = table( ...
    "Wcustom", ...
    "CustomSet benchmark in Simulink", ...
    "Results on gitlab.com use Julia and F1-score.", ...
    'VariableNames', ["openalex_id", "title", "abstract"]);
r4 = openalex_to_normalized_works(src4, StrictValidation=false, ReproSignalsConfigPath=customPath);
assert(r4.mentions_dataset(1) == true,  'Case4: adapter did not apply custom dataset term');
assert(r4.mentions_code(1) == true,     'Case4: adapter did not apply custom code term');
assert(r4.mentions_library(1) == true,  'Case4: adapter did not apply custom library term');
assert(r4.mentions_metrics(1) == true,  'Case4: adapter did not apply custom metrics term');
assert(r4.matlab_mentioned(1) == true,  'Case4: adapter did not apply custom matlab term');
assert(r4.repro_signal_score(1) == 4,   'Case4: adapter repro_signal_score expected 4');
fprintf('[PASS] Case4: adapter-level custom config override\n');

fprintf('\n=== test_repro_signals_smoke: ALL PASS ===\n');
end
