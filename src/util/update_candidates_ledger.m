function result = update_candidates_ledger(options)
%UPDATE_CANDIDATES_LEDGER  Update managed fields and optional extra columns for selected ledger rows.
%
%   result = update_candidates_ledger(ledgerPath="...", doiNormalized="10.1000/abc")
%   result = update_candidates_ledger(..., status="reviewed", note="Tier A candidate")
%   result = update_candidates_ledger(..., updateColumns="extra_a", updateValues="v1")
%
%   Selectors:
%     - doiNormalized (preferred)
%     - openalexId
%
%   Updates:
%     - status
%     - note
%     - updateColumns / updateValues

arguments
    options.ledgerPath     (1,1) string = "result/candidates/candidates.jsonl"
    options.doiNormalized          string = strings(0, 1)
    options.openalexId             string = strings(0, 1)
    options.status         (1,1) string = ""
    options.note           (1,1) string = ""
    options.updateColumns          string = strings(0, 1)
    options.updateValues           string = strings(0, 1)
end

if ~isfile(options.ledgerPath)
    error("update_candidates_ledger:InputNotFound", ...
        "Ledger file not found: %s", options.ledgerPath);
end

hasDoiSelector = ~isempty(options.doiNormalized);
hasIdSelector = ~isempty(options.openalexId);
if ~hasDoiSelector && ~hasIdSelector
    error("update_candidates_ledger:MissingSelector", ...
        "Specify doiNormalized and/or openalexId.");
end
updateColumns = string(options.updateColumns(:));
updateValues = string(options.updateValues(:));
updateColumns(ismissing(updateColumns)) = "";
updateValues(ismissing(updateValues)) = "";
if strlength(strtrim(options.status)) == 0 ...
        && strlength(options.note) == 0 ...
        && isempty(updateColumns)
    error("update_candidates_ledger:MissingUpdate", ...
        "Specify status, note, and/or updateColumns/updateValues.");
end
if strlength(strtrim(options.status)) > 0
    local_validate_status(options.status);
end
local_validate_extra_updates(updateColumns, updateValues);

T = read_jsonl(options.ledgerPath);
if ~ismember("doi_normalized", T.Properties.VariableNames)
    T.doi_normalized = repmat("", height(T), 1);
end
if ~ismember("openalex_id", T.Properties.VariableNames)
    T.openalex_id = repmat("", height(T), 1);
end
if ~ismember("status", T.Properties.VariableNames)
    T.status = repmat("", height(T), 1);
end
if ~ismember("note", T.Properties.VariableNames)
    T.note = repmat("", height(T), 1);
end
T.doi_normalized = normalize_candidate_doi(string(T.doi_normalized));
T.openalex_id = local_normalize_openalex_id(string(T.openalex_id));
T.status = string(T.status);
T.note = string(T.note);
T = local_prepare_extra_columns(T, updateColumns);

mask = true(height(T), 1);
if hasDoiSelector
    doiVals = string(T.doi_normalized);
    selector = normalize_candidate_doi(string(options.doiNormalized(:)));
    mask = mask & ismember(doiVals, selector);
end
if hasIdSelector
    idVals = string(T.openalex_id);
    selector = local_normalize_openalex_id(string(options.openalexId(:)));
    mask = mask & ismember(idVals, selector);
end

matchCount = nnz(mask);
if matchCount == 0
    error("update_candidates_ledger:NoMatch", "No ledger rows matched the selector.");
end

if strlength(strtrim(options.status)) > 0
    T.status(mask) = repmat(string(options.status), matchCount, 1);
end
if strlength(options.note) > 0
    T.note(mask) = repmat(string(options.note), matchCount, 1);
end
T = local_apply_extra_updates(T, mask, updateColumns, updateValues);

write_jsonl(T, options.ledgerPath);

result = struct();
result.ledger_path = string(options.ledgerPath);
result.rows_updated = int32(matchCount);
result.T = T(mask, :);
end

function ids = local_normalize_openalex_id(ids)
ids = string(ids);
ids(ismissing(ids)) = "";
ids = strtrim(ids);
ids = regexprep(ids, '^https?://openalex\.org/', '', 'ignorecase');
ids = upper(ids);
end

function local_validate_status(status)
status = strtrim(string(status));
validFixed = ["new", "reviewed", "rejected"];
if any(status == validFixed)
    return;
end
if ~isempty(regexp(char(status), '^registered_RP[0-9A-Za-z_-]+$', 'once'))
    return;
end
error("update_candidates_ledger:InvalidStatus", ...
    "status must be new / reviewed / rejected / registered_RPxx. Got: %s", status);
end

function local_validate_extra_updates(updateColumns, updateValues)
if isempty(updateColumns) && isempty(updateValues)
    return;
end
if numel(updateColumns) ~= numel(updateValues)
    error("update_candidates_ledger:UpdateSizeMismatch", ...
        "updateColumns and updateValues must have the same number of elements.");
end
updateColumns = strtrim(string(updateColumns));
if any(strlength(updateColumns) == 0)
    error("update_candidates_ledger:InvalidUpdateColumn", ...
        "updateColumns must not contain blank names.");
end
reserved = ["doi_normalized", "openalex_id", "status", "note"];
invalidMask = ismember(updateColumns, reserved);
if any(invalidMask)
    badName = updateColumns(find(invalidMask, 1, "first"));
    error("update_candidates_ledger:ReservedUpdateColumn", ...
        "Use dedicated arguments for reserved column: %s", badName);
end
end

function T = local_prepare_extra_columns(T, updateColumns)
for i = 1:numel(updateColumns)
    varName = char(updateColumns(i));
    if ~ismember(updateColumns(i), T.Properties.VariableNames)
        T.(varName) = repmat("", height(T), 1);
    else
        T.(varName) = string(T.(varName));
        T.(varName)(ismissing(T.(varName))) = "";
    end
end
end

function T = local_apply_extra_updates(T, mask, updateColumns, updateValues)
matchCount = nnz(mask);
for i = 1:numel(updateColumns)
    varName = char(updateColumns(i));
    T.(varName)(mask) = repmat(string(updateValues(i)), matchCount, 1);
end
end
