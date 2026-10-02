function test_no_api_key_error_smoke()
%TEST_NO_API_KEY_ERROR_SMOKE  Missing API key must raise run_pipeline:NoApiKey with a readable message.
%
%   Regression: the message was built with char + char, which failed with
%   MATLAB:sizeDimensionsMustMatch ("array sizes are not compatible") instead.

thisDir = fileparts(mfilename('fullpath'));
root = fullfile(thisDir, '..', '..');
addpath(fullfile(root, 'src', 'pipeline'));

settingsPath = fullfile(root, 'config', 'settings.json');
if isfile(settingsPath)
    fprintf("[SKIP] test_no_api_key_error_smoke: config/settings.json exists (cannot simulate a missing key)\n");
    return;
end

origKey = getenv('ANYRESEARCH_OPENALEX_API_KEY');
restoreEnv = onCleanup(@() setenv('ANYRESEARCH_OPENALEX_API_KEY', origKey));
setenv('ANYRESEARCH_OPENALEX_API_KEY', '');

runDir = fullfile(tempdir, 'smoke_no_api_key');
try
    run_pipeline("test", "2025-01-01", "2025-01-02", showCountPreview=false, runRootDir=runDir);
    error('test_no_api_key:NoError', 'expected run_pipeline:NoApiKey');
catch ex
    assert(strcmp(ex.identifier, 'run_pipeline:NoApiKey'), ...
        'unexpected error %s: %s', ex.identifier, ex.message);
    assert(contains(string(ex.message), "ANYRESEARCH_OPENALEX_API_KEY"), ...
        'message must tell how to configure the key: %s', ex.message);
end
fprintf("[PASS] test_no_api_key_error_smoke: readable NoApiKey message\n");
end
