function result = append_to_candidates(source, options)
%APPEND_TO_CANDIDATES  Merge search results into the cross-run candidate ledger.
%
%   result = append_to_candidates(runDirOrTable)
%   result = append_to_candidates(..., ledgerPath="result/candidates/candidates.jsonl")
%   result = append_to_candidates(..., runId="20260717_120000")
%
%   Deduplication key:
%     1. doi_normalized (preferred when non-empty)
%     2. openalex_id
%
%   Existing rows keep all existing non-managed columns when incoming values are empty.
%
%   Metadata fields managed by this function:
%     - first_seen_run_id
%     - last_seen_run_id

arguments
    source
    options.ledgerPath (1,1) string = "result/candidates/candidates.jsonl"
    options.runId      (1,1) string = ""
end

ledgerPath = string(options.ledgerPath);
runId = string(options.runId);

[incoming, inferredRunId] = local_load_source(source);
if runId == ""
    runId = inferredRunId;
end
if runId == ""
    runId = "manual";
end

incoming = local_prepare_incoming(incoming, runId);
incoming = local_filter_valid_rows(incoming);

if isfile(ledgerPath)
    ledger = read_jsonl(ledgerPath);
else
    ledger = table();
end
ledger = local_prepare_existing(ledger);
existingVars = string(ledger.Properties.VariableNames);

allVars = local_union_columns(ledger.Properties.VariableNames, incoming.Properties.VariableNames);
ledger = local_align_table_columns(ledger, allVars, incoming);
incoming = local_align_table_columns(incoming, allVars, ledger);

ledgerKeys = local_make_candidate_keys(ledger);
incomingKeys = local_make_candidate_keys(incoming);

rowsAppended = 0;
rowsUpdated = 0;

for i = 1:height(incoming)
    key = incomingKeys(i);
    idx = find(ledgerKeys == key, 1, "first");
    if isempty(idx)
        if strlength(strtrim(string(incoming.status(i)))) == 0
            incoming.status(i) = "new";
        end
        ledger = [ledger; incoming(i, :)]; %#ok<AGROW>
        ledgerKeys(end+1, 1) = key; %#ok<AGROW>
        rowsAppended = rowsAppended + 1;
        continue;
    end

    for vi = 1:numel(allVars)
        varName = string(allVars{vi});
        if varName == "first_seen_run_id" || varName == "last_seen_run_id"
            continue;
        end

        if any(existingVars == varName)
            if local_row_has_value(incoming.(varName), i)
                ledger.(varName)(idx, :) = incoming.(varName)(i, :);
            end
        else
            ledger.(varName)(idx, :) = incoming.(varName)(i, :);
        end
    end

    if strlength(strtrim(string(ledger.first_seen_run_id(idx)))) == 0
        ledger.first_seen_run_id(idx) = incoming.first_seen_run_id(i);
    end
    ledger.last_seen_run_id(idx) = incoming.last_seen_run_id(i);
    rowsUpdated = rowsUpdated + 1;
end

ledger = local_drop_internal_columns(ledger);

parentDir = fileparts(ledgerPath);
if strlength(parentDir) > 0 && ~isfolder(parentDir)
    mkdir(parentDir);
end
write_jsonl(ledger, ledgerPath);

result = struct();
result.ledger_path = ledgerPath;
result.run_id = runId;
result.rows_incoming = int32(height(incoming));
result.rows_appended = int32(rowsAppended);
result.rows_updated = int32(rowsUpdated);
result.rows_total = int32(height(ledger));
result.T = ledger;
end

function [T, runId] = local_load_source(source)
runId = "";

if istable(source)
    T = source;
    return;
end

sourcePath = string(source);
if isfolder(sourcePath)
    runId = string(local_basename(sourcePath));
    jsonlPath = fullfile(char(sourcePath), "search_results.jsonl");
    csvPath = fullfile(char(sourcePath), "search_results.csv");
    if isfile(jsonlPath)
        T = read_jsonl(jsonlPath);
        return;
    end
    if isfile(csvPath)
        T = readtable(csvPath, "TextType", "string", ...
            "VariableNamingRule", "preserve", "Delimiter", ",", "ReadVariableNames", true);
        return;
    end
    error("append_to_candidates:InputNotFound", ...
        "search_results.jsonl / .csv not found under run dir: %s", sourcePath);
end

if isfile(sourcePath)
    [parentDir, ~, ext] = fileparts(sourcePath);
    runId = string(local_basename(parentDir));
    if strcmpi(ext, ".jsonl")
        T = read_jsonl(sourcePath);
    else
        T = readtable(sourcePath, "TextType", "string", ...
            "VariableNamingRule", "preserve", "Delimiter", ",", "ReadVariableNames", true);
    end
    return;
end

error("append_to_candidates:InvalidInput", ...
    "source must be a table, run directory, or existing .jsonl/.csv path.");
end

function T = local_prepare_incoming(T, runId)
if ~istable(T)
    error("append_to_candidates:InvalidInput", "Incoming source could not be loaded as a table.");
end

if ~ismember("doi_normalized", T.Properties.VariableNames)
    T.doi_normalized = repmat("", height(T), 1);
end
if ~ismember("openalex_id", T.Properties.VariableNames)
    T.openalex_id = repmat("", height(T), 1);
end
T.doi_normalized = local_to_string_column(T.doi_normalized, height(T));
T.openalex_id = local_to_string_column(T.openalex_id, height(T));
T.doi_normalized = normalize_candidate_doi(T.doi_normalized);
T.openalex_id = local_normalize_openalex_id(T.openalex_id);

if ~ismember("first_seen_run_id", T.Properties.VariableNames)
    T.first_seen_run_id = repmat(runId, height(T), 1);
else
    T.first_seen_run_id = local_to_string_column(T.first_seen_run_id, height(T));
    missingMask = strlength(strtrim(T.first_seen_run_id)) == 0;
    T.first_seen_run_id(missingMask) = runId;
end

if ~ismember("last_seen_run_id", T.Properties.VariableNames)
    T.last_seen_run_id = repmat(runId, height(T), 1);
else
    T.last_seen_run_id = local_to_string_column(T.last_seen_run_id, height(T));
end
T.last_seen_run_id(:) = runId;

if ~ismember("status", T.Properties.VariableNames)
    T.status = repmat("", height(T), 1);
else
    T.status = local_to_string_column(T.status, height(T));
end

if ~ismember("note", T.Properties.VariableNames)
    T.note = repmat("", height(T), 1);
else
    T.note = local_to_string_column(T.note, height(T));
end
end

function T = local_prepare_existing(T)
if isempty(T)
    T = table();
end

requiredStringVars = ["doi_normalized", "openalex_id", "first_seen_run_id", ...
    "last_seen_run_id", "status", "note"];
for i = 1:numel(requiredStringVars)
    varName = requiredStringVars(i);
    if ~ismember(varName, T.Properties.VariableNames)
        T.(varName) = repmat("", height(T), 1);
    else
        T.(varName) = local_to_string_column(T.(varName), height(T));
    end
end
T.doi_normalized = normalize_candidate_doi(T.doi_normalized);
T.openalex_id = local_normalize_openalex_id(T.openalex_id);

missingStatus = strlength(strtrim(T.status)) == 0;
T.status(missingStatus) = "new";
end

function T = local_filter_valid_rows(T)
keys = local_make_candidate_keys(T);
keep = strlength(keys) > 0;
T = T(keep, :);
end

function keys = local_make_candidate_keys(T)
nRows = height(T);
keys = repmat("", nRows, 1);
doiVals = local_to_string_column(T.doi_normalized, nRows);
idVals = local_to_string_column(T.openalex_id, nRows);

for i = 1:nRows
    doiVal = strtrim(doiVals(i));
    idVal = strtrim(idVals(i));
    if strlength(doiVal) > 0
        keys(i) = "doi:" + doiVal;
    elseif strlength(idVal) > 0
        keys(i) = "openalex:" + idVal;
    end
end
end

function ids = local_normalize_openalex_id(ids)
ids = string(ids);
ids(ismissing(ids)) = "";
ids = strtrim(ids);
ids = regexprep(ids, '^https?://openalex\.org/', '', 'ignorecase');
ids = upper(ids);
end

function vars = local_union_columns(existingVars, incomingVars)
vars = cell(1, 0);
for i = 1:numel(existingVars)
    vars{end+1} = existingVars{i}; %#ok<AGROW>
end
for i = 1:numel(incomingVars)
    if ~any(strcmp(vars, incomingVars{i}))
        vars{end+1} = incomingVars{i}; %#ok<AGROW>
    end
end

managedTail = {"first_seen_run_id", "last_seen_run_id", "status", "note"};
for i = 1:numel(managedTail)
    vars(strcmp(vars, managedTail{i})) = [];
end
vars = [vars, managedTail];
end

function T = local_align_table_columns(T, allVars, refTable)
if nargin < 3
    refTable = table();
end

nRows = height(T);
for i = 1:numel(allVars)
    varName = string(allVars{i});
    if ismember(varName, T.Properties.VariableNames)
        continue;
    end
    if ismember(varName, refTable.Properties.VariableNames)
        refVal = refTable.(varName);
        if isnumeric(refVal)
            T.(varName) = nan(nRows, 1);
        elseif islogical(refVal)
            T.(varName) = false(nRows, 1);
        else
            T.(varName) = repmat("", nRows, 1);
        end
    else
        T.(varName) = repmat("", nRows, 1);
    end
end
T = T(:, cellstr(string(allVars)));
end

function tf = local_row_has_value(columnData, rowIdx)
rowValue = columnData(rowIdx, :);

if isstring(rowValue) || ischar(rowValue)
    tf = any(strlength(strtrim(string(rowValue))) > 0);
    return;
end

if iscell(rowValue)
    tf = false;
    for k = 1:numel(rowValue)
        item = rowValue{k};
        if isempty(item)
            continue;
        end
        if isstring(item) || ischar(item)
            if any(strlength(strtrim(string(item))) > 0)
                tf = true;
                return;
            end
        elseif isnumeric(item)
            if any(~isnan(item), "all")
                tf = true;
                return;
            end
        elseif islogical(item)
            tf = true;
            return;
        else
            tf = true;
            return;
        end
    end
    return;
end

if isnumeric(rowValue)
    tf = any(~isnan(rowValue), "all");
    return;
end

if islogical(rowValue)
    tf = true;
    return;
end

if isdatetime(rowValue)
    tf = any(~isnat(rowValue), "all");
    return;
end

if isduration(rowValue) || iscalendarDuration(rowValue)
    tf = ~isempty(rowValue);
    return;
end

try
    missingMask = ismissing(rowValue);
    tf = any(~missingMask, "all");
catch
    tf = ~isempty(rowValue);
end
end

function T = local_drop_internal_columns(T)
vars = T.Properties.VariableNames;
internalMask = startsWith(string(vars), "__");
if any(internalMask)
    T(:, internalMask) = [];
end
end

function values = local_to_string_column(raw, nRows)
if nargin < 2
    nRows = numel(raw);
end

if isstring(raw)
    values = raw;
    return;
end
if iscellstr(raw)
    values = string(raw);
    return;
end
if iscell(raw)
    values = repmat("", nRows, 1);
    for i = 1:nRows
        item = raw{i};
        if isempty(item)
            values(i) = "";
        elseif isstring(item) || ischar(item)
            values(i) = string(item);
        elseif isnumeric(item) || islogical(item)
            values(i) = string(item);
        else
            values(i) = string(jsonencode(item));
        end
    end
    return;
end
if isnumeric(raw) || islogical(raw)
    values = string(raw);
    values(ismissing(values)) = "";
    return;
end

values = string(raw);
values(ismissing(values)) = "";
end

function name = local_basename(pathText)
[~, name, ext] = fileparts(char(pathText));
name = string(name);
if strlength(name) == 0
    name = string(ext);
end
end
