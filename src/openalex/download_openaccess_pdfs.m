function report = download_openaccess_pdfs(openalexCsv, pdfCacheDir, opts)
arguments
    openalexCsv (1,1) string
    pdfCacheDir (1,1) string
    opts.maxRows (1,1) double {mustBeInteger(opts.maxRows), mustBePositive(opts.maxRows)} = 50
    opts.mailto (1,1) string = ""
    opts.timeoutSec (1,1) double {mustBePositive(opts.timeoutSec)} = 60
    opts.resumeReportCsv (1,1) string = ""
    opts.retryPending (1,1) logical = true
    opts.reportCsvPath (1,1) string = ""  % If empty, defaults to pdfCacheDir/pdf_download_report.csv
end

if ~isfile(openalexCsv)
    error("download_openaccess_pdfs:InputNotFound", "OpenAlex CSV not found: %s", openalexCsv);
end

T = readtable(openalexCsv, "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",", "ReadVariableNames", true);
if ~ismember("openalex_id", string(T.Properties.VariableNames))
    error("download_openaccess_pdfs:MissingOpenAlexId", "openalex_id column is required.");
end

n = min(height(T), opts.maxRows);
autoDir = string(fullfile(pdfCacheDir, 'auto'));
manualDir = string(fullfile(pdfCacheDir, 'manual'));
if ~isfolder(autoDir), mkdir(autoDir); end
if ~isfolder(manualDir), mkdir(manualDir); end

resumeTbl = table();
hasResume = false;
if opts.resumeReportCsv ~= "" && isfile(opts.resumeReportCsv)
    resumeTbl = readtable(opts.resumeReportCsv, "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",", "ReadVariableNames", true);
    requiredResumeCols = ["openalex_id","status","local_path"];
    if all(ismember(requiredResumeCols, string(resumeTbl.Properties.VariableNames)))
        hasResume = true;
    end
end

rows = cell(n, 7);
for i = 1:n
    oid = string(T.openalex_id(i));
    wid = local_work_id(oid);

    if hasResume
        prevIdx = find(string(resumeTbl.openalex_id) == oid, 1, 'first');
        if ~isempty(prevIdx)
            prevStatus = string(resumeTbl.status(prevIdx));
            prevPath = string(resumeTbl.local_path(prevIdx));
            if strlength(strtrim(prevPath)) > 0 && isfile(prevPath)
                rows(i,:) = {oid, wid, local_resume_pdf_url(resumeTbl, prevIdx), "downloaded", prevPath, "reused_existing_local_pdf", string(datetime('now','Format','yyyy-MM-dd''T''HH:mm:ss'))};
                log_progress(i, n, "pdf-download");
                continue;
            end
            if ~opts.retryPending && any(prevStatus == ["manual_required","error"])
                pendingPath = prevPath;
                if strlength(strtrim(pendingPath)) == 0
                    pendingPath = string(fullfile(manualDir, wid + ".pdf"));
                end
                rows(i,:) = {oid, wid, local_resume_pdf_url(resumeTbl, prevIdx), prevStatus, pendingPath, "kept_pending_from_resume_report", string(datetime('now','Format','yyyy-MM-dd''T''HH:mm:ss'))};
                log_progress(i, n, "pdf-download");
                continue;
            end
        end
    end

    workUrl = "https://api.openalex.org/works/" + wid;
    if opts.mailto ~= ""
        workUrl = workUrl + "?mailto=" + string(urlencode(char(opts.mailto)));
    end

    pdfUrl = "";
    msg = "";

    try
        w = webread(workUrl, weboptions('Timeout', opts.timeoutSec));
        pdfUrl = local_pick_pdf_url(w);
        if pdfUrl ~= ""
            localPath = string(fullfile(autoDir, wid + ".pdf"));
            websave(localPath, pdfUrl, weboptions('Timeout', opts.timeoutSec));
            % --- M12: Immediate post-download validation ---
            vr = validate_pdf_quality(localPath);
            if vr.status == "valid"
                status = "downloaded";
            else
                status = string(vr.status);
                msg = string(vr.message);
            end
        else
            status = "manual_required";
            localPath = string(fullfile(manualDir, wid + ".pdf"));
            msg = "Open access PDF URL not found";
        end
    catch ex
        localPath = string(fullfile(manualDir, wid + ".pdf"));
        % --- M12: HTTP error detection ---
        if contains(string(ex.message), ["404","403","500","502","503"])
            status = "failed_auto_http";
        else
            status = "error";
        end
        msg = string(ex.message);
    end

    rows(i,:) = {oid, wid, pdfUrl, status, localPath, msg, string(datetime('now','Format','yyyy-MM-dd''T''HH:mm:ss'))};
    log_progress(i, n, "pdf-download");
end

reportTbl = cell2table(rows, 'VariableNames', {'openalex_id','work_id','pdf_url','status','local_path','message','timestamp'});
if opts.reportCsvPath ~= ""
    reportPath = opts.reportCsvPath;
else
    reportPath = string(fullfile(pdfCacheDir, 'pdf_download_report.csv'));
end
reportDir = fileparts(reportPath);
if strlength(reportDir) > 0 && ~isfolder(reportDir)
    mkdir(reportDir);
end
local_write_csv_utf8_bom(reportTbl, reportPath);

% M13: JSONL parallel output
reportJsonl = strrep(reportPath, '.csv', '.jsonl');
write_jsonl(reportTbl, reportJsonl);

report = struct();
report.report_csv   = reportPath;
report.report_jsonl = reportJsonl;
report.checked_rows = int32(n);
report.downloaded_count = int32(nnz(reportTbl.status == "downloaded"));
report.manual_required_count = int32(nnz(reportTbl.status == "manual_required"));
report.error_count = int32(nnz(reportTbl.status == "error"));
report.failed_auto_0kb_count = int32(nnz(reportTbl.status == "failed_auto_0kb"));
report.failed_auto_corrupt_count = int32(nnz(reportTbl.status == "failed_auto_corrupt"));
report.failed_auto_http_count = int32(nnz(reportTbl.status == "failed_auto_http"));

log_info("pdf download done: checked=%d downloaded=%d manual=%d error=%d 0kb=%d corrupt=%d http=%d", ...
    report.checked_rows, report.downloaded_count, report.manual_required_count, report.error_count, ...
    report.failed_auto_0kb_count, report.failed_auto_corrupt_count, report.failed_auto_http_count);
end

function url = local_resume_pdf_url(tbl, idx)
if ismember("pdf_url", string(tbl.Properties.VariableNames))
    url = string(tbl.pdf_url(idx));
else
    url = "";
end
end

function wid = local_work_id(openalexId)
text = string(openalexId);
text = strtrim(text);
if startsWith(text, "https://openalex.org/")
    wid = extractAfter(text, "https://openalex.org/");
else
    wid = text;
end
wid = strrep(wid, "/", "_");
end

function url = local_pick_pdf_url(work)
url = "";
if isfield(work, 'primary_location') && ~isempty(work.primary_location)
    p = work.primary_location;
    if isfield(p, 'pdf_url') && ~isempty(p.pdf_url)
        url = string(p.pdf_url);
        return;
    end
    if isfield(p, 'landing_page_url') && ~isempty(p.landing_page_url)
        cand = string(p.landing_page_url);
        if endsWith(lower(cand), ".pdf")
            url = cand;
            return;
        end
    end
end
if isfield(work, 'open_access') && ~isempty(work.open_access)
    oa = work.open_access;
    if isfield(oa, 'oa_url') && ~isempty(oa.oa_url)
        cand = string(oa.oa_url);
        if endsWith(lower(cand), ".pdf")
            url = cand;
            return;
        end
    end
end
if isfield(work, 'best_oa_location') && ~isempty(work.best_oa_location)
    b = work.best_oa_location;
    if isfield(b, 'pdf_url') && ~isempty(b.pdf_url)
        url = string(b.pdf_url);
        return;
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
