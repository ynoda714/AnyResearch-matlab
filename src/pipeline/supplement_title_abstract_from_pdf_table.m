function result = supplement_title_abstract_from_pdf_table(baseTable, pdfTextInput, opts)
arguments
    baseTable table
    pdfTextInput
    opts.outputCsv (1,1) string = ""
end

if istable(pdfTextInput)
    P = pdfTextInput;
else
    inputPath = string(pdfTextInput);
    if ~isfile(inputPath)
        error("supplement_title_abstract_from_pdf_table:PdfTextNotFound", "PDF text input not found: %s", inputPath);
    end
    P = local_read_pdf_text_table(inputPath);
end

B = baseTable;

requiredBase = ["openalex_id", "title", "abstract"];
for i = 1:numel(requiredBase)
    if ~ismember(requiredBase(i), string(B.Properties.VariableNames))
        error("supplement_title_abstract_from_pdf_table:MissingBaseColumn", "Missing required column in base table: %s", requiredBase(i));
    end
end
requiredPdf = ["openalex_id", "extract_status", "title_from_pdf", "abstract_from_pdf"];
for i = 1:numel(requiredPdf)
    if ~ismember(requiredPdf(i), string(P.Properties.VariableNames))
        error("supplement_title_abstract_from_pdf_table:MissingPdfColumn", "Missing required column in pdf text table: %s", requiredPdf(i));
    end
end

B.title_original = string(B.title);
B.abstract_original = string(B.abstract);
B.title = local_clean_html_noise(string(B.title));
B.abstract = local_clean_html_noise(string(B.abstract));

B.title_supplemented_from_pdf = false(height(B), 1);
B.abstract_supplemented_from_pdf = false(height(B), 1);

keys = string(P.openalex_id);
map = containers.Map('KeyType', 'char', 'ValueType', 'int32');
for i = 1:numel(keys)
    k = strtrim(keys(i));
    if k == ""
        continue;
    end
    ck = char(k);
    if ~isKey(map, ck)
        map(ck) = int32(i);
    end
end

for i = 1:height(B)
    k = strtrim(string(B.openalex_id(i)));
    if k == ""
        continue;
    end
    ck = char(k);
    if ~isKey(map, ck)
        continue;
    end
    pi = map(ck);

    if string(P.extract_status(pi)) ~= "ok"
        continue;
    end

    pdfTitle = local_clean_html_noise(string(P.title_from_pdf(pi)));
    pdfAbstract = local_clean_html_noise(string(P.abstract_from_pdf(pi)));

    if strlength(strtrim(string(B.title(i)))) == 0 && strlength(strtrim(pdfTitle)) > 0
        B.title(i) = pdfTitle;
        B.title_supplemented_from_pdf(i) = true;
    end
    if strlength(strtrim(string(B.abstract(i)))) == 0 && strlength(strtrim(pdfAbstract)) > 0
        B.abstract(i) = pdfAbstract;
        B.abstract_supplemented_from_pdf(i) = true;
    end
end

result = struct();
result.T = B;
result.rows = int32(height(B));
result.title_supplemented_count = int32(nnz(B.title_supplemented_from_pdf));
result.abstract_supplemented_count = int32(nnz(B.abstract_supplemented_from_pdf));
result.title_empty_after = int32(nnz(strlength(strtrim(string(B.title))) == 0));
result.abstract_empty_after = int32(nnz(strlength(strtrim(string(B.abstract))) == 0));

if opts.outputCsv ~= ""
    outDir = fileparts(opts.outputCsv);
    if strlength(outDir) > 0 && ~isfolder(outDir)
        mkdir(outDir);
    end
    local_write_csv_utf8_bom(B, opts.outputCsv);
    result.output_csv = opts.outputCsv;
end

log_info("supplement done: rows=%d title_supp=%d abstract_supp=%d", ...
    result.rows, result.title_supplemented_count, result.abstract_supplemented_count);
if isfield(result, 'output_csv')
    log_info("output=%s", result.output_csv);
end
end

function T = local_read_pdf_text_table(path)
inPath = string(path);
if endsWith(lower(inPath), ".jsonl")
    T = local_read_jsonl(inPath);
    return;
end
T = readtable(inPath, "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",", "ReadVariableNames", true);
end

function T = local_read_jsonl(path)
txt = string(fileread(path));
lines = splitlines(txt);
lines = strtrim(lines);
lines = lines(lines ~= "");

rows = cell(numel(lines), 4);
for i = 1:numel(lines)
    obj = jsondecode(char(lines(i)));
    rows(i,:) = { ...
        local_obj_str(obj, 'openalex_id'), ...
        local_obj_str(obj, 'extract_status'), ...
        local_obj_str(obj, 'title_from_pdf'), ...
        local_obj_str(obj, 'abstract_from_pdf') ...
        };
end

T = cell2table(rows, 'VariableNames', {'openalex_id','extract_status','title_from_pdf','abstract_from_pdf'});
T.openalex_id = string(T.openalex_id);
T.extract_status = string(T.extract_status);
T.title_from_pdf = string(T.title_from_pdf);
T.abstract_from_pdf = string(T.abstract_from_pdf);
end

function s = local_obj_str(obj, fieldName)
if isfield(obj, fieldName)
    s = string(obj.(fieldName));
else
    s = "";
end
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
values = regexprep(values, "[\x{FDD0}-\x{FDEF}\x{FFFE}\x{FFFF}]", "");
values = regexprep(values, "\s+", " ");
values = strtrim(values);
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
