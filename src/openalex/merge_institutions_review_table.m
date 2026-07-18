function merged = merge_institutions_review_table(freshTable, existingTable, asOfDate)
%MERGE_INSTITUTIONS_REVIEW_TABLE  Preserves reviewed fields when refreshing institution candidates.
%
%   merged = merge_institutions_review_table(freshTable, existingTable, "2026-07-17")
%
%   Human-maintained columns (include / role / note) are preserved for
%   matching account x openalex_institution_id rows. API-derived columns are
%   refreshed from freshTable.

arguments
    freshTable table
    existingTable table
    asOfDate (1,1) string = string(datetime('today', 'Format', 'yyyy-MM-dd'))
end

fresh = local_normalize_table(freshTable);
existing = local_normalize_table(existingTable);
dateText = strtrim(asOfDate);

existingAccounts = unique(existing.account(existing.account ~= ""), 'stable');
freshKeys = local_make_keys(fresh.account, fresh.openalex_institution_id);
existingKeys = local_make_keys(existing.account, existing.openalex_institution_id);

keepFresh = true(height(fresh), 1);
merged = fresh([],:);

for i = 1:height(fresh)
    key = freshKeys(i);
    if key == "|"
        if any(existing.account == fresh.account(i))
            keepFresh(i) = false;
        end
        continue;
    end

    idxExisting = find(existingKeys == key, 1, 'first');
    if ~isempty(idxExisting)
        row = fresh(i, :);
        row.include = local_preserve_include(existing.include(idxExisting), fresh.include(i));
        row.role = existing.role(idxExisting);
        row.note = existing.note(idxExisting);
        merged = [merged; row]; %#ok<AGROW>
        keepFresh(i) = false;
        continue;
    end

    row = fresh(i, :);
    row.include = 0;
    if any(existingAccounts == row.account)
        row.note = local_append_note(row.note, "new candidate since " + dateText);
    end
    merged = [merged; row]; %#ok<AGROW>
    keepFresh(i) = false;
end

for i = 1:height(existing)
    key = existingKeys(i);
    if key == "|"
        continue;
    end
    if any(freshKeys == key)
        continue;
    end

    row = existing(i, :);
    row.note = local_append_note(row.note, "not returned by API on " + dateText);
    merged = [merged; row]; %#ok<AGROW>
end

freshResidual = fresh(keepFresh, :);
if ~isempty(freshResidual)
    merged = [merged; freshResidual]; %#ok<AGROW>
end

merged = local_order_rows(merged);
end

function T = local_normalize_table(T)
requiredString = ["account","openalex_institution_id","display_name","country_code","role","note","status"];
for i = 1:numel(requiredString)
    name = requiredString(i);
    if ~ismember(name, string(T.Properties.VariableNames))
        T.(name) = repmat("", height(T), 1);
    else
        T.(name) = strtrim(string(T.(name)));
        T.(name)(ismissing(T.(name))) = "";
    end
end

if ~ismember("works_count", string(T.Properties.VariableNames))
    T.works_count = nan(height(T), 1);
else
    if iscell(T.works_count) || isstring(T.works_count) || ischar(T.works_count)
        vals = str2double(string(T.works_count));
    else
        vals = double(T.works_count);
    end
    T.works_count = vals;
end

if ~ismember("include", string(T.Properties.VariableNames))
    T.include = zeros(height(T), 1);
else
    T.include = local_parse_include_values(T.include);
end

T = T(:, {'account','openalex_institution_id','display_name','country_code','works_count','include','role','note','status'});
end

function includeVals = local_parse_include_values(raw)
s = string(raw);
s(ismissing(s)) = "";
includeVals = zeros(numel(s), 1);
for i = 1:numel(s)
    v = lower(strtrim(s(i)));
    if v == ""
        includeVals(i) = 0;
    elseif any(v == ["1","true","yes","y"])
        includeVals(i) = 1;
    elseif any(v == ["0","false","no","n"])
        includeVals(i) = 0;
    else
        numVal = str2double(v);
        if isnan(numVal)
            includeVals(i) = 0;
        else
            includeVals(i) = double(numVal ~= 0);
        end
    end
end
end

function keys = local_make_keys(accounts, ids)
keys = lower(strtrim(string(accounts))) + "|" + upper(strtrim(string(ids)));
end

function includeValue = local_preserve_include(existingValue, fallbackValue)
parsed = local_parse_include_values(existingValue);
if isempty(parsed)
    includeValue = double(fallbackValue);
else
    includeValue = double(parsed(1));
end
end

function noteOut = local_append_note(noteIn, message)
base = strtrim(string(noteIn));
msg = strtrim(string(message));
if strlength(msg) == 0
    noteOut = base;
elseif strlength(base) == 0
    noteOut = msg;
elseif contains(base, msg)
    noteOut = base;
else
    noteOut = base + " | " + msg;
end
end

function T = local_order_rows(T)
statusRank = zeros(height(T), 1);
statusRank(T.status == "found") = 0;
statusRank(T.status == "not_found") = 1;
statusRank(T.status == "api_error") = 2;
statusRank(T.status == "") = 3;

includeRank = -double(T.include);
worksSort = -double(T.works_count);
idSort = string(T.openalex_institution_id);
accountSort = string(T.account);

[~, ix] = sortrows(table(accountSort, statusRank, includeRank, worksSort, idSort), ...
    {'accountSort','statusRank','includeRank','worksSort','idSort'});
T = T(ix, :);
end
