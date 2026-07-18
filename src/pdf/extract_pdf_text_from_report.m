function result = extract_pdf_text_from_report(pdfReportCsv, outputCsv, opts)
arguments
    pdfReportCsv (1,1) string
    outputCsv (1,1) string
    opts.outputJsonl (1,1) string = ""
    opts.maxRows (1,1) double {mustBeInteger(opts.maxRows), mustBePositive(opts.maxRows)} = 200
    opts.maxBodyChars (1,1) double {mustBeInteger(opts.maxBodyChars), mustBePositive(opts.maxBodyChars)} = 200000
end

if ~isfile(pdfReportCsv)
    error("extract_pdf_text_from_report:ReportNotFound", "PDF report not found: %s", pdfReportCsv);
end

R = readtable(pdfReportCsv, "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",", "ReadVariableNames", true);
required = ["openalex_id","work_id","status","local_path"];
for i = 1:numel(required)
    if ~ismember(required(i), string(R.Properties.VariableNames))
        error("extract_pdf_text_from_report:MissingColumn", "Missing required column: %s", required(i));
    end
end

rows = min(height(R), opts.maxRows);
out = cell(rows, 10);
jsonRows = repmat(struct( ...
    'openalex_id', "", ...
    'work_id', "", ...
    'pdf_status', "", ...
    'local_path', "", ...
    'pdf_exists', false, ...
    'extract_status', "", ...
    'extract_message', "", ...
    'title_from_pdf', "", ...
    'abstract_from_pdf', "", ...
    'body_text_excerpt', ""), rows, 1);

for i = 1:rows
    openalexId = string(R.openalex_id(i));
    workId = string(R.work_id(i));
    status = string(R.status(i));
    localPath = string(R.local_path(i));

    existsPdf = isfile(localPath);
    titleText = "";
    abstractText = "";
    bodyText = "";

    % --- M12: skip text extraction for failed_auto_* statuses ---
    if any(status == ["failed_auto_0kb", "failed_auto_corrupt", "failed_auto_http"])
        extractStatus = "skipped_" + status;
        extractMessage = "skipped: pdf validation failed (" + status + ")";
    elseif existsPdf
        [fullText, extractStatus, extractMessage] = extract_pdf_text_engine(localPath);
        fullText = local_normalize_text(fullText);
        if extractStatus == "ok" || extractStatus == "ok_python_fallback"
            if strlength(fullText) == 0
                extractStatus = "empty";
                extractMessage = "extracted text is empty";
            else
                titleText = local_pick_title(fullText);
                abstractText = local_pick_abstract(fullText);
                bodyText = extractBefore(fullText, min(strlength(fullText)+1, opts.maxBodyChars+1));
            end
        end
    else
        extractStatus = "missing_pdf";
        extractMessage = "local_path not found";
    end

    titleCsv = local_flatten_for_csv(titleText);
    abstractCsv = local_flatten_for_csv(abstractText);
    bodyCsv = local_flatten_for_csv(bodyText);

    out(i,:) = {openalexId, workId, status, localPath, existsPdf, extractStatus, extractMessage, titleCsv, abstractCsv, bodyCsv};
    jsonRows(i).openalex_id = string(openalexId);
    jsonRows(i).work_id = string(workId);
    jsonRows(i).pdf_status = string(status);
    jsonRows(i).local_path = string(localPath);
    jsonRows(i).pdf_exists = logical(existsPdf);
    jsonRows(i).extract_status = string(extractStatus);
    jsonRows(i).extract_message = local_ascii_safe_message(string(extractMessage), string(extractStatus));
    jsonRows(i).title_from_pdf = string(titleText);
    jsonRows(i).abstract_from_pdf = string(abstractText);
    jsonRows(i).body_text_excerpt = string(bodyText);
    log_progress(i, rows, "pdf-text");
end

T = cell2table(out, 'VariableNames', {
    'openalex_id','work_id','pdf_status','local_path','pdf_exists', ...
    'extract_status','extract_message','title_from_pdf','abstract_from_pdf','body_text_excerpt'});

parent = fileparts(outputCsv);
if strlength(parent) > 0 && ~isfolder(parent)
    mkdir(parent);
end
local_write_csv_utf8_bom(T, outputCsv);

outputJsonl = string(opts.outputJsonl);
if strlength(strtrim(outputJsonl)) == 0
    outputJsonl = local_default_jsonl_path(outputCsv);
end
local_write_jsonl(jsonRows, outputJsonl);

result = struct();
result.output_csv = outputCsv;
result.output_jsonl = outputJsonl;
result.rows = int32(height(T));
result.ok_count = int32(nnz(T.extract_status == "ok"));
result.error_count = int32(nnz(T.extract_status == "error"));
result.missing_pdf_count = int32(nnz(T.extract_status == "missing_pdf"));

log_info("pdf text extraction done: rows=%d ok=%d error=%d missing_pdf=%d", ...
    result.rows, result.ok_count, result.error_count, result.missing_pdf_count);
log_info("output=%s", result.output_csv);
log_info("output_jsonl=%s", result.output_jsonl);
end

function path = local_default_jsonl_path(csvPath)
path = string(csvPath);
if endsWith(lower(path), ".csv")
    path = extractBefore(path, strlength(path) - 2) + "jsonl";
else
    path = path + ".jsonl";
end
end

function text = local_flatten_for_csv(text)
text = string(text);
text = regexprep(text, "[\x00-\x1F\x7F]", " ");
text = replace(text, ",", " ");
text = replace(text, '"', " ");
text = regexprep(text, "\s+", " ");
text = strtrim(text);
end

function text = local_normalize_text(text)
text = string(text);
text = local_repair_common_mojibake(text);
text = replace(text, "\r", "\n");
text = regexprep(text, "[\t ]+", " ");
text = regexprep(text, "\n{3,}", sprintf('\n\n'));
text = strtrim(text);
end

function title = local_pick_title(text)
lines = splitlines(text);
title = "";
bestScore = -inf;
for i = 1:min(numel(lines), 40)
    line = strtrim(string(lines(i)));
    if local_is_noise_title_line(line)
        continue;
    end
    s = local_score_title_line(line);
    if s > bestScore
        bestScore = s;
        title = line;
    end
end
end

function tf = local_is_noise_title_line(line)
line = strtrim(string(line));
low = lower(line);
if strlength(line) < 20 || strlength(line) > 220
    tf = true;
    return;
end

noiseTokens = ["doi:", "http://", "https://", "copyright", "all rights reserved", "biorxiv preprint", "medrxiv preprint", "issn", "received:", "accepted:", "published online"];
for i = 1:numel(noiseTokens)
    if contains(low, noiseTokens(i))
        tf = true;
        return;
    end
end

if ~isempty(regexp(char(low), '^\d+\s*$', 'once'))
    tf = true;
    return;
end

% Journal citation style lines often include year-volume-page patterns.
if ~isempty(regexp(char(low), '(19|20)\d{2}.*\d+[:(]\d+', 'once')) && strlength(line) < 90
    tf = true;
    return;
end

tf = false;
end

function s = local_score_title_line(line)
line = strtrim(string(line));
alphaCount = numel(regexp(char(line), '[A-Za-z]', 'match'));
spaceCount = count(line, " ");
upperCount = numel(regexp(char(line), '[A-Z]', 'match'));
upperPenalty = 0;
if upperCount > alphaCount * 0.7
    upperPenalty = 15;
end
s = double(alphaCount) + double(spaceCount) * 1.5 - upperPenalty;
end

function absText = local_pick_abstract(text)
low = lower(text);
idx = strfind(low, "abstract");
if isempty(idx)
    absText = "";
    return;
end
startPos = idx(1) + strlength("abstract");
remain = extractAfter(text, startPos);
remainLow = lower(remain);
stopTokens = ["\nintroduction", "\n1.", "\nkeywords", "\nindex terms"];
stopPos = strlength(remain) + 1;
for i = 1:numel(stopTokens)
    p = strfind(remainLow, stopTokens(i));
    if ~isempty(p)
        stopPos = min(stopPos, p(1));
    end
end
absText = strtrim(extractBefore(remain, stopPos));
if strlength(absText) > 2000
    absText = extractBefore(absText, 2001);
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

function local_write_jsonl(rows, path)
parent = fileparts(path);
if strlength(parent) > 0 && ~isfolder(parent)
    mkdir(parent);
end

fid = fopen(path, 'w', 'n', 'UTF-8');
if fid < 0
    error("extract_pdf_text_from_report:WriteJsonlFailed", "Failed to write JSONL: %s", path);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

for i = 1:numel(rows)
    r = rows(i);
    data = struct();
    data.openalex_id = char(string(r.openalex_id));
    data.work_id = char(string(r.work_id));
    data.pdf_status = char(string(r.pdf_status));
    data.local_path = char(string(r.local_path));
    data.pdf_exists = logical(r.pdf_exists);
    data.extract_status = char(string(r.extract_status));
    data.extract_message = char(string(r.extract_message));
    data.title_from_pdf = char(string(r.title_from_pdf));
    data.abstract_from_pdf = char(string(r.abstract_from_pdf));
    data.body_text_excerpt = char(string(r.body_text_excerpt));
    line = jsonencode(data);
    fwrite(fid, [line newline], 'char');
end
end

function text = local_repair_common_mojibake(text)
text = string(text);
text = replace(text, char(65533), " ");

from = ["â€™","â€˜","â€œ","â€�","â€“","â€”","â€¦", ...
    "窶冱","窶冦","窶彙","窶晄","窶ｦ", "窶"];
to = ["'","'","'","'","-","-","...", ...
    "'s","'","'","'","...", "-"];

for i = 1:numel(from)
    text = replace(text, from(i), to(i));
end

text = regexprep(text, "\s+", " ");
text = strtrim(text);
end

function text = local_safe_json_text(text)
text = string(text);
text = local_repair_common_mojibake(text);
text = regexprep(text, "[\x00-\x1F\x7F]", " ");
text = replace(text, '"', "'");
text = strtrim(text);
end

function text = local_ascii_safe_message(text, status)
text = string(text);
text = local_safe_json_text(text);
text = regexprep(text, "[^\x20-\x7E]", " ");
text = regexprep(text, "\s+", " ");
text = strtrim(text);
if text == "" && status == "error"
    text = "extract_error";
end
end
