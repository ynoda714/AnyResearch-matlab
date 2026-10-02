function test_api_key_masking_smoke()
%TEST_API_KEY_MASKING_SMOKE  API failures must not expose OpenAlex API keys.

thisDir = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'config'));
addpath(fullfile(projectRoot, 'src', 'openalex'));
addpath(fullfile(projectRoot, 'src', 'util'));

secret = "MASKTEST_KEY_0123456789";
previousKey = getenv('ANYRESEARCH_OPENALEX_API_KEY');
cleanup = onCleanup(@() setenv('ANYRESEARCH_OPENALEX_API_KEY', previousKey));
setenv('ANYRESEARCH_OPENALEX_API_KEY', secret);

fprintf('\n=== test_api_key_masking_smoke ===\n');

%% T1: Seed resolution rethrows a masked HTTP failure.
[seedEx, seedOutput] = local_capture_exception(@() resolve_openalex_seed_id( ...
    "W000000000000000", apiKey=secret, timeoutSec=20));
local_assert_masked_exception(seedEx, seedOutput, secret, 'T1');

%% T2: Referenced-work resolution masks its direct HTTP failure too.
[refEx, refOutput] = local_capture_exception(@() resolve_openalex_referenced_ids( ...
    "W000000000000000", apiKey=secret, timeoutSec=20));
local_assert_masked_exception(refEx, refOutput, secret, 'T2');

%% T3: Institution lookup masks the API error it wraps.
[lookupEx, lookupOutput] = local_capture_exception(@() lookup_institution_id( ...
    "MASKING_TEST_INSTITUTION", timeoutSec=20));
local_assert_masked_exception(lookupEx, lookupOutput, secret, 'T3');

%% T4: Candidate preparation masks its warning output for an API failure.
outputPath = fullfile(tempdir, 'test_api_key_masking_institutions.csv');
[prepared, prepareOutput] = local_capture_prepare(outputPath);
assert(prepared.status(1) == "api_error", 'T4: expected an api_error row from the invalid API key');
local_assert_masked_text(prepareOutput, secret, 'T4 command output');

%% T5: Institution-ID resolution does not attach an API key to its request.
idsOutput = evalc('resolve_institution_ids("MASKING TEST INSTITUTION", "", strings(0, 1), 20);');
local_assert_masked_text(idsOutput, secret, 'T5 command output');

%% T6: Rate-limit failures store a masked error message.
info = get_openalex_rate_limit_status(secret, 20);
assert(~info.ok, 'T6: expected the sentinel API key to be rejected');
local_assert_masked_text(string(info.error_message), secret, 'T6 error_message');

%% T7: the masking still works, and the real error is reported, when only src/openalex is on the
% path (a caller that did not add src/util must not get "Undefined function mask_api_key").
savedPath = path;
pathCleanup = onCleanup(@() path(savedPath)); %#ok<NASGU>
rmpath(fullfile(projectRoot, 'src', 'util'));
standalone = get_openalex_rate_limit_status(secret, 20);
assert(~standalone.ok && ~contains(string(standalone.error_message), "mask_api_key"), ...
    'T7: rate-limit status must report the HTTP failure, not a missing helper');
local_assert_masked_text(string(standalone.error_message), secret, 'T7 error_message');
[seedEx7, seedOut7] = local_capture_exception(@() resolve_openalex_seed_id( ...
    "W000000000000000", apiKey=secret, timeoutSec=20));
assert(~isempty(seedEx7) && ~strcmp(seedEx7.identifier, 'MATLAB:UndefinedFunction'), ...
    'T7: seed resolution must fail with the HTTP error, not an undefined helper');
local_assert_masked_exception(seedEx7, seedOut7, secret, 'T7');

fprintf('[PASS] test_api_key_masking_smoke: 7 cases\n');
end

function [captured, output] = local_capture_exception(fcn)
captured = MException.empty;
output = evalc('local_call');

    function local_call()
        try
            fcn();
        catch ex
            captured = ex;
        end
    end
end

function [prepared, output] = local_capture_prepare(outputPath)
prepared = table();
output = evalc('local_call');

    function local_call()
        [~, prepared] = prepare_institutions_csv( ...
            "MASKING_TEST_INSTITUTION", outputPath=outputPath, timeoutSec=20);
    end
end

function local_assert_masked_exception(ex, output, secret, label)
assert(~isempty(ex), '%s: expected an HTTP error', label);
local_assert_masked_text(string(ex.message), secret, label + " exception");
local_assert_masked_text(output, secret, label + " command output");
end

function local_assert_masked_text(text, secret, label)
assert(~contains(string(text), secret), '%s exposed the API key', label);
end
