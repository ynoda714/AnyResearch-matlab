function [T, isLegacy] = read_institutions_review_csv(csvPath)
%READ_INSTITUTIONS_REVIEW_CSV  Reads an institutions CSV (candidate, reviewed or legacy) into one table.
%
%   [T, isLegacy] = read_institutions_review_csv(csvPath)
%
%   Returns the nine review columns (account, openalex_institution_id, display_name,
%   country_code, works_count, include, role, note, status); missing columns are
%   filled with blanks. The legacy two-column format (Account, openalex_institution_id)
%   has no include column and always meant "every row is a target" for the batch
%   (load_institutions_list), so its rows read as include = "1" and isLegacy is true.
%   A file that does have an include column keeps its own values (blank means skip).
%
%   Errors: prepare_institutions_csv:MergeMissingColumn when the account or the
%   institution ID column is missing.
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

isLegacy = local_find_existing_column(vars, "include") == "";
includeDefault = "";
if isLegacy
    includeDefault = "1";
end

T = table( ...
    strtrim(string(T.(accountCol))), ...
    strtrim(string(T.(idCol))), ...
    local_pick_or_default(T, vars, "display_name", ""), ...
    local_pick_or_default(T, vars, "country_code", ""), ...
    local_pick_numeric_or_default(T, vars, "works_count", NaN), ...
    local_pick_or_default(T, vars, "include", includeDefault), ...
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
