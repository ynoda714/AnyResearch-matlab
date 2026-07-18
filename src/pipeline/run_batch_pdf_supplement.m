function result = run_batch_pdf_supplement(batchDir, opts)
% run_batch_pdf_supplement — Batch reprocessing for manual PDF supplement after Section 0b
%
% After running Section 0b, manually place the PDFs that could not be
%   result/batch/<id>/pdf_cache/manual/<workId>.pdf
% retrieved automatically, then just run this section (0c) to
% reprocess all affected runs at once.
%
% Processing steps (automatically applied to all affected runs):
%   1. Identify affected run_ids from batch_manual_pdf_queue.csv
%   2. Detect placed PDFs and update pdf_download_report
%   3. Extract PDF body text (extract_pdf_text_from_report)
%   4. Supplement title/abstract (supplement_title_abstract_from_pdf)
%   5. Extract keyword evidence (extract_keyword_evidence)
%   6. Build final integrated CSV (build_final_csv)
%   7. Merge best CSVs from all runs -> batch_final_integrated_supplemented.csv
%
% Arguments:
%   batchDir  — Target batch directory (e.g. "result/batch/20260316_100748")
%
% Options (inherited from batch mode settings):
%   query                     — Search query (for keyword evidence)
%   pdfTextMaxRows            — Maximum rows for PDF extraction
%   pdfTextMaxBodyChars       — Maximum body characters for PDF text
%   enableKeywordEvidence     — Enable keyword evidence extraction (default: true)
%   keywordContextLines       — Context lines before/after keyword evidence
%   maxEvidencePerRow         — Maximum keyword evidence items per paper
%
% Return values:
%   result.batch_dir                  — Target batch directory
%   result.supplemented_run_count     — Number of runs supplemented
%   result.detected_pdf_count         — Total number of manually placed PDFs detected
%   result.final_integrated_csv       — Merged final CSV (when generated)
%   result.manual_pdf_queue_csv       — Original queue CSV
%   result.remaining_queue_csv        — Queue with PDFs still missing (when generated)

arguments
    batchDir (1,1) string
    opts.query (1,1) string = ""
    opts.pdfTextMaxRows (1,1) double {mustBeInteger(opts.pdfTextMaxRows), mustBePositive(opts.pdfTextMaxRows)} = 200
    opts.pdfTextMaxBodyChars (1,1) double {mustBeInteger(opts.pdfTextMaxBodyChars), mustBePositive(opts.pdfTextMaxBodyChars)} = 100000
    opts.enableKeywordEvidence (1,1) logical = true
    opts.keywordContextLines (1,1) double {mustBeInteger(opts.keywordContextLines), mustBePositive(opts.keywordContextLines)} = 2
    opts.maxEvidencePerRow (1,1) double {mustBeInteger(opts.maxEvidencePerRow), mustBePositive(opts.maxEvidencePerRow)} = 3
end

thisDir = fileparts(mfilename('fullpath'));
addpath(thisDir);
addpath(fullfile(thisDir, '..', 'pdf'));
addpath(fullfile(thisDir, '..', 'util'));

if ~isfolder(batchDir)
    error("run_batch_pdf_supplement:BatchDirNotFound", "Batch directory not found: %s", batchDir);
end

manualQueueCsv = string(fullfile(batchDir, 'batch_manual_pdf_queue.csv'));
if ~isfile(manualQueueCsv)
    log_warn("batch_manual_pdf_queue.csv not found — no PDF queue: %s", manualQueueCsv);
    result = local_empty_result(batchDir, manualQueueCsv);
    return;
end

% ── Load queue CSV ──────────────────────────────────────────
Q = readtable(manualQueueCsv, "TextType", "string", "VariableNamingRule", "preserve", ...
    "Delimiter", ",", "ReadVariableNames", true);
requiredCols = ["run_id", "openalex_id", "local_path"];
for i = 1:numel(requiredCols)
    if ~ismember(requiredCols(i), string(Q.Properties.VariableNames))
        error("run_batch_pdf_supplement:MissingColumn", "Missing required column: %s", requiredCols(i));
    end
end

Q.local_path = strtrim(string(Q.local_path));
totalQueued = height(Q);

% ── Detect placed PDFs ─────────────────────────────────────────
pdfExists = arrayfun(@(p) isfile(p), Q.local_path);
nDetected = nnz(pdfExists);

if nDetected == 0
    log_info("No manual PDFs placed.");
    log_info("Placement path: %s", string(fullfile(batchDir, 'pdf_cache', 'manual', '<workId>.pdf')));
    log_info("Queue (%d items): %s", totalQueued, manualQueueCsv);
    result = local_empty_result(batchDir, manualQueueCsv);
    return;
end

log_info("Manual PDFs detected: %d / %d", nDetected, totalQueued);

% Affected run_ids (only runs with at least one placed PDF)
affectedQ = Q(pdfExists, :);
affectedRunIds = unique(string(affectedQ.run_id), 'stable');
log_info("Runs to supplement: %d", numel(affectedRunIds));

% Write queue entries where PDFs are still missing to the remaining list
remainingQ = Q(~pdfExists, :);
remainingPath = "";
if ~isempty(remainingQ)
    remainingPath = string(fullfile(batchDir, 'batch_manual_pdf_queue_remaining.csv'));
    local_write_csv_utf8_bom(remainingQ, remainingPath);
    log_info("Remaining queue (not placed): %d items \u2192 %s", height(remainingQ), remainingPath);
end

% ── Reprocess each affected run ───────────────────────────────────────
runsDir = string(fullfile(batchDir, 'runs'));
supplementedCount = 0;

for i = 1:numel(affectedRunIds)
    rid = affectedRunIds(i);
    runDir = string(fullfile(runsDir, rid));
    if ~isfolder(runDir)
        log_warn("[%d/%d] run dir not found, skipping: %s", i, numel(affectedRunIds), rid);
        continue;
    end

    log_progress(i, numel(affectedRunIds), "supplement-runs");

    intermediateDir = string(fullfile(runDir, 'intermediate'));
    pdfReportCsv    = string(fullfile(intermediateDir, 'pdf_download_report.csv'));
    normalizedWorksCsv = string(fullfile(intermediateDir, char("scoring" + "_input.csv")));

    if ~isfile(pdfReportCsv)
        log_warn("pdf_download_report.csv not found, skipping: %s", rid);
        continue;
    end
    if ~isfile(normalizedWorksCsv)
        log_warn("normalized works CSV not found, skipping: %s", rid);
        continue;
    end

    % Step A: Update pdf_download_report (manual PDF -> "downloaded")
    R = readtable(pdfReportCsv, "TextType", "string", "VariableNamingRule", "preserve", ...
        "Delimiter", ",", "ReadVariableNames", true);
    nMarked = 0;
    for j = 1:height(R)
        if ismember(string(R.status(j)), ["manual_required", "error"])
            lp = string(R.local_path(j));
            if strlength(lp) > 0 && isfile(lp)
                R.status(j) = "downloaded";
                R.message(j) = "manually_supplied";
                nMarked = nMarked + 1;
            end
        end
    end
    if nMarked == 0
        log_warn("run %s: no placed PDFs detected (possible run_id mismatch)", rid);
        continue;
    end
    log_info("run %s: marked %d PDF(s) as manually_supplied", rid, nMarked);

    updatedReportCsv = string(fullfile(intermediateDir, 'pdf_download_report_supplemented.csv'));
    local_write_csv_utf8_bom(R, updatedReportCsv);

    % Step B: Extract PDF body text
    pdfTextCsv   = string(fullfile(intermediateDir, 'pdf_text_extracted_supplemented.csv'));
    pdfTextJsonl = string(fullfile(intermediateDir, 'pdf_text_extracted_supplemented.jsonl'));
    pdfTextRes = struct();
    try
        pdfTextRes = extract_pdf_text_from_report( ...
            updatedReportCsv, pdfTextCsv, ...
            outputJsonl=pdfTextJsonl, ...
            maxRows=opts.pdfTextMaxRows, ...
            maxBodyChars=opts.pdfTextMaxBodyChars);
    catch ex
        log_warn("PDF text extraction failed (run %s): %s", rid, string(ex.message));
        continue;
    end

    pdfTextInput = "";
    if isfield(pdfTextRes, 'output_jsonl') && isfile(string(pdfTextRes.output_jsonl))
        pdfTextInput = string(pdfTextRes.output_jsonl);
    elseif isfield(pdfTextRes, 'output_csv') && isfile(string(pdfTextRes.output_csv))
        pdfTextInput = string(pdfTextRes.output_csv);
    end
    if pdfTextInput == ""
        log_warn("PDF text output empty, skipping: %s", rid);
        continue;
    end

    % Step C: Supplement title/abstract
    metadataCsv     = normalizedWorksCsv;
    supplementedCsv = string(fullfile(intermediateDir, char("scoring" + "_input_supplemented.csv")));
    try
        suppRes = supplement_title_abstract_from_pdf(normalizedWorksCsv, pdfTextInput, supplementedCsv);
        if isfield(suppRes, 'output_csv') && isfile(string(suppRes.output_csv))
            metadataCsv = string(suppRes.output_csv);
        end
    catch ex
        log_warn("Supplement failed (run %s): %s", rid, string(ex.message));
    end

    % Step D: Extract keyword evidence
    evidenceCsv = "";
    if opts.enableKeywordEvidence && strlength(strtrim(opts.query)) > 0
        evidenceOut = string(fullfile(intermediateDir, 'keyword_evidence_supplemented.csv'));
        try
            evRes = extract_keyword_evidence( ...
                pdfTextInput, evidenceOut, opts.query, ...
                contextLines=opts.keywordContextLines, ...
                maxEvidencePerRow=opts.maxEvidencePerRow);
            if isfield(evRes, 'output_csv') && isfile(string(evRes.output_csv))
                evidenceCsv = string(evRes.output_csv);
            end
        catch ex
            log_warn("Keyword evidence failed (run %s): %s", rid, string(ex.message));
        end
    end

    % Step E: Build final integrated CSV
    finalOutCsv = string(fullfile(intermediateDir, 'final_integrated_supplemented.csv'));
    finalRes = struct();
    try
        finalRes = build_final_csv( ...
            metadataCsv, finalOutCsv, opts.query, ...
            metadataCsv=metadataCsv, ...
            evidenceCsv=evidenceCsv, ...
            pdfReportCsv=updatedReportCsv);
    catch ex
        log_warn("build_final_csv failed (run %s): %s", rid, string(ex.message));
        continue;
    end

    supplementedCount = supplementedCount + 1;
end

fprintf('\n');  % Final newline after log_progress

% ── Merge best CSVs from all runs ───────────────────────────────────
candidateNames = [
    "final_integrated_supplemented.csv"
    "final_integrated.csv"
];

finalTables = cell(0,1);
if isfolder(runsDir)
    runEntries = dir(runsDir);
    runEntries = runEntries([runEntries.isdir] & ~ismember({runEntries.name}, {'.','..'}));

    for i = 1:numel(runEntries)
        rid = string(runEntries(i).name);
        intDir = string(fullfile(runsDir, rid, 'intermediate'));
        chosen = "";
        for c = 1:numel(candidateNames)
            candidate = string(fullfile(intDir, candidateNames(c)));
            if isfile(candidate)
                chosen = candidate;
                break;
            end
        end
        if chosen == ""
            continue;
        end
        try
            T = readtable(chosen, "TextType", "string", "VariableNamingRule", "preserve", ...
                "Delimiter", ",", "ReadVariableNames", true);
            if ~ismember("run_id", string(T.Properties.VariableNames))
                T.run_id = repmat(rid, height(T), 1);
            end
            finalTables{end+1,1} = T; %#ok<AGROW>
        catch
        end
    end
end

mergedPath = "";
if ~isempty(finalTables)
    merged = local_vertcat_tables(finalTables);
    mergedPath = string(fullfile(batchDir, 'batch_final_integrated_supplemented.csv'));
    local_write_csv_utf8_bom(merged, mergedPath);
    log_info("Merged final CSV: %s (%d rows, %d institution runs)", ...
        mergedPath, height(merged), numel(finalTables));
end

% ── Result struct ───────────────────────────────────────────────
result = struct();
result.batch_dir              = batchDir;
result.supplemented_run_count = int32(supplementedCount);
result.detected_pdf_count     = int32(nDetected);
result.manual_pdf_queue_csv   = manualQueueCsv;
if mergedPath ~= ""
    result.final_integrated_csv = mergedPath;
end
if remainingPath ~= ""
    result.remaining_queue_csv = remainingPath;
end

log_info("Supplement complete: %d run(s) processed / %d manual PDF(s) detected", supplementedCount, nDetected);
if remainingPath ~= ""
    log_info("Remaining (not placed): %d item(s) \u2192 %s", height(remainingQ), remainingPath);
end

end

% ────────────────────────────────────────────────────────────
% Local functions
% ────────────────────────────────────────────────────────────

function result = local_empty_result(batchDir, manualQueueCsv)
result = struct();
result.batch_dir              = batchDir;
result.supplemented_run_count = int32(0);
result.detected_pdf_count     = int32(0);
result.manual_pdf_queue_csv   = manualQueueCsv;
end

function out = local_vertcat_tables(tbls)
if isempty(tbls)
    out = table();
    return;
end
allVars = strings(0,1);
for i = 1:numel(tbls)
    allVars = union(allVars, string(tbls{i}.Properties.VariableNames), 'stable');
end
norm = cell(size(tbls));
for i = 1:numel(tbls)
    T = tbls{i};
    for j = 1:numel(allVars)
        vn = allVars(j);
        if ~ismember(vn, string(T.Properties.VariableNames))
            T.(vn) = repmat("", height(T), 1);
        end
    end
    T = T(:, cellstr(allVars));
    norm{i} = T;
end
out = norm{1};
for i = 2:numel(norm)
    out = [out; norm{i}]; %#ok<AGROW>
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
