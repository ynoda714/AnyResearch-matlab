function normalizedWorks = openalex_to_normalized_works(openalexTable, options)
arguments
    openalexTable table
    options.StrictValidation (1,1) logical = true
    options.DefaultSourceDataset (1,1) string = "openalex"
    options.ReproSignalsConfigPath (1,1) string = ""
end

source = standardize_columns(openalexTable);
validate_required_columns(source);
n = height(source);

recordId = build_record_id(source);
titleText = normalize_text_column(source.title);
abstractText = normalize_text_column(source.abstract);

if options.StrictValidation
    invalidMask = strlength(titleText) == 0 | strlength(abstractText) == 0;
    if any(invalidMask)
        error("openalex_to_normalized_works:InvalidRequiredText", ...
            "Found %d rows with empty title/abstract.", nnz(invalidMask));
    end
end

openalexId = optional_string_column(source, "openalex_id");
doiValue = optional_string_column(source, "doi");
publicationYear = optional_numeric_column(source, "publication_year");
publicationDate = optional_string_column(source, "publication_date");
citedByCount = optional_numeric_column(source, "cited_by_count");
fwciVal = optional_numeric_column(source, "fwci");
citationPercentile = optional_numeric_column(source, "citation_percentile");
countsByYear = optional_string_column(source, "counts_by_year");
isRetracted = optional_numeric_column(source, "is_retracted");
bestOaPdfUrl = optional_string_column(source, "best_oa_pdf_url");
licenseVal = optional_string_column(source, "license");
referencedWorksCount = optional_numeric_column(source, "referenced_works_count");
sourceDataset = optional_string_column(source, "source_dataset");
if all(strlength(sourceDataset) == 0)
    sourceDataset = repmat(options.DefaultSourceDataset, height(source), 1);
end
firstAuthorName = optional_string_column(source, "first_author_name");
firstAuthorInstitutions = optional_string_column(source, "first_author_institutions");
lastAuthorName = optional_string_column(source, "last_author_name");
lastAuthorInstitutions = optional_string_column(source, "last_author_institutions");
isOa = optional_numeric_column(source, "is_oa");
typeVal = optional_string_column(source, "type");
sourceNameVal = optional_string_column(source, "source_name");
openAccessUrl = optional_string_column(source, "open_access_url");
topicsVal = optional_string_column(source, "topics");
languageVal = optional_string_column(source, "language");

recordId = local_force_len_string(recordId, n);
titleText = local_force_len_string(titleText, n);
abstractText = local_force_len_string(abstractText, n);
openalexId = local_force_len_string(openalexId, n);
doiValue = local_force_len_string(doiValue, n);
publicationYear = local_force_len_numeric(publicationYear, n);
publicationDate = local_force_len_string(publicationDate, n);
citedByCount = local_force_len_numeric(citedByCount, n);
fwciVal = local_force_len_numeric(fwciVal, n);
citationPercentile = local_force_len_numeric(citationPercentile, n);
countsByYear = local_force_len_string(countsByYear, n);
isRetracted = local_force_len_numeric(isRetracted, n);
bestOaPdfUrl = local_force_len_string(bestOaPdfUrl, n);
licenseVal = local_force_len_string(licenseVal, n);
referencedWorksCount = local_force_len_numeric(referencedWorksCount, n);
sourceDataset = local_force_len_string(sourceDataset, n);
firstAuthorName = local_force_len_string(firstAuthorName, n);
firstAuthorInstitutions = local_force_len_string(firstAuthorInstitutions, n);
lastAuthorName = local_force_len_string(lastAuthorName, n);
lastAuthorInstitutions = local_force_len_string(lastAuthorInstitutions, n);
isOa = local_force_len_numeric(isOa, n);
typeVal = local_force_len_string(typeVal, n);
sourceNameVal = local_force_len_string(sourceNameVal, n);
openAccessUrl = local_force_len_string(openAccessUrl, n);
topicsVal = local_force_len_string(topicsVal, n);
languageVal = local_force_len_string(languageVal, n);

% M13: DOI normalization (lowercase + trim)
doiNormalized = lower(strtrim(doiValue));
doiNormalized(ismissing(doiNormalized)) = "";
doiNormalized = local_force_len_string(doiNormalized, n);

signalTable = detect_repro_signals(titleText, abstractText, ConfigPath=options.ReproSignalsConfigPath);

normalizedWorks = table( ...
    recordId, ...
    titleText, ...
    abstractText, ...
    openalexId, ...
    doiValue, ...
    doiNormalized, ...
    publicationYear, ...
    publicationDate, ...
    citedByCount, ...
    fwciVal, ...
    citationPercentile, ...
    countsByYear, ...
    isRetracted, ...
    bestOaPdfUrl, ...
    licenseVal, ...
    referencedWorksCount, ...
    sourceDataset, ...
    firstAuthorName, ...
    firstAuthorInstitutions, ...
    lastAuthorName, ...
    lastAuthorInstitutions, ...
    signalTable.mentions_dataset, ...
    signalTable.mentions_code, ...
    signalTable.mentions_library, ...
    signalTable.mentions_metrics, ...
    signalTable.repro_signal_score, ...
    signalTable.matlab_mentioned, ...
    isOa, ...
    typeVal, ...
    sourceNameVal, ...
    openAccessUrl, ...
    topicsVal, ...
    languageVal, ...
    'VariableNames', {'record_id', 'title', 'abstract', 'openalex_id', 'doi', 'doi_normalized', 'publication_year', 'publication_date', 'cited_by_count', 'fwci', 'citation_percentile', 'counts_by_year', 'is_retracted', 'best_oa_pdf_url', 'license', 'referenced_works_count', 'source_dataset', 'first_author_name', 'first_author_institutions', 'last_author_name', 'last_author_institutions', 'mentions_dataset', 'mentions_code', 'mentions_library', 'mentions_metrics', 'repro_signal_score', 'matlab_mentioned', 'is_oa', 'type', 'source_name', 'open_access_url', 'topics', 'language'} ...
    );
end

function standardized = standardize_columns(inputTable)
standardized = inputTable;
nameMap = containers.Map( ...
    {'id', 'work_id', 'openalexid', 'display_name', 'paper_title', 'abstract_inverted_index', 'paper_abstract', 'year', 'pub_year', 'source'}, ...
    {'openalex_id', 'openalex_id', 'openalex_id', 'title', 'title', 'abstract', 'abstract', 'publication_year', 'publication_year', 'source_dataset'} ...
);

for i = 1:numel(standardized.Properties.VariableNames)
    rawName = standardized.Properties.VariableNames{i};
    normalizedName = lower(regexprep(rawName, "[^a-zA-Z0-9]", ""));
    if isKey(nameMap, normalizedName)
        standardized.Properties.VariableNames{i} = char(nameMap(normalizedName));
    end
end
end

function validate_required_columns(inputTable)
requiredColumns = ["title", "abstract"];
missing = requiredColumns(~ismember(requiredColumns, string(inputTable.Properties.VariableNames)));
if ~isempty(missing)
    error("openalex_to_normalized_works:MissingColumns", ...
        "Required columns are missing: %s", strjoin(missing, ", "));
end
end

function recordId = build_record_id(inputTable)
rowCount = height(inputTable);
if ismember("record_id", string(inputTable.Properties.VariableNames))
    recordId = string(inputTable.record_id);
elseif ismember("openalex_id", string(inputTable.Properties.VariableNames))
    recordId = "oa_" + string(inputTable.openalex_id);
else
    recordId = "row_" + string((1:rowCount)');
end
recordId = strtrim(recordId);
emptyMask = strlength(recordId) == 0;
recordId(emptyMask) = "row_" + string(find(emptyMask));
recordId = recordId(:);
end

function values = normalize_text_column(raw)
if iscell(raw)
    values = string(raw);
elseif isstring(raw)
    values = raw;
elseif ischar(raw)
    values = string(cellstr(raw));
else
    values = string(raw);
end
values = regexprep(strtrim(values), "\s+", " ");
values(ismissing(values)) = "";
values = local_clean_html_noise(values);
values = values(:);
end

function values = local_clean_html_noise(values)
values = string(values);
values(ismissing(values)) = "";
values = regexprep(values, "<[^>]*>", " ");
values = strrep(values, "&lt;", "<");
values = strrep(values, "&gt;", ">");
values = strrep(values, "&amp;", "&");
values = strrep(values, "&quot;", '"');
values = strrep(values, "&#39;", "'");
values = regexprep(values, "\s+", " ");
values = strtrim(values);
end

function values = optional_string_column(inputTable, columnName)
rowCount = height(inputTable);
if ismember(columnName, string(inputTable.Properties.VariableNames))
    values = string(inputTable.(columnName));
    values(ismissing(values)) = "";
else
    values = repmat("", rowCount, 1);
end
values = values(:);
end

function values = optional_numeric_column(inputTable, columnName)
rowCount = height(inputTable);
if ismember(columnName, string(inputTable.Properties.VariableNames))
    raw = inputTable.(columnName);
    if isnumeric(raw)
        values = double(raw);
    else
        values = str2double(string(raw));
    end
else
    values = nan(rowCount, 1);
end
values = values(:);
end

function values = local_force_len_string(values, n)
values = string(values);
values(ismissing(values)) = "";
if isscalar(values)
    values = repmat(values, n, 1);
else
    values = values(:);
end
if numel(values) ~= n
    error("openalex_to_normalized_works:InvalidLength", "String column row count mismatch. expected=%d actual=%d", n, numel(values));
end
end

function values = local_force_len_numeric(values, n)
values = double(values);
if isscalar(values)
    values = repmat(values, n, 1);
else
    values = values(:);
end
if numel(values) ~= n
    error("openalex_to_normalized_works:InvalidLength", "Numeric column row count mismatch. expected=%d actual=%d", n, numel(values));
end
end
