function [outPath, outTable] = prepare_institutions_csv(nameList, options)
%PREPARE_INSTITUTIONS_CSV  Builds a reviewed institutions.csv from institution names.
%
%   Accepts a list of institution names (string array or text file path),
%   searches each institution via the OpenAlex API, and outputs a CSV that
%   can be used directly by main_run_batch.m after include review.
%
%   Usage:
%     prepare_institutions_csv(["Nagoya University", "Kyoto University"])
%     prepare_institutions_csv("my_universities.txt")
%     [outPath, T] = prepare_institutions_csv(names, countryFilter="JP")
%     prepare_institutions_csv(names, mergeWith="data/list/institutions.csv")
%
%   [Required arguments]
%     nameList       : String array of institution names, or path to a text file
%
%   [Name=Value options]
%     outputPath     : Output CSV path (default: "data/list/institutions_candidate.csv")
%     maxCandidates  : Maximum candidates per institution, 1-10 (default: 3)
%     countryFilter  : Filter candidates by country code, e.g. "JP" (default: "")
%     timeoutSec     : HTTP timeout in seconds (default: 15)
%     mergeWith      : Existing reviewed CSV path to merge with (default: "")
%
%   [Return values]
%     outPath        : Absolute path of the output CSV file (string)
%     outTable       : Output table written to CSV
%
%   [Output CSV columns]
%     account                : Reviewed account name
%     openalex_institution_id: OpenAlex institution ID (e.g. I46030298)
%     display_name           : Official institution name in OpenAlex
%     country_code           : Country code (e.g. JP)
%     works_count            : Registered paper count
%     include                : Review flag (1/0). New rows default to 0 in merge mode.
%     role                   : Optional role. Hospital-like names get a proposal.
%     note                   : Reviewer note / merge note
%     status                 : found / not_found / api_error

arguments
    nameList
    options.outputPath    (1,1) string = ""
    options.maxCandidates (1,1) double = 3
    options.countryFilter (1,1) string = ""
    options.timeoutSec    (1,1) double = 15
    options.mergeWith     (1,1) string = ""
end

thisDir = fileparts(mfilename('fullpath'));
srcDir = fileparts(thisDir);
projectRoot = fileparts(srcDir);
if isfolder(fullfile(projectRoot, 'src', 'config'))
    addpath(fullfile(projectRoot, 'src', 'config'));
end
if isfolder(fullfile(projectRoot, 'src', 'util'))
    addpath(fullfile(projectRoot, 'src', 'util'));
end

if strlength(strtrim(options.outputPath)) == 0
    outPath = string(fullfile(projectRoot, 'data', 'list', 'institutions_candidate.csv'));
else
    op = strtrim(options.outputPath);
    if local_is_absolute(op)
        outPath = op;
    else
        outPath = string(fullfile(projectRoot, char(op)));
    end
end

names = local_parse_name_list(nameList, projectRoot);
if isempty(names)
    error('prepare_institutions_csv:EmptyList', 'Institution name list is empty.');
end
nNames = numel(names);

apiKey = load_openalex_api_key(fullfile(projectRoot, 'config', 'settings.json'), true);

maxCand = min(max(round(options.maxCandidates), 1), 10);
perPage = min(maxCand * 3, 25);
wopts = weboptions('Timeout', options.timeoutSec, 'ContentType', 'json');

rowAccount = strings(0, 1);
rowId = strings(0, 1);
rowDispName = strings(0, 1);
rowCountry = strings(0, 1);
rowWorks = zeros(0, 1);
rowInclude = zeros(0, 1);
rowRole = strings(0, 1);
rowNote = strings(0, 1);
rowStatus = strings(0, 1);

log_info('prepare_institutions_csv: searching %d institutions', nNames);

for k = 1:nNames
    nm = strtrim(names(k));
    if strlength(nm) == 0
        continue;
    end
    log_progress(k, nNames, nm);

    urlStr = "https://api.openalex.org/institutions" + ...
        "?search=" + string(urlencode(char(nm))) + ...
        "&per-page=" + string(perPage) + ...
        "&select=id,display_name,country_code,works_count";
    if strlength(apiKey) > 0
        urlStr = urlStr + "&api_key=" + apiKey;
    end

    try
        resp = webread(char(urlStr), wopts);
    catch ex
        log_warn('API error for "%s": %s', nm, ex.message);
        [rowAccount, rowId, rowDispName, rowCountry, rowWorks, rowInclude, rowRole, rowNote, rowStatus] = ...
            local_append_row(rowAccount, rowId, rowDispName, rowCountry, rowWorks, ...
            rowInclude, rowRole, rowNote, rowStatus, nm, "", "", "", 0, 0, "", "", "api_error");
        continue;
    end

    if ~isfield(resp, 'results') || isempty(resp.results)
        [rowAccount, rowId, rowDispName, rowCountry, rowWorks, rowInclude, rowRole, rowNote, rowStatus] = ...
            local_append_row(rowAccount, rowId, rowDispName, rowCountry, rowWorks, ...
            rowInclude, rowRole, rowNote, rowStatus, nm, "", "", "", 0, 0, "", "", "not_found");
        continue;
    end

    cf = strtrim(upper(options.countryFilter));
    added = 0;
    for i = 1:numel(resp.results)
        if added >= maxCand
            break;
        end
        item = resp.results(i);

        dispName = "";
        if isfield(item, 'display_name') && ~isempty(item.display_name)
            dispName = strtrim(string(item.display_name));
        end
        oapId = "";
        if isfield(item, 'id') && ~isempty(item.id)
            parts = strsplit(strtrim(string(item.id)), '/');
            oapId = parts(end);
        end
        cc = "";
        if isfield(item, 'country_code') && ~isempty(item.country_code)
            cc = strtrim(string(item.country_code));
        end
        wc = 0;
        if isfield(item, 'works_count') && ~isempty(item.works_count)
            wc = double(item.works_count);
        end

        if strlength(cf) > 0 && strlength(cc) > 0 && ~strcmpi(cc, cf)
            continue;
        end

        added = added + 1;
        includeValue = double(added == 1);
        roleValue = local_propose_role(dispName);
        [rowAccount, rowId, rowDispName, rowCountry, rowWorks, rowInclude, rowRole, rowNote, rowStatus] = ...
            local_append_row(rowAccount, rowId, rowDispName, rowCountry, rowWorks, ...
            rowInclude, rowRole, rowNote, rowStatus, nm, oapId, dispName, cc, wc, ...
            includeValue, roleValue, "", "found");
    end

    if added == 0
        [rowAccount, rowId, rowDispName, rowCountry, rowWorks, rowInclude, rowRole, rowNote, rowStatus] = ...
            local_append_row(rowAccount, rowId, rowDispName, rowCountry, rowWorks, ...
            rowInclude, rowRole, rowNote, rowStatus, nm, "", "", "", 0, 0, "", "", "not_found");
    end
end

freshTable = table(rowAccount, rowId, rowDispName, rowCountry, rowWorks, rowInclude, rowRole, rowNote, rowStatus, ...
    'VariableNames', {'account','openalex_institution_id','display_name','country_code','works_count','include','role','note','status'});
freshTable = local_order_output_rows(freshTable);

mergePath = strtrim(options.mergeWith);
if strlength(mergePath) > 0
    if ~local_is_absolute(mergePath)
        mergePath = string(fullfile(projectRoot, char(mergePath)));
    end
    % mergeWith is best-effort: it carries prior include/role/note decisions
    % forward on a re-run. On a first run the file is absent, and a hand-made
    % institutions.csv may not yet have the review columns. Neither should be a
    % hard failure -- fall back to fresh candidates so the tool still produces
    % a usable candidate CSV.
    if ~isfile(mergePath)
        log_info('mergeWith CSV not found (%s); generating fresh candidates without merge.', mergePath);
        outTable = freshTable;
    else
        try
            existingTable = local_read_existing_review_csv(mergePath);
            outTable = merge_institutions_review_table(freshTable, existingTable, string(datetime('today', 'Format', 'yyyy-MM-dd')));
        catch mergeErr
            warning('prepare_institutions_csv:MergeSkipped', ...
                ['Ignoring mergeWith CSV (%s): %s\n', ...
                 'Generating fresh candidates. Review the output, then save it as data/list/institutions.csv.'], ...
                mergePath, mergeErr.message);
            outTable = freshTable;
        end
    end
else
    outTable = freshTable;
end

outDir = fileparts(char(outPath));
if ~isfolder(outDir) && strlength(outDir) > 0
    mkdir(outDir);
end
writetable(outTable, char(outPath));

nFound = numel(unique(outTable.account(outTable.status == "found")));
nNotFound = numel(unique(outTable.account(outTable.status ~= "found")));

log_info('Search complete: %d of %d institutions matched / %d not found', nNames, nFound, nNotFound);
fprintf('\nOutput file: %s\n', outPath);
fprintf('  %-25s %s\n', 'Total rows:', num2str(height(outTable)));
fprintf('  %-25s %s\n', 'Institutions with matches:', [num2str(nFound) ' / ' num2str(nNames)]);

if nNotFound > 0
    notFoundNames = unique(outTable.account(outTable.status ~= "found"));
    fprintf('\n  [Review needed] Institutions with no candidates:\n');
    for k = 1:numel(notFoundNames)
        fprintf('    - %s\n', notFoundNames(k));
    end
end

fprintf('\nNext steps:\n');
fprintf('  1. Open %s and review candidates\n', outPath);
fprintf('  2. Set include to 1/0 for each candidate you want to keep or skip\n');
fprintf('  3. Optionally adjust role / note after review\n');
fprintf('  4. In main_run_batch.m, set promoteReviewed=true and run Section 0.6\n');
fprintf('     (or save the reviewed file as data/list/institutions.csv manually)\n');
fprintf('  5. Validate with load_institutions_list(''data/list/institutions.csv'')\n');
fprintf('  6. Run main_run_batch.m with the reviewed institutions.csv\n\n');

if nargout == 0
    clear outPath outTable;
end
end

function names = local_parse_name_list(nameList, projectRoot)
if (ischar(nameList) || isstring(nameList)) && isscalar(string(nameList))
    s = strtrim(string(nameList));
    if isfile(s)
        fpath = char(s);
    elseif isfile(fullfile(projectRoot, char(s)))
        fpath = fullfile(projectRoot, char(s));
    else
        names = s;
        return;
    end

    raw = readlines(fpath);
    names = strings(0, 1);
    for i = 1:numel(raw)
        line = strtrim(raw(i));
        if strlength(line) == 0 || startsWith(line, "#")
            continue;
        end
        names(end+1, 1) = line; %#ok<AGROW>
    end
else
    names = strtrim(string(nameList(:)));
    names = names(strlength(names) > 0);
end
end

function result = local_is_absolute(p)
s = char(strtrim(string(p)));
result = ~isempty(s) && ...
    (s(1) == '/' || s(1) == '\' || ...
     (length(s) >= 3 && s(2) == ':' && (s(3) == '/' || s(3) == '\')));
end

function roleValue = local_propose_role(displayName)
name = strtrim(string(displayName));
if strlength(name) == 0
    roleValue = "";
elseif contains(lower(name), "hospital") || contains(name, "病院")
    roleValue = "hospital";
else
    roleValue = "";
end
end

function [rowAccount, rowId, rowDispName, rowCountry, rowWorks, rowInclude, rowRole, rowNote, rowStatus] = ...
    local_append_row(rowAccount, rowId, rowDispName, rowCountry, rowWorks, ...
    rowInclude, rowRole, rowNote, rowStatus, account, openalexId, displayName, ...
    countryCode, worksCount, includeValue, roleValue, noteValue, statusValue)
rowAccount(end+1, 1) = string(account); %#ok<AGROW>
rowId(end+1, 1) = string(openalexId); %#ok<AGROW>
rowDispName(end+1, 1) = string(displayName); %#ok<AGROW>
rowCountry(end+1, 1) = string(countryCode); %#ok<AGROW>
rowWorks(end+1, 1) = double(worksCount); %#ok<AGROW>
rowInclude(end+1, 1) = double(includeValue); %#ok<AGROW>
rowRole(end+1, 1) = string(roleValue); %#ok<AGROW>
rowNote(end+1, 1) = string(noteValue); %#ok<AGROW>
rowStatus(end+1, 1) = string(statusValue); %#ok<AGROW>
end

function T = local_order_output_rows(T)
statusRank = zeros(height(T), 1);
statusRank(T.status == "found") = 0;
statusRank(T.status == "not_found") = 1;
statusRank(T.status == "api_error") = 2;

includeRank = -double(T.include);
worksSort = -double(T.works_count);
idSort = string(T.openalex_institution_id);
accountSort = string(T.account);

[~, ix] = sortrows(table(accountSort, statusRank, includeRank, worksSort, idSort), ...
    {'accountSort','statusRank','includeRank','worksSort','idSort'});
T = T(ix, :);
end

function T = local_read_existing_review_csv(csvPath)
opts = detectImportOptions(csvPath, ...
    'VariableNamingRule', 'preserve', ...
    'Delimiter', ',');
opts = setvartype(opts, opts.VariableNames, 'string');
T = readtable(csvPath, opts);

vars = string(T.Properties.VariableNames);
accountCol = local_find_existing_column(vars, ["account","Account","input_name"]);
idCol = local_find_existing_column(vars, ["openalex_institution_id","openalex_id"]);
if accountCol == "" || idCol == ""
    error('prepare_institutions_csv:MergeMissingColumn', ...
        'mergeWith CSV must contain account/Account and openalex_institution_id/openalex_id.');
end

T = table( ...
    strtrim(string(T.(accountCol))), ...
    strtrim(string(T.(idCol))), ...
    local_pick_or_default(T, vars, "display_name", ""), ...
    local_pick_or_default(T, vars, "country_code", ""), ...
    local_pick_numeric_or_default(T, vars, "works_count", NaN), ...
    local_pick_or_default(T, vars, "include", ""), ...
    local_pick_or_default(T, vars, "role", ""), ...
    local_pick_or_default(T, vars, "note", ""), ...
    local_pick_or_default(T, vars, "status", ""), ...
    'VariableNames', {'account','openalex_institution_id','display_name','country_code','works_count','include','role','note','status'});
end

function col = local_find_existing_column(vars, candidates)
col = "";
for i = 1:numel(candidates)
    idx = find(strcmpi(vars, candidates(i)), 1, 'first');
    if ~isempty(idx)
        col = vars(idx);
        return;
    end
end
end

function vals = local_pick_or_default(T, vars, name, defaultValue)
col = local_find_existing_column(vars, name);
if col == ""
    vals = repmat(string(defaultValue), height(T), 1);
else
    vals = strtrim(string(T.(col)));
    vals(ismissing(vals)) = "";
end
end

function vals = local_pick_numeric_or_default(T, vars, name, defaultValue)
col = local_find_existing_column(vars, name);
if col == ""
    vals = repmat(double(defaultValue), height(T), 1);
else
    raw = string(T.(col));
    raw(ismissing(raw)) = "";
    vals = str2double(raw);
    vals(isnan(vals)) = defaultValue;
end
end
