function result = build_final_table(baseTable, queryText, opts)
arguments
    baseTable table
    queryText (1,1) string
    opts.metadataTable table = table()
    opts.evidenceTable table = table()
    opts.pdfReportTable table = table()
    opts.outputCsv (1,1) string = ""
end

B = baseTable;
B = local_ensure_default_metadata_cols(B);

if height(opts.metadataTable) > 0
    B = local_attach_metadata(B, opts.metadataTable);
end

if height(opts.evidenceTable) > 0
    B = local_attach_evidence(B, opts.evidenceTable);
else
    B = local_add_missing_evidence_cols(B);
end

if height(opts.pdfReportTable) > 0
    B = local_attach_pdf_status(B, opts.pdfReportTable);
end

B = local_finalize_output_cols(B);

result = struct();
result.T = B;
result.rows = int32(height(B));
result.query = queryText;

if opts.outputCsv ~= ""
    outDir = fileparts(opts.outputCsv);
    if strlength(outDir) > 0 && ~isfolder(outDir)
        mkdir(outDir);
    end
    local_write_csv_utf8_bom(B, opts.outputCsv);
    result.output_csv = opts.outputCsv;
end

log_info("final table done: rows=%d", result.rows);
if isfield(result, 'output_csv')
    log_info("output=%s", result.output_csv);
end
end

function B = local_attach_evidence(B, E)
B = local_add_missing_evidence_cols(B);
required = ["openalex_id","evidence_status","evidence_count","evidence_text"];
if ~all(ismember(required, string(E.Properties.VariableNames)))
    return;
end

if ~ismember("openalex_id", string(B.Properties.VariableNames))
    return;
end

keys = string(E.openalex_id);
map = containers.Map('KeyType','char','ValueType','int32');
for i = 1:numel(keys)
    k = strtrim(keys(i));
    if ismissing(k) || k == ""
        continue;
    end
    ck = char(k);
    if ~isKey(map, ck)
        map(ck) = int32(i);
    end
end

for i = 1:height(B)
    k = strtrim(string(B.openalex_id(i)));
    if ismissing(k) || k == ""
        continue;
    end
    ck = char(k);
    if ~isKey(map, ck)
        continue;
    end
    j = map(ck);
    B.evidence_status(i) = string(E.evidence_status(j));
    B.evidence_count(i) = double(E.evidence_count(j));
    B.evidence_text(i) = string(E.evidence_text(j));
end
end

function B = local_add_missing_evidence_cols(B)
if ~ismember("evidence_status", string(B.Properties.VariableNames))
    B.evidence_status = repmat("", height(B), 1);
end
if ~ismember("evidence_count", string(B.Properties.VariableNames))
    B.evidence_count = nan(height(B), 1);
end
if ~ismember("evidence_text", string(B.Properties.VariableNames))
    B.evidence_text = repmat("", height(B), 1);
end
end

function B = local_attach_metadata(B, M)
if ~ismember("openalex_id", string(B.Properties.VariableNames))
    return;
end
if ~ismember("openalex_id", string(M.Properties.VariableNames))
    return;
end

metaCols = ["title", "abstract", "publication_year", "cited_by_count", "title_supplemented_from_pdf", "abstract_supplemented_from_pdf"];
metaCols = metaCols(ismember(metaCols, string(M.Properties.VariableNames)));
if isempty(metaCols)
    return;
end

keys = string(M.openalex_id);
map = containers.Map('KeyType','char','ValueType','int32');
for i = 1:numel(keys)
    k = strtrim(keys(i));
    if ismissing(k) || k == ""
        continue;
    end
    ck = char(k);
    if ~isKey(map, ck)
        map(ck) = int32(i);
    end
end

for c = 1:numel(metaCols)
    col = metaCols(c);
    if ~ismember(col, string(B.Properties.VariableNames))
        if islogical(M.(col))
            B.(col) = false(height(B), 1);
        elseif isnumeric(M.(col))
            B.(col) = nan(height(B), 1);
        else
            B.(col) = repmat("", height(B), 1);
        end
    end
end

for i = 1:height(B)
    k = strtrim(string(B.openalex_id(i)));
    if ismissing(k) || k == ""
        continue;
    end
    ck = char(k);
    if ~isKey(map, ck)
        continue;
    end
    j = map(ck);
    for c = 1:numel(metaCols)
        col = metaCols(c);
        if islogical(B.(col))
            B.(col)(i) = logical(M.(col)(j));
        elseif isnumeric(B.(col))
            B.(col)(i) = double(M.(col)(j));
        else
            B.(col)(i) = string(M.(col)(j));
        end
    end
end
end

function B = local_ensure_default_metadata_cols(B)
if ~ismember("cited_by_count", string(B.Properties.VariableNames))
    B.cited_by_count = nan(height(B), 1);
end
if ~ismember("title_supplemented_from_pdf", string(B.Properties.VariableNames))
    B.title_supplemented_from_pdf = false(height(B), 1);
end
if ~ismember("abstract_supplemented_from_pdf", string(B.Properties.VariableNames))
    B.abstract_supplemented_from_pdf = false(height(B), 1);
end
end

function B = local_finalize_output_cols(B)
cols = string(B.Properties.VariableNames);

if ~ismember("first_author_name", cols)
    if ismember("author", cols)
        B.first_author_name = fillmissing(string(B.author), "constant", "");
    else
        B.first_author_name = repmat("", height(B), 1);
    end
end

if ~ismember("first_author_institution", cols)
    if ismember("first_author_institutions", cols)
        B.first_author_institution = fillmissing(string(B.first_author_institutions), "constant", "");
    elseif ismember("institution", cols)
        B.first_author_institution = fillmissing(string(B.institution), "constant", "");
    else
        B.first_author_institution = repmat("", height(B), 1);
    end
end

if ~ismember("last_author_name", cols)
    if ismember("first_author_name", string(B.Properties.VariableNames))
        B.last_author_name = fillmissing(string(B.first_author_name), "constant", "");
    else
        B.last_author_name = repmat("", height(B), 1);
    end
end

if ~ismember("last_author_institution", cols)
    if ismember("last_author_institutions", string(B.Properties.VariableNames))
        B.last_author_institution = fillmissing(string(B.last_author_institutions), "constant", "");
    elseif ismember("first_author_institution", string(B.Properties.VariableNames))
        B.last_author_institution = fillmissing(string(B.first_author_institution), "constant", "");
    else
        B.last_author_institution = repmat("", height(B), 1);
    end
end

if ~ismember("author", cols)
    if ismember("first_author_name", string(B.Properties.VariableNames))
        B.author = fillmissing(string(B.first_author_name), "constant", "");
    else
        B.author = repmat("", height(B), 1);
    end
end

if ~ismember("institution", cols)
    if ismember("first_author_institutions", string(B.Properties.VariableNames))
        B.institution = fillmissing(string(B.first_author_institutions), "constant", "");
    else
        B.institution = repmat("", height(B), 1);
    end
end

if ~ismember("pdf_status", cols)
    B.pdf_status = repmat("", height(B), 1);
end

dropCols = ["evidence_status", "evidence_count", "evidence_text", ...
            "title_supplemented_from_pdf", "abstract_supplemented_from_pdf"];
for k = 1:numel(dropCols)
    if ismember(dropCols(k), string(B.Properties.VariableNames))
        B.(dropCols(k)) = [];
    end
end
end

function B = local_attach_pdf_status(B, R)
if ~ismember("openalex_id", string(B.Properties.VariableNames))
    return;
end
if ~ismember("openalex_id", string(R.Properties.VariableNames)) || ...
        ~ismember("status", string(R.Properties.VariableNames))
    return;
end

statusMap = containers.Map( ...
    {'downloaded', 'manual_required', 'error', 'failed_auto_0kb', 'failed_auto_corrupt', 'failed_auto_http'}, ...
    {'ok',         'manual_required', 'error', 'failed_auto_0kb', 'failed_auto_corrupt', 'failed_auto_http'});

reportMap = containers.Map('KeyType','char','ValueType','char');
rkeys = string(R.openalex_id);
for i = 1:numel(rkeys)
    k = strtrim(rkeys(i));
    if ismissing(k) || k == ""
        continue;
    end
    ck = char(k);
    rawStatus = char(strtrim(string(R.status(i))));
    if isKey(statusMap, rawStatus)
        mapped = statusMap(rawStatus);
    else
        mapped = rawStatus;
    end
    if ~isKey(reportMap, ck)
        reportMap(ck) = mapped;
    end
end

if ~ismember("pdf_status", string(B.Properties.VariableNames))
    B.pdf_status = repmat("", height(B), 1);
end

for i = 1:height(B)
    k = strtrim(string(B.openalex_id(i)));
    if ismissing(k) || k == ""
        continue;
    end
    ck = char(k);
    if isKey(reportMap, ck)
        B.pdf_status(i) = string(reportMap(ck));
    end
end
end

function local_write_csv_utf8_bom(T, path)
writetable(T, path, "Encoding", "UTF-8");

fid = fopen(path, 'r');
if fid < 0
    return;
end
cleanupIn = onCleanup(@() fclose(fid)); %#ok<NASGU>
bytes = fread(fid, Inf, '*uint8');

bom = uint8([239; 187; 191]);
hasBom = numel(bytes) >= 3 && all(bytes(1:3) == bom);
if hasBom
    return;
end

fidw = fopen(path, 'w');
if fidw < 0
    return;
end
cleanupOut = onCleanup(@() fclose(fidw)); %#ok<NASGU>
fwrite(fidw, bom, 'uint8');
fwrite(fidw, bytes, 'uint8');
end
