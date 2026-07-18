function targets = load_institutions_list(csvPath)
%LOAD_INSTITUTIONS_LIST  Loads a reviewed institutions.csv into 1-target-per-row form.
%
%   Supports both the legacy 2-column schema:
%     Account, openalex_institution_id
%
%   and the v2 reviewed schema:
%     account, openalex_institution_id, display_name, include, role, note, ...
%
%   Usage:
%     T = load_institutions_list("data/list/institutions.csv")
%
%   Return table columns:
%     account         : Target name (1 row = 1 target)
%     institution_ids : Cell array of string vectors (included OpenAlex IDs)
%     n_ids           : Number of included IDs
%     display_names   : Cell array of string vectors aligned to institution_ids
%     roles           : Cell array of string vectors aligned to institution_ids

arguments
    csvPath (1,1) string
end

if ~isfile(csvPath)
    error("load_institutions_list:InputNotFound", ...
        "institutions CSV not found: %s", csvPath);
end

opts = detectImportOptions(csvPath, ...
    "VariableNamingRule", "preserve", ...
    "Delimiter", ",");
opts = setvartype(opts, opts.VariableNames, "string");
L = readtable(csvPath, opts);

vars = string(L.Properties.VariableNames);
accountCol = local_find_required_column(vars, "account");
idCol = local_find_required_column(vars, "openalex_institution_id");
displayCol = local_find_optional_column(vars, "display_name");
includeCol = local_find_optional_column(vars, "include");
roleCol = local_find_optional_column(vars, "role");

accountVals = strtrim(string(L.(accountCol)));
idVals = strtrim(string(L.(idCol)));

rowMask = accountVals ~= "" & idVals ~= "";
accountVals = accountVals(rowMask);
idVals = idVals(rowMask);

if displayCol ~= ""
    displayVals = strtrim(string(L.(displayCol)));
    displayVals = displayVals(rowMask);
else
    displayVals = repmat("", nnz(rowMask), 1);
end

if roleCol ~= ""
    roleVals = strtrim(string(L.(roleCol)));
    roleVals = roleVals(rowMask);
else
    roleVals = repmat("", nnz(rowMask), 1);
end

if includeCol ~= ""
    includeVals = local_parse_include_column(L.(includeCol));
    includeVals = includeVals(rowMask);
else
    includeVals = true(nnz(rowMask), 1);
end

if isempty(accountVals)
    error("load_institutions_list:NoRows", "No valid institution rows found.");
end

local_validate_id_format(idVals);
local_warn_duplicate_ids_across_accounts(accountVals, idVals);

accounts = unique(accountVals, "stable");
targetAccount = strings(0, 1);
targetIds = cell(0, 1);
targetCounts = zeros(0, 1);
targetDisplays = cell(0, 1);
targetRoles = cell(0, 1);

for i = 1:numel(accounts)
    acc = accounts(i);
    maskAll = accountVals == acc;
    maskIncluded = maskAll & includeVals;
    if ~any(maskIncluded)
        warning("load_institutions_list:NoIncludedRows", ...
            "Skipping account '%s': no rows with include=1.", acc);
        continue;
    end

    ids = idVals(maskIncluded);
    displays = displayVals(maskIncluded);
    roles = roleVals(maskIncluded);
    [ids, displays, roles] = local_unique_by_id(ids, displays, roles);

    targetAccount(end+1, 1) = acc; %#ok<AGROW>
    targetIds{end+1, 1} = ids; %#ok<AGROW>
    targetCounts(end+1, 1) = numel(ids); %#ok<AGROW>
    targetDisplays{end+1, 1} = displays; %#ok<AGROW>
    targetRoles{end+1, 1} = roles; %#ok<AGROW>
end

if isempty(targetAccount)
    error("load_institutions_list:NoTargets", ...
        "No executable targets remained after applying include filters.");
end

targets = table(targetAccount, targetIds, targetCounts, targetDisplays, targetRoles, ...
    'VariableNames', {'account', 'institution_ids', 'n_ids', 'display_names', 'roles'});
end

function col = local_find_required_column(vars, wanted)
col = local_find_optional_column(vars, wanted);
if col == ""
    error("load_institutions_list:MissingColumn", "Missing required column: %s", wanted);
end
end

function col = local_find_optional_column(vars, wanted)
idx = find(strcmpi(vars, wanted), 1, "first");
if isempty(idx)
    col = "";
else
    col = vars(idx);
end
end

function includeVals = local_parse_include_column(raw)
s = string(raw);
s(ismissing(s)) = "";
includeVals = false(size(s));
for i = 1:numel(s)
    v = lower(strtrim(s(i)));
    if v == ""
        includeVals(i) = false;
    elseif any(v == ["1", "true", "yes", "y"])
        includeVals(i) = true;
    elseif any(v == ["0", "false", "no", "n"])
        includeVals(i) = false;
    else
        numVal = str2double(v);
        if ~isnan(numVal)
            includeVals(i) = (numVal ~= 0);
        else
            error("load_institutions_list:InvalidInclude", ...
                "Unsupported include value at row %d: %s", i + 1, s(i));
        end
    end
end
includeVals = logical(includeVals);
end

function local_validate_id_format(ids)
badMask = cellfun(@isempty, regexp(cellstr(ids), '^I\d+$', 'once'));
if any(badMask)
    badId = ids(find(badMask, 1, "first"));
    error("load_institutions_list:InvalidId", ...
        "Invalid OpenAlex institution ID: %s", badId);
end
end

function local_warn_duplicate_ids_across_accounts(accounts, ids)
uIds = unique(ids, "stable");
for i = 1:numel(uIds)
    id = uIds(i);
    owners = unique(accounts(ids == id), "stable");
    if numel(owners) > 1
        warning("load_institutions_list:DuplicateIdAcrossAccounts", ...
            "OpenAlex institution ID %s is assigned to multiple accounts: %s", ...
            id, strjoin(owners, ", "));
    end
end
end

function [idsOut, displaysOut, rolesOut] = local_unique_by_id(ids, displays, roles)
[~, ia] = unique(ids, "stable");
idsOut = ids(ia);
displaysOut = displays(ia);
rolesOut = roles(ia);
end
