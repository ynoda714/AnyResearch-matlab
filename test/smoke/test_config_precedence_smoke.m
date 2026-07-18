function test_config_precedence_smoke()
addpath("src/config");

tmpDir   = fullfile(tempdir, 'smoke_config_precedence');
if ~isfolder(tmpDir); mkdir(tmpDir); end
cleanup  = onCleanup(@() rmdir(tmpDir, 's'));   % auto-delete directory on cleanup
envClean = onCleanup(@() local_clear_env());     % clear env even on exception

jsonPath = fullfile(tmpDir, 'test_settings.json');

% Create test JSON settings file
fid = fopen(jsonPath, 'w', 'n', 'UTF-8');
fprintf(fid, '{\n');
fprintf(fid, '  "openalex": { "per_page": 50, "api_key": "from_json" },\n');
fprintf(fid, '  "search":   { "query": "from_json_query" }\n');
fprintf(fid, '}\n');
fclose(fid);

% Override openalex.api_key via environment variable
setenv('ANYRESEARCH_OPENALEX_API_KEY', 'from_env_key');
setenv('ANYRESEARCH_OPENALEX_PER_PAGE', '75');

cfg = load_runtime_config(jsonPath);

% Verify that env vars take precedence over JSON
assert(string(cfg.openalex.api_key) == "from_env_key", ...
    "api_key: env should override JSON");
assert(cfg.openalex.per_page == 75, ...
    "per_page: env should override JSON");
% Verify that JSON values override defaults
assert(string(cfg.search.query) == "from_json_query", ...
    "query: JSON should override default");

setenv('ANYRESEARCH_OPENALEX_API_KEY', '');
setenv('ANYRESEARCH_OPENALEX_PER_PAGE', '');

% Verify that default values are used when a non-existent path is given
cfg2 = load_runtime_config("non_existing.json");
assert(cfg2.openalex.per_page == 100, ...
    "per_page default should be 100");
assert(string(cfg2.openalex.api_key) == "", ...
    "api_key default should be empty string");

fprintf("Smoke test passed: config precedence env > json > default\n");
end

function local_clear_env()
    setenv('ANYRESEARCH_OPENALEX_API_KEY', '');
    setenv('ANYRESEARCH_OPENALEX_PER_PAGE', '');
end
