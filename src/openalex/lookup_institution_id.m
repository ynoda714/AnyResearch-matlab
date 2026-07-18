function results = lookup_institution_id(nameQuery, options)
%LOOKUP_INSTITUTION_ID  Searches for OpenAlex institution IDs by institution name.
%
%   Uses the OpenAlex institutions API to search by institution name and display
%   a list of candidates in the Command Window. Utility for building institutions.csv.
%
%   Usage:
%     lookup_institution_id("Nagoya University")
%     lookup_institution_id("Tokyo", maxResults=20)
%     results = lookup_institution_id("Fujita")
%
%   [Required arguments]
%     nameQuery : Institution name to search (partial match; OpenAlex full-text search)
%
%   [Name=Value options]
%     maxResults : Maximum results to return, 1-25 (default: 10)
%     timeoutSec : HTTP timeout in seconds (default: 15)
%
%   [Return value]
%     results — table: display_name / openalex_id / country_code / works_count / homepage_url
%               (when nargout == 0, display only)

arguments
    nameQuery          (1,1) string
    options.maxResults (1,1) double = 10
    options.timeoutSec (1,1) double = 15
end

if strlength(strtrim(nameQuery)) == 0
    error('lookup_institution_id:EmptyQuery', 'Institution name is required.');
end

% Path setup (for standalone invocation)
thisDir     = fileparts(mfilename('fullpath'));   % src/openalex/
srcDir      = fileparts(thisDir);                 % src/
projectRoot = fileparts(srcDir);                  % project root
if isfolder(fullfile(projectRoot, 'src', 'config'))
    addpath(fullfile(projectRoot, 'src', 'config'));
end
if isfolder(fullfile(projectRoot, 'src', 'util'))
    addpath(fullfile(projectRoot, 'src', 'util'));
end

% API Key retrieval (from settings file or environment variable)
apiKey = "";
try
    cfg = load_runtime_config(fullfile(projectRoot, 'config', 'settings.json'));
    if isfield(cfg, 'openalex') && isfield(cfg.openalex, 'api_key')
        apiKey = strtrim(string(cfg.openalex.api_key));
    end
catch
    % Continue without API Key (ignore errors)
end

% Build OpenAlex institutions search URL
perPage = min(max(round(options.maxResults), 1), 25);
urlStr  = "https://api.openalex.org/institutions" + ...
    "?search=" + string(urlencode(char(strtrim(nameQuery)))) + ...
    "&per-page=" + string(perPage) + ...
    "&select=id,display_name,country_code,works_count,homepage_url";
if strlength(apiKey) > 0
    urlStr = urlStr + "&api_key=" + apiKey;
end

% API call
try
    wopts = weboptions('Timeout', options.timeoutSec, 'ContentType', 'json');
    resp  = webread(char(urlStr), wopts);
catch ex
    error('lookup_institution_id:ApiError', ...
        'OpenAlex API call failed: %s', ex.message);
end

% Empty result
if ~isfield(resp, 'results') || isempty(resp.results)
    fprintf('\nNo results found for: "%s"\n\n', nameQuery);
    results = table( ...
        strings(0,1), strings(0,1), strings(0,1), zeros(0,1), strings(0,1), ...
        'VariableNames', {'display_name','openalex_id','country_code','works_count','homepage_url'});
    if nargout == 0; clear results; end
    return;
end

n = numel(resp.results);
displayNames = strings(n, 1);
oapIds       = strings(n, 1);
countryCodes = strings(n, 1);
worksCounts  = zeros(n, 1);
homepageUrls = strings(n, 1);

for i = 1:n
    item = resp.results(i);
    if isfield(item, 'display_name') && ~isempty(item.display_name)
        displayNames(i) = strtrim(string(item.display_name));
    end
    if isfield(item, 'id') && ~isempty(item.id)
        % "https://openalex.org/I12345" → "I12345"
        rawId = strtrim(string(item.id));
        parts = strsplit(rawId, '/');
        oapIds(i) = parts(end);
    end
    if isfield(item, 'country_code') && ~isempty(item.country_code)
        countryCodes(i) = strtrim(string(item.country_code));
    end
    if isfield(item, 'works_count') && ~isempty(item.works_count)
        worksCounts(i) = double(item.works_count);
    end
    if isfield(item, 'homepage_url') && ~isempty(item.homepage_url)
        homepageUrls(i) = strtrim(string(item.homepage_url));
    end
end

results = table(displayNames, oapIds, countryCodes, worksCounts, homepageUrls, ...
    'VariableNames', {'display_name','openalex_id','country_code','works_count','homepage_url'});

% ── Command window output ────────────────────────────────────────────────
line = repmat('-', 1, 95);
fprintf('\nInstitution ID search results for: "%s"  (%d results)\n', nameQuery, n);
fprintf('%-52s %-16s %-8s %12s\n', 'display_name', 'openalex_id', 'country', 'works_count');
fprintf('%s\n', line);
for i = 1:n
    nm = char(displayNames(i));
    if length(nm) > 50
        nm = [nm(1:47), '...'];
    end
    fprintf('%-52s %-16s %-8s %12d\n', nm, char(oapIds(i)), char(countryCodes(i)), worksCounts(i));
end
fprintf('%s\n', line);
fprintf('\nExample entry for institutions.csv:\n');
fprintf('  Account,openalex_institution_id\n');
for i = 1:min(n, 5)
    fprintf('  %s,%s\n', char(displayNames(i)), char(oapIds(i)));
end
fprintf('\n');

if nargout == 0
    clear results;
end
end
