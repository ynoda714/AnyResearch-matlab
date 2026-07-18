function result = extract_keyword_evidence(pdfTextInput, outputCsv, queryText, opts)
arguments
    pdfTextInput (1,1) string
    outputCsv (1,1) string
    queryText (1,1) string
    % New policy: extract 2 lines before/after keyword
    opts.contextLines (1,1) double {mustBeInteger(opts.contextLines), mustBePositive(opts.contextLines)} = 2
    opts.maxEvidencePerRow (1,1) double {mustBeInteger(opts.maxEvidencePerRow), mustBePositive(opts.maxEvidencePerRow)} = 3
end

if ~isfile(pdfTextInput)
    error("extract_keyword_evidence:InputNotFound", "PDF text input not found: %s", pdfTextInput);
end

q = strtrim(string(queryText));
if q == ""
    error("extract_keyword_evidence:EmptyQuery", "queryText is empty.");
end

T = local_read_pdf_text_table(pdfTextInput);
required = ["openalex_id","work_id","extract_status","body_text_excerpt"];
for i = 1:numel(required)
    if ~ismember(required(i), string(T.Properties.VariableNames))
        error("extract_keyword_evidence:MissingColumn", "Missing required column: %s", required(i));
    end
end

rows = cell(height(T), 8);
for i = 1:height(T)
    openalexId = string(T.openalex_id(i));
    workId = string(T.work_id(i));
    estatus = string(T.extract_status(i));
    body = string(T.body_text_excerpt(i));

    evidenceCount = int32(0);
    evidenceText = "";
    hitPositions = "";
    msg = "";

    if (estatus == "ok" || estatus == "ok_python_fallback") && strlength(strtrim(body)) > 0
        cleaned = local_remove_references_and_notes(body);
        [snippets, pos] = local_find_contexts_lines(cleaned, q, opts.contextLines, opts.maxEvidencePerRow);
        if isempty(snippets)
            evidenceStatus = "not_found";
        else
            evidenceStatus = "found";
            evidenceCount = int32(numel(snippets));
            evidenceText = strjoin(snippets, " || ");
            hitPositions = strjoin(string(pos), "|");
        end
    elseif estatus ~= "ok"
        evidenceStatus = "skip_extract_status";
        msg = "extract_status=" + estatus;
    else
        evidenceStatus = "empty_body";
    end

    rows(i,:) = {openalexId, workId, q, evidenceStatus, evidenceCount, evidenceText, hitPositions, msg};
    log_progress(i, height(T), "evidence");
end

R = cell2table(rows, 'VariableNames', {
    'openalex_id','work_id','query','evidence_status','evidence_count','evidence_text','hit_positions','message'});

parent = fileparts(outputCsv);
if strlength(parent) > 0 && ~isfolder(parent)
    mkdir(parent);
end
local_write_csv_utf8_bom(R, outputCsv);

% M13: parallel JSONL output
outputJsonl = strrep(outputCsv, '.csv', '.jsonl');
write_jsonl(R, outputJsonl);

result = struct();
result.output_csv   = outputCsv;
result.output_jsonl = outputJsonl;
result.rows = int32(height(R));
result.found_rows = int32(nnz(R.evidence_status == "found"));
result.not_found_rows = int32(nnz(R.evidence_status == "not_found"));

log_info("keyword evidence done: rows=%d found=%d not_found=%d", result.rows, result.found_rows, result.not_found_rows);
log_info("output=%s", result.output_csv);
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
        local_obj_str(obj, 'work_id'), ...
        local_obj_str(obj, 'extract_status'), ...
        local_obj_str(obj, 'body_text_excerpt') ...
        };
end

T = cell2table(rows, 'VariableNames', {'openalex_id','work_id','extract_status','body_text_excerpt'});
T.openalex_id = string(T.openalex_id);
T.work_id = string(T.work_id);
T.extract_status = string(T.extract_status);
T.body_text_excerpt = string(T.body_text_excerpt);
end

function s = local_obj_str(obj, fieldName)
if isfield(obj, fieldName)
    s = string(obj.(fieldName));
else
    s = "";
end
end

function text = local_remove_references_and_notes(text)
% Remove the reference list and trailing boilerplate sections, keeping only the body text
%
% Cutoff (delete everything from this point on):
%   References / Bibliography / Acknowledg / Author contributions /
%   Conflict of interest / Competing interests / Funding / Data availability /
%   Supplementary / Ethics / Appendix
%
% Line-level exclusions (citation lines and DOI lines in the body text):
%   Reference lines starting with [number] / lines starting with doi:
text = string(text);
parts = splitlines(text);
keep = strings(0,1);

% Cutoff keywords (text after these is outside the main body)
cutoffPatterns = [
    "^references", "^bibliography", "^acknowledg", "^author contributions", ...
    "^author's contributions", "^conflict of interest", "^competing interests", ...
    "^funding", "^data availability", "^supplementary", "^ethics", ...
    "^appendix", "^supporting information", "^abbreviations"
];

for i = 1:numel(parts)
    line = strtrim(parts(i));
    low = lower(line);
    % Section cutoff check
    isCutoff = false;
    for k = 1:numel(cutoffPatterns)
        if ~isempty(regexp(char(low), char(cutoffPatterns(k)), 'once'))
            isCutoff = true;
            break;
        end
    end
    if isCutoff
        break;
    end
    % Exclude reference-numbered lines ([1] Authorname... format)
    if ~isempty(regexp(char(line), '^\[\d+\]', 'once'))
        continue;
    end
    % Exclude DOI lines
    if startsWith(low, "doi:")
        continue;
    end
    keep(end+1) = line; %#ok<AGROW>
end
text = strjoin(keep, " ");
text = regexprep(text, "\s+", " ");
text = strtrim(text);
end


% New policy: extract N lines before/after keyword (e.g. 2 lines)
function [snippets, positions] = local_find_contexts_lines(text, queryText, contextLines, maxN)
% Revised: case-insensitive search, extract N surrounding lines, deduplicate
lines = splitlines(string(text));
nLines = numel(lines);
hitIdx = [];
for i = 1:nLines
    if contains(lines(i), queryText, 'IgnoreCase', true)
        hitIdx(end+1) = i; %#ok<AGROW>
    end
end
if isempty(hitIdx)
    snippets = strings(0,1);
    positions = zeros(0,1);
    return;
end
snippets = strings(0,1);
positions = zeros(0,1);
for i = 1:numel(hitIdx)
    idx = hitIdx(i);
    s = max(1, idx - contextLines);
    e = min(nLines, idx + contextLines);
    snippet = strjoin(lines(s:e), " ");
    snippets(end+1) = snippet; %#ok<AGROW>
    positions(end+1) = idx; %#ok<AGROW>
end
% Deduplication
[snippets, ia] = unique(snippets, 'stable');
positions = positions(ia);
% Maximum count limit
if numel(snippets) > maxN
    snippets = snippets(1:maxN);
    positions = positions(1:maxN);
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
