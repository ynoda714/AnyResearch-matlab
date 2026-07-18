function result = run_pipeline(query, fromDate, toDate, options)
%RUN_PIPELINE  AnyResearch pipeline execution core (Layer 0-3 integrated).
%
%   Orchestration function responsible for all processing in a single search.
%   Called from front-end scripts (main_run_pipeline.m / main_run_batch.m).
%
%   Usage:
%     result = run_pipeline(query)
%     result = run_pipeline(query, fromDate, toDate)
%     result = run_pipeline(query, fromDate, toDate, Name=Value, ...)
%
%   [Required arguments]
%     query    : Search query string
%     fromDate : Start date "YYYY-MM-DD" (optional)
%     toDate   : End date "YYYY-MM-DD" (optional)
%
%   [Name=Value options — Layer 0: Search filters]
%     language                  : Language code (default: "en")
%     requireOpenAccess         : OA filter (default: true)
%     filterCountryCode         : Country code filter (default: "")
%     firstAuthorInstitution    : Institution name filter (default: "")
%     firstAuthorInstitutionId  : Institution ID filter(s) (default: "")
%     firstAuthorInstitutionAliases : Institution name aliases (default: strings(0,1))
%     sortBy                    : Sort order (default: "") e.g. "cited_by_count:desc" / "publication_date:desc" / "relevance_score"
%     filterType                : Document type filter (default: "") e.g. "article" / "review" / "article,review"
%     citedByMin                : Minimum cited_by_count filter (default: 0 = disabled)
%     citedByMax                : Maximum cited_by_count filter (default: 0 = disabled)
%     seedId                    : Seed DOI or OpenAlex Work ID for snowball mode (default: "")
%     snowballMode              : "citing" / "referenced" (default: "citing")
%     topN                      : Top N papers/journals to include in the Summary sheet (default: 10)
%     enableBibtex              : Enable additional BibTeX (.bib) / RIS (.ris) output (default: false)
%
%   [Name=Value options — Layer 0: Advanced parameters (use defaults)]
%     maxPages                     : Maximum pages (default: 10)
%     candidateMaxPages            : Maximum candidate pages (default: 10)
%     maxRowsForValidation         : Maximum rows for validation (default: 0 = unlimited)
%     samplingMode                 : Sampling mode (default: "head")
%     mailto                       : Email address for OpenAlex polite pool (default: "")
%     firstAuthorFilterMode        : Author filter mode (default: "two_stage")
%     resolveInstitutionIds        : Resolve institution IDs from the institution name at run time (default: true)
%     autoResolveInstitutionIds    : Automatically resolve institution IDs (default: false)
%     institutionResolveTimeoutSec : Institution ID resolution timeout in seconds (default: 30)
%     showCountPreview             : Show count preview (default: true)
%     runRootDir                   : Root directory for run outputs (default: "result/runs")
%     appendToCandidates           : Append final results to the candidate ledger (default: false)
%     ledgerPath                   : Candidate ledger path used when appendToCandidates=true
%
%   [Name=Value options — Layer 1: PDF extension]
%     enablePdfDownload       : Enable PDF download (default: false)
%     enableKeywordEvidence   : Enable keyword evidence extraction (default: true)
%     pdfMaxRows              : Maximum rows for PDF download (default: 20)
%     pdfTimeoutSec           : PDF download timeout in seconds (default: 60)
%     resumePdfReportCsv      : CSV for resuming PDF download (default: "")
%     retryPendingPdf         : Retry pending PDFs (default: true)
%     enablePdfTextExtraction : Enable PDF text extraction (default: true)
%     pdfTextMaxRows          : Maximum rows for PDF text extraction (default: 200)
%     pdfTextMaxBodyChars     : Maximum body characters for PDF text (default: 100000)
%     maxEvidencePerRow       : Maximum keyword evidence items per row (default: 3)
%
%
%   [Return value] result struct
%     .run_id, .run_dir
%     .rows_fetched, .total_hits   (total_hits: only when count preview is fetched)
%     .search_results_xlsx / .jsonl / .csv  (when generated)

arguments
    query     (1,1) string
    fromDate  (1,1) string = ""
    toDate    (1,1) string = ""
    % ── Layer 0: Search filters ──────────────────────────────────────────
    options.language                        (1,1) string  = "en"
    options.requireOpenAccess               (1,1) logical = true
    options.requireAbstract                 (1,1) logical = true
    options.filterCountryCode               (1,1) string  = ""
    options.firstAuthorInstitution          (1,1) string  = ""
    options.firstAuthorInstitutionId                string  = strings(0,1)
    options.firstAuthorInstitutionAliases           string  = strings(0,1)
    options.sortBy                          (1,1) string  = ""
    options.filterType                      (1,1) string  = ""
    options.excludeRetracted                (1,1) logical = true
    options.citedByMin                      (1,1) double  = 0
    options.citedByMax                      (1,1) double  = 0
    options.seedId                          (1,1) string  = ""
    options.snowballMode                    (1,1) string  = "citing"
    % ── Layer 0: Excel output options ────────────────────────────────────────
    options.topN                            (1,1) double  = 10
    options.enableBibtex                    (1,1) logical = false
    % ── Layer 0: Advanced parameters ────────────────────────────────────────────────
    options.maxPages                        (1,1) double  = 10
    options.candidateMaxPages               (1,1) double  = 10
    options.maxRowsForValidation            (1,1) double  = 0   % 0 = unlimited
    options.samplingMode                    (1,1) string  = "head"
    options.mailto                          (1,1) string  = ""
    options.firstAuthorFilterMode           (1,1) string  = "two_stage"
    options.resolveInstitutionIds           (1,1) logical = true
    options.autoResolveInstitutionIds       (1,1) logical = false
    options.institutionResolveTimeoutSec    (1,1) double  = 30
    options.showCountPreview                (1,1) logical = true
    options.runRootDir                      (1,1) string  = "result/runs"
    options.saveRawResponses                (1,1) logical = true
    options.appendToCandidates              (1,1) logical = false
    options.ledgerPath                      (1,1) string  = "result/candidates/candidates.jsonl"
    % ── Layer 1: PDF extension ───────────────────────────────────────────
    options.enablePdfDownload               (1,1) logical = false
    options.enableKeywordEvidence           (1,1) logical = true
    options.pdfMaxRows                      (1,1) double  = 20
    options.pdfTimeoutSec                   (1,1) double  = 60
    options.resumePdfReportCsv              (1,1) string  = ""
    options.retryPendingPdf                 (1,1) logical = true
    options.enablePdfTextExtraction         (1,1) logical = true
    options.pdfTextMaxRows                  (1,1) double  = 200
    options.pdfTextMaxBodyChars             (1,1) double  = 100000
    options.maxEvidencePerRow               (1,1) double  = 3
    % ── arXiv extension ──────────────────────────────────────────────────
    options.useArxiv                        (1,1) logical = false
    options.arxivMaxResults                 (1,1) double  = 0   % 0 = auto (maxPages * 100)
end

%% Internal path setup
% mfilename('fullpath') → .../src/pipeline/run_pipeline
% fileparts x3 to reach the project root
thisDir     = fileparts(mfilename('fullpath'));   % src/pipeline/
srcDir      = fileparts(thisDir);                 % src/
projectRoot = fileparts(srcDir);                  % project root
local_addpath_all(projectRoot);

%% Input validation
if strlength(strtrim(query)) == 0 && strlength(strtrim(options.seedId)) == 0
    error('run_pipeline:InvalidInput', ...
        'query is empty. Please specify a search keyword or set seedId for snowball mode.');
end
local_validate_date_format(fromDate, 'fromDate');
local_validate_date_format(toDate, 'toDate');
% API Key check (config file or environment variable)
local_check_api_key(projectRoot);

%% Expand options
language                     = options.language;
requireOpenAccess            = options.requireOpenAccess;
requireAbstract              = options.requireAbstract;
filterCountryCode            = options.filterCountryCode;
firstAuthorInstitution       = options.firstAuthorInstitution;
firstAuthorInstitutionId     = normalize_openalex_ids(options.firstAuthorInstitutionId);
firstAuthorInstitutionAliases = options.firstAuthorInstitutionAliases;
excludeRetracted             = options.excludeRetracted;
citedByMin                   = options.citedByMin;
citedByMax                   = options.citedByMax;
seedId                       = strtrim(options.seedId);
snowballMode                 = lower(strtrim(options.snowballMode));
maxPages                     = options.maxPages;
candidateMaxPages            = options.candidateMaxPages;
maxRowsForValidation         = options.maxRowsForValidation;
samplingMode                 = options.samplingMode;
mailto                       = options.mailto;
firstAuthorFilterMode        = options.firstAuthorFilterMode;
resolveInstitutionIds        = options.resolveInstitutionIds;
autoResolveInstitutionIds    = options.autoResolveInstitutionIds;
institutionResolveTimeoutSec = options.institutionResolveTimeoutSec;
showCountPreview             = options.showCountPreview;
saveRawResponses             = options.saveRawResponses;
appendToCandidates           = options.appendToCandidates;
ledgerPath                   = options.ledgerPath;
sortBy                       = options.sortBy;
filterType                   = options.filterType;
topN                         = options.topN;
enableBibtex                 = options.enableBibtex;
enablePdfDownload            = options.enablePdfDownload;
enableKeywordEvidence        = options.enableKeywordEvidence;
pdfMaxRows                   = options.pdfMaxRows;
pdfTimeoutSec                = options.pdfTimeoutSec;
resumePdfReportCsv           = options.resumePdfReportCsv;
retryPendingPdf              = options.retryPendingPdf;
enablePdfTextExtraction      = options.enablePdfTextExtraction;
pdfTextMaxRows               = options.pdfTextMaxRows;
pdfTextMaxBodyChars          = options.pdfTextMaxBodyChars;
maxEvidencePerRow            = options.maxEvidencePerRow;
useArxiv                     = options.useArxiv;
arxivMaxResults              = options.arxivMaxResults;

% PDF downstream steps require pdf_download to be enabled
if ~enablePdfDownload
    enablePdfTextExtraction = false;
    enableKeywordEvidence   = false;
end

% runRootDir: resolve relative paths relative to the project root
runRootDir = options.runRootDir;
if ~is_absolute_path(runRootDir)
    runRootDir = string(fullfile(char(projectRoot), char(runRootDir)));
end

%% Create execution context
ctx = create_run_context(runRootDir);
log_info("run_id=%s", ctx.run_id);
log_info("run_dir=%s", ctx.run_dir);
if seedId ~= ""
    log_info("seed_id=%s", seedId);
    log_info("snowball_mode=%s", snowballMode);
else
    log_info("query=%s", query);
end

%% Resolve institution IDs
resolvedInstitutionIds = strings(0,1);
if autoResolveInstitutionIds
    resolveInstitutionIds = true;
end
if resolveInstitutionIds && strlength(strtrim(firstAuthorInstitution)) > 0
    [firstAuthorInstitutionId, resolvedInstitutionIds] = resolve_institution_ids( ...
        firstAuthorInstitution, firstAuthorInstitutionId, firstAuthorInstitutionAliases, institutionResolveTimeoutSec);
elseif ~isempty(firstAuthorInstitutionId)
    resolvedInstitutionIds = normalize_openalex_ids(firstAuthorInstitutionId);
end

%% Build filter & write settings JSON
filterText = build_openalex_filter( ...
    fromDate, toDate, language, requireOpenAccess, resolvedInstitutionIds, filterCountryCode, filterType, requireAbstract, excludeRetracted, citedByMin, citedByMax);
overrideSettingsJson = string(fullfile(ctx.logs_dir, 'settings_front_override.json'));
local_write_front_settings_json( ...
    overrideSettingsJson, query, filterText, maxPages, candidateMaxPages, maxRowsForValidation, ...
    samplingMode, mailto, firstAuthorInstitution, firstAuthorInstitutionId, ...
    resolvedInstitutionIds, firstAuthorInstitutionAliases, firstAuthorFilterMode, sortBy, ...
    local_load_api_key_string());

log_info("filter=%s", filterText);
if strlength(strtrim(firstAuthorInstitution)) > 0
    log_info("firstAuthorInstitution=%s", firstAuthorInstitution);
    log_info("firstAuthorInstitutionId=%s", strjoin(string(firstAuthorInstitutionId), " | "));
    if ~isempty(resolvedInstitutionIds)
        log_info("resolvedInstitutionIds=%s", strjoin(resolvedInstitutionIds, " | "));
    end
    log_info("firstAuthorFilterMode=%s candidateMaxPages=%d", firstAuthorFilterMode, candidateMaxPages);
end

%% Layer 0: Count preview
totalHits = int32(-1);
if showCountPreview && seedId == ""
    try
        previewRes = fetch_and_normalize_works(overrideSettingsJson, dryRun=true);
        totalHits = int32(previewRes.total_count);
        log_info("Total papers (count preview): %d (%s to %s)", totalHits, fromDate, toDate);
        if totalHits > maxPages * 100
            log_warn("Large result set (maxPages=%d, perPage=100 \u2192 up to %d records). Consider narrowing the date range.", maxPages, maxPages * 100);
        end
    catch previewEx
        log_warn("Count preview failed (continuing): %s", previewEx.message);
    end
end

%% Layer 0: Fetch from OpenAlex API
try
    if seedId == ""
        apiRes = fetch_and_normalize_works( ...
            overrideSettingsJson, ...
            outputRawCsv=ctx.openalex_raw_csv, ...
            outputNormalizedWorksCsv=ctx.normalized_works_csv, ...
            saveRawResponses=saveRawResponses, ...
            rawResponseDir=ctx.raw_dir);
    else
        apiRes = local_fetch_seed_mode( ...
            seedId, snowballMode, filterText, sortBy, maxPages, ctx, saveRawResponses, mailto);
    end
catch ex
    % Zero-result queries: return gracefully with empty outputs instead of failing
    zeroIds = ["fetch_and_normalize_works:NoRows", ...
                "fetch_and_normalize_works:NoValidRows"];
    if any(strcmp(ex.identifier, zeroIds))
        log_warn("Zero results returned (query=%s). Generating empty outputs.", query);
        % Write empty JSONL / CSV
        fid = fopen(ctx.search_results_jsonl, 'w'); fclose(fid);
        fid = fopen(ctx.search_results_csv,   'w'); fclose(fid);
        % Write minimal xlsx (empty)
        try
            emptyCfg = struct();
            emptyCfg.run_id = ctx.run_id;
            emptyCfg.run_dir = ctx.run_dir;
            emptyCfg.rows_fetched = int32(0);
            emptyCfg.query = query;
            emptyCfg.created_at = string(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
            export_excel_workbook(ctx.search_results_jsonl, ctx.search_results_xlsx, emptyCfg);
        catch xlsEx
            log_warn("Failed to write empty xlsx (continuing): %s", xlsEx.message);
        end
        % Write run_meta.json
        zeroMeta = local_make_base_run_meta( ...
            ctx, query, filterText, sortBy, filterType, ...
            firstAuthorInstitution, resolvedInstitutionIds, useArxiv, seedId, snowballMode);
        zeroMeta.steps = struct( ...
            'openalex_fetch',      struct('status', 'ok_zero'), ...
            'arxiv_fetch',         struct('status', 'skipped'), ...
            'pdf_download',        struct('status', 'skipped'), ...
            'pdf_text_extraction', struct('status', 'skipped'), ...
            'keyword_evidence',    struct('status', 'skipped'));
zeroMeta.outputs = struct();
        write_run_meta(ctx.run_meta_json, zeroMeta);
        log_info("run_meta saved: %s", ctx.run_meta_json);
        % Build and return result struct
        result             = struct();
        result.run_id      = ctx.run_id;
        result.run_dir     = ctx.run_dir;
        result.rows_fetched = int32(0);
        result.T = table();
        if totalHits >= 0
            result.total_hits = totalHits;
        end
        if isfile(ctx.search_results_xlsx)
            result.search_results_xlsx = ctx.search_results_xlsx;
        end
        result.search_results_jsonl = ctx.search_results_jsonl;
        result.search_results_csv   = ctx.search_results_csv;
        return;
    end
    failMeta = struct();
    failMeta.run_id                   = ctx.run_id;
    failMeta.run_dir                  = ctx.run_dir;
    failMeta.mode                     = "pipeline";
    failMeta.status                   = "failed";
    failMeta.query                    = query;
    failMeta.seed_id                  = seedId;
    failMeta.snowball_mode            = snowballMode;
    failMeta.filter                   = filterText;
    failMeta.first_author_institution = firstAuthorInstitution;
    failMeta.first_author_institution_ids = strjoin(resolvedInstitutionIds, " | ");
    failMeta.error_id                 = string(ex.identifier);
    failMeta.error_message            = string(ex.message);
    failMeta.hint                     = "Try broadening query / date range / firstAuthorInstitution and re-run.";
    failMeta.created_at               = string(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
    write_run_meta(ctx.run_meta_json, failMeta);
    log_error("run_pipeline stopped: %s", string(ex.message));
    log_info("run_meta (failed) saved: %s", ctx.run_meta_json);
    rethrow(ex);
end

%% arXiv: fetch & merge (useArxiv=true)
arxivRes = struct();
T_current = apiRes.normalized_works_table;
if useArxiv
    arxivMax = arxivMaxResults;
    if arxivMax <= 0
        arxivMax = maxPages * 100;
    end
    log_info("Fetching arXiv (maxResults=%d) ...", arxivMax);
    try
        arxivRaw = fetch_arxiv_works( ...
            searchQuery=query, fromDate=fromDate, toDate=toDate, maxResults=arxivMax, ...
            saveRawResponse=saveRawResponses, rawResponsePath=ctx.arxiv_raw_xml);
        arxivRes.fetched_count = height(arxivRaw);
        if height(arxivRaw) > 0
            T_arxiv = arxiv_to_normalized_works(arxivRaw);
            T_oa    = T_current;
            % Dedup: drop arXiv rows whose doi_normalized is already in OA results
            if ismember("doi_normalized", T_oa.Properties.VariableNames) && ...
                    ismember("doi_normalized", T_arxiv.Properties.VariableNames)
                hasArxivDoi = strlength(T_arxiv.doi_normalized) > 0;
                isDuplicate = hasArxivDoi & ismember(T_arxiv.doi_normalized, T_oa.doi_normalized);
                T_arxiv     = T_arxiv(~isDuplicate, :);
            end
            log_info("arXiv: fetched=%d  new_after_dedup=%d", height(arxivRaw), height(T_arxiv));
            if height(T_arxiv) > 0
                T_arxiv   = local_align_table(T_arxiv, T_oa);
                T_merged  = [T_oa; T_arxiv];
                mergedCsv = string(fullfile(ctx.intermediate_dir, char("scoring" + "_input_merged.csv")));
                local_write_csv_utf8_bom(T_merged, mergedCsv);
                apiRes.normalized_works_csv = mergedCsv;
                apiRes.normalized_works_table = T_merged;
                apiRes.rows              = height(T_merged);
                arxivRes.merged_csv      = mergedCsv;
                arxivRes.added_rows      = height(T_arxiv);
                T_current                = T_merged;
                log_info("arXiv merged: +%d rows -> total %d", height(T_arxiv), height(T_merged));
            end
        else
            log_info("arXiv: 0 results returned (query=%s)", query);
        end
    catch arxivEx
        log_warn("arXiv fetch failed (continuing): %s", arxivEx.message);
    end
end

%% Layer 1: Download PDFs
pdfRes = struct();
if enablePdfDownload
    pdfRes = download_openaccess_pdfs( ...
        apiRes.openalex_raw_csv, ...
        ctx.pdf_cache_dir, ...
        maxRows=pdfMaxRows, ...
        mailto=mailto, ...
        timeoutSec=pdfTimeoutSec, ...
        resumeReportCsv=resumePdfReportCsv, ...
        retryPending=retryPendingPdf);
end

%% Layer 1: Extract PDF text
pdfTextRes = struct();
if enablePdfTextExtraction && isfield(pdfRes, 'report_csv') ...
        && strlength(string(pdfRes.report_csv)) > 0 && isfile(string(pdfRes.report_csv))
    pdfTextOutCsv   = string(fullfile(ctx.intermediate_dir, 'pdf_text_extracted.csv'));
    pdfTextOutJsonl = string(fullfile(ctx.intermediate_dir, 'pdf_text_extracted.jsonl'));
    pdfTextRes = extract_pdf_text_from_report( ...
        string(pdfRes.report_csv), ...
        pdfTextOutCsv, ...
        outputJsonl=pdfTextOutJsonl, ...
        maxRows=pdfTextMaxRows, ...
        maxBodyChars=pdfTextMaxBodyChars);
end

%% Layer 1: Extract keyword evidence / Supplement title and abstract from PDF
pdfTextInputForDownstream = "";
if isfield(pdfTextRes, 'output_jsonl') && strlength(string(pdfTextRes.output_jsonl)) > 0 ...
        && isfile(string(pdfTextRes.output_jsonl))
    pdfTextInputForDownstream = string(pdfTextRes.output_jsonl);
elseif isfield(pdfTextRes, 'output_csv') && strlength(string(pdfTextRes.output_csv)) > 0 ...
        && isfile(string(pdfTextRes.output_csv))
    pdfTextInputForDownstream = string(pdfTextRes.output_csv);
end

evidenceRes = struct();
if enableKeywordEvidence && pdfTextInputForDownstream ~= ""
    evidenceOutCsv = string(fullfile(ctx.intermediate_dir, 'keyword_evidence.csv'));
    evidenceRes = extract_keyword_evidence( ...
        pdfTextInputForDownstream, ...
        evidenceOutCsv, ...
        query, ...
        contextLines=2, ...
        maxEvidencePerRow=maxEvidencePerRow);
end

supplementRes = struct();
if pdfTextInputForDownstream ~= ""
    supplementRes = supplement_title_abstract_from_pdf_table( ...
        T_current, ...
        pdfTextInputForDownstream, ...
        outputCsv=ctx.normalized_works_supplemented_csv);
end

%% Build final integrated table
baseTableForFinal = T_current;
if isfield(supplementRes, 'T') && istable(supplementRes.T)
    baseTableForFinal = supplementRes.T;
end

evidenceTableForFinal = table();
if isfield(evidenceRes, 'output_csv') && strlength(string(evidenceRes.output_csv)) > 0 ...
        && isfile(string(evidenceRes.output_csv))
    evidenceTableForFinal = readtable(string(evidenceRes.output_csv), ...
        "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",", "ReadVariableNames", true);
end

pdfReportTableForFinal = table();
if isfield(pdfRes, 'report_csv') && strlength(string(pdfRes.report_csv)) > 0 ...
        && isfile(string(pdfRes.report_csv))
    pdfReportTableForFinal = readtable(string(pdfRes.report_csv), ...
        "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",", "ReadVariableNames", true);
end

finalRes = build_final_table( ...
    baseTableForFinal, ...
    query, ...
    metadataTable=baseTableForFinal, ...
    evidenceTable=evidenceTableForFinal, ...
    pdfReportTable=pdfReportTableForFinal, ...
    outputCsv=ctx.final_integrated_csv);

%% Output artifacts (search_results.xlsx / .jsonl / .csv)
finalCsvForArtifact = local_safe_field(finalRes, 'output_csv');
finalTableForArtifact = table();
if isfield(finalRes, 'T') && istable(finalRes.T)
    finalTableForArtifact = finalRes.T;
end

if height(finalTableForArtifact) > 0 || (strlength(finalCsvForArtifact) > 0 && isfile(finalCsvForArtifact))
    % search_results.csv
    try
        local_write_csv_utf8_bom(finalTableForArtifact, ctx.search_results_csv);
    catch cpEx
        log_warn("Failed to copy search_results.csv (continuing): %s", cpEx.message);
    end

    % search_results.jsonl
    try
        write_jsonl(finalTableForArtifact, ctx.search_results_jsonl);
    catch jEx
        log_warn("Failed to generate search_results.jsonl (continuing): %s", jEx.message);
    end

    % search_results.mat
    try
        T = finalTableForArtifact; %#ok<NASGU>
        save(ctx.search_results_mat, 'T');
    catch matEx
        log_warn("Failed to save search_results.mat (continuing): %s", matEx.message);
    end

    % search_results.xlsx
    xlsCfg            = struct();
    xlsCfg.query      = query;
    xlsCfg.from_date  = fromDate;
    xlsCfg.to_date    = toDate;
    xlsCfg.filter     = filterText;
    xlsCfg.run_id     = ctx.run_id;
    xlsCfg.run_dir    = ctx.run_dir;
    xlsCfg.rows_fetched = int32(apiRes.rows);
    if totalHits >= 0
        xlsCfg.total_hits = totalHits;
    end
    xlsCfg.top_n      = topN;
    xlsCfg.created_at = string(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));

    xlsInPath = ctx.search_results_jsonl;
    if ~isfile(xlsInPath)
        xlsInPath = finalCsvForArtifact;
    end
    try
        export_excel_workbook(xlsInPath, ctx.search_results_xlsx, xlsCfg);
    catch xlsEx
        log_warn("Failed to generate search_results.xlsx (continuing): %s", xlsEx.message);
    end

    log_info("search_results: csv=%s",  ctx.search_results_csv);
    log_info("search_results: jsonl=%s", ctx.search_results_jsonl);
    log_info("search_results: xlsx=%s",  ctx.search_results_xlsx);

    % Generate BibTeX / RIS (only when enableBibtex is set)
    if enableBibtex && isfile(ctx.search_results_jsonl)
        try
            export_bibtex(ctx.search_results_jsonl, ctx.run_dir);
        catch bibEx
            log_warn("Failed to generate BibTeX/RIS (continuing): %s", bibEx.message);
        end
    end
else
    log_warn("Final integrated CSV not found; search_results.* could not be generated");
end

candidateRes = struct();
if appendToCandidates && isfile(ctx.search_results_jsonl)
    try
        candidateRes = append_to_candidates(ctx.run_dir, ledgerPath=ledgerPath);
        candidateJsonl = string(candidateRes.ledger_path);
        candidateXlsx = strrep(candidateJsonl, ".jsonl", ".xlsx");
        candidateMd = string(fullfile(fileparts(char(candidateJsonl)), "repro_candidates.md"));
        export_candidates_xlsx(candidateJsonl, candidateXlsx);
        export_candidates_md(candidateJsonl, candidateMd);
        candidateRes.candidates_xlsx = candidateXlsx;
        candidateRes.candidates_md = candidateMd;
        log_info("candidate ledger updated: %s", candidateJsonl);
    catch candidateEx
        log_warn("Candidate ledger append failed (continuing): %s", candidateEx.message);
    end
end

%% Save run_meta.json
runMeta = local_make_base_run_meta( ...
    ctx, query, filterText, sortBy, filterType, ...
    firstAuthorInstitution, resolvedInstitutionIds, useArxiv, seedId, snowballMode);

steps                      = struct();
steps.openalex_fetch       = local_step_status(apiRes, 'openalex_raw_csv');
steps.arxiv_fetch          = local_step_status_optional(arxivRes, 'merged_csv', useArxiv);
steps.pdf_download         = local_step_status_optional(pdfRes, 'report_csv',  enablePdfDownload);
steps.pdf_text_extraction  = local_step_status_optional(pdfTextRes, 'output_csv', enablePdfTextExtraction);
steps.keyword_evidence     = local_step_status_optional(evidenceRes, 'output_csv', enableKeywordEvidence);
runMeta.steps              = steps;

outputs = struct();
outputs.openalex_raw_csv     = local_safe_field(apiRes, 'openalex_raw_csv');
outputs.normalized_works_csv = local_safe_field(apiRes, 'normalized_works_csv');
outputs.final_integrated_csv = local_safe_field(finalRes, 'output_csv');
if isfield(pdfRes, 'report_csv')
    outputs.pdf_download_report_csv = string(pdfRes.report_csv);
end
if isfield(pdfTextRes, 'output_jsonl')
    outputs.pdf_text_extracted_jsonl = string(pdfTextRes.output_jsonl);
end
if isfield(evidenceRes, 'output_csv')
    outputs.keyword_evidence_csv = string(evidenceRes.output_csv);
end
if isfile(ctx.search_results_xlsx)
    outputs.search_results_xlsx = ctx.search_results_xlsx;
end
if isfile(ctx.search_results_jsonl)
    outputs.search_results_jsonl = ctx.search_results_jsonl;
end
if isfile(ctx.search_results_csv)
    outputs.search_results_csv = ctx.search_results_csv;
end
if isfile(ctx.search_results_mat)
    outputs.search_results_mat = ctx.search_results_mat;
end
if isfield(candidateRes, 'ledger_path') && isfile(string(candidateRes.ledger_path))
    outputs.candidates_jsonl = string(candidateRes.ledger_path);
end
if isfield(candidateRes, 'candidates_xlsx') && isfile(string(candidateRes.candidates_xlsx))
    outputs.candidates_xlsx = string(candidateRes.candidates_xlsx);
end
if isfield(candidateRes, 'candidates_md') && isfile(string(candidateRes.candidates_md))
    outputs.candidates_md = string(candidateRes.candidates_md);
end
if isfield(arxivRes, 'merged_csv') && strlength(string(arxivRes.merged_csv)) > 0
    outputs.arxiv_merged_csv = string(arxivRes.merged_csv);
end
if saveRawResponses
    outputs.raw_dir = ctx.raw_dir;
    if isfile(ctx.arxiv_raw_xml)
        outputs.arxiv_raw_xml = ctx.arxiv_raw_xml;
    end
end
runMeta.outputs    = outputs;
runMeta.created_at = string(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));

write_run_meta(ctx.run_meta_json, runMeta);
log_info("run_meta saved: %s", ctx.run_meta_json);

%% Return value
result             = struct();
result.run_id      = ctx.run_id;
result.run_dir     = ctx.run_dir;
result.rows_fetched = int32(apiRes.rows);
result.T = finalTableForArtifact;
if totalHits >= 0
    result.total_hits = totalHits;
end
if saveRawResponses
    result.raw_dir = ctx.raw_dir;
end
if isfile(ctx.search_results_xlsx)
    result.search_results_xlsx = ctx.search_results_xlsx;
end
if isfile(ctx.search_results_jsonl)
    result.search_results_jsonl = ctx.search_results_jsonl;
end
if isfile(ctx.search_results_csv)
    result.search_results_csv = ctx.search_results_csv;
end
if isfile(ctx.search_results_mat)
    result.search_results_mat = ctx.search_results_mat;
end
if isfield(candidateRes, 'ledger_path') && isfile(string(candidateRes.ledger_path))
    result.candidates_jsonl = string(candidateRes.ledger_path);
end
if isfield(candidateRes, 'candidates_xlsx') && isfile(string(candidateRes.candidates_xlsx))
    result.candidates_xlsx = string(candidateRes.candidates_xlsx);
end
if isfield(candidateRes, 'candidates_md') && isfile(string(candidateRes.candidates_md))
    result.candidates_md = string(candidateRes.candidates_md);
end
end

% ── Local functions ──────────────────────────────────────────────────────────

function local_addpath_all(projectRoot)
dirs = {"src/util", "src/pipeline", "src/config", "src/openalex", ...
        "src/adapters", "src/pdf", "src/export"};
for i = 1:numel(dirs)
    p = fullfile(projectRoot, dirs{i});
    if isfolder(p)
        addpath(char(p));
    end
end
end

function local_write_front_settings_json( ...
        path, query, filterText, maxPages, candidateMaxPages, maxRowsForValidation, ...
        samplingMode, mailto, firstAuthorInstitution, firstAuthorInstitutionId, ...
        firstAuthorInstitutionIds, firstAuthorInstitutionAliases, firstAuthorFilterMode, sortBy, apiKey)
if nargin < 14
    sortBy = "";
end
if nargin < 15
    apiKey = "";
end
parentDir = fileparts(path);
if strlength(parentDir) > 0 && ~isfolder(parentDir)
    mkdir(parentDir);
end

s                                        = struct();
s.openalex                               = struct();
s.openalex.search_query                  = char(strtrim(string(query)));
s.openalex.filter                        = char(strtrim(string(filterText)));
s.openalex.sort                          = char(strtrim(string(sortBy)));
s.openalex.api_key                       = char(strtrim(string(apiKey)));
s.openalex.per_page                      = 100;
s.openalex.max_pages                     = round(maxPages);
s.openalex.candidate_max_pages           = round(candidateMaxPages);
s.openalex.max_rows_for_validation       = round(maxRowsForValidation);
s.openalex.sampling_mode                 = char(strtrim(string(samplingMode)));
s.openalex.random_seed                   = 42;
s.openalex.mailto                        = char(strtrim(string(mailto)));
s.openalex.first_author_institution      = char(strtrim(string(firstAuthorInstitution)));
s.openalex.first_author_institution_id   = '';
if ~isempty(firstAuthorInstitutionId)
    s.openalex.first_author_institution_id = char(firstAuthorInstitutionId(1));
end
if isempty(firstAuthorInstitutionIds)
    s.openalex.first_author_institution_ids = '';
else
    s.openalex.first_author_institution_ids = char(strjoin(string(firstAuthorInstitutionIds), " | "));
end
s.openalex.first_author_institution_aliases = char(strjoin(string(firstAuthorInstitutionAliases), " | "));
s.openalex.first_author_filter_mode      = char(strtrim(string(firstAuthorFilterMode)));

jsonText = jsonencode(s, PrettyPrint=true);

fid = fopen(path, 'w', 'n', 'UTF-8');
if fid < 0
    error("run_pipeline:WriteSettingsFailed", "Failed to write settings: %s", path);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, char(jsonText), 'char');
end

function meta = local_make_base_run_meta( ...
        ctx, query, filterText, sortBy, filterType, ...
        firstAuthorInstitution, resolvedInstitutionIds, useArxiv, seedId, snowballMode)
meta = struct();
meta.run_id                      = ctx.run_id;
meta.run_dir                     = ctx.run_dir;
meta.mode                        = "pipeline";
meta.status                      = "completed";
meta.query                       = query;
meta.filter                      = filterText;
meta.sort_by                     = sortBy;
meta.filter_type                 = filterType;
meta.first_author_institution    = firstAuthorInstitution;
meta.first_author_institution_ids = strjoin(resolvedInstitutionIds, " | ");
meta.use_arxiv                   = useArxiv;
meta.seed_id                     = seedId;
meta.snowball_mode               = snowballMode;
meta.created_at                  = string(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
end

function apiRes = local_fetch_seed_mode(seedId, snowballMode, filterText, sortBy, maxPages, ctx, saveRawResponses, mailto)
apiKey = local_load_api_key_string();
switch snowballMode
    case "citing"
        [openalexTbl, meta] = fetch_citing_works( ...
            seedId=seedId, ...
            filter=filterText, ...
            perPage=100, ...
            maxPages=maxPages, ...
            mailto=mailto, ...
            apiKey=apiKey, ...
            sort=sortBy, ...
            saveRawResponses=saveRawResponses, ...
            rawResponseDir=ctx.raw_dir);
    case "referenced"
        [openalexTbl, meta] = fetch_referenced_works( ...
            seedId=seedId, ...
            filter=filterText, ...
            perPage=100, ...
            maxPages=maxPages, ...
            mailto=mailto, ...
            apiKey=apiKey, ...
            sort=sortBy, ...
            saveRawResponses=saveRawResponses, ...
            rawResponseDir=ctx.raw_dir);
    otherwise
        error("run_pipeline:InvalidInput", ...
            "snowballMode must be ""citing"" or ""referenced"". Got: %s", snowballMode);
end

if height(openalexTbl) == 0
    error("fetch_and_normalize_works:NoRows", ...
        "No valid rows retrieved from OpenAlex seed traversal. mode=%s seed=%s", snowballMode, seedId);
end

normalizedWorks = openalex_to_normalized_works(openalexTbl, StrictValidation=false);
local_write_csv_utf8_bom(openalexTbl, ctx.openalex_raw_csv);
local_write_csv_utf8_bom(normalizedWorks, ctx.normalized_works_csv);
write_jsonl(openalexTbl, strrep(ctx.openalex_raw_csv, '.csv', '.jsonl'));
write_jsonl(normalizedWorks, strrep(ctx.normalized_works_csv, '.csv', '.jsonl'));

apiRes = struct();
apiRes.openalex_raw_csv = ctx.openalex_raw_csv;
apiRes.openalex_raw_jsonl = strrep(ctx.openalex_raw_csv, '.csv', '.jsonl');
apiRes.normalized_works_csv = ctx.normalized_works_csv;
apiRes.normalized_works_jsonl = strrep(ctx.normalized_works_csv, '.csv', '.jsonl');
apiRes.openalex_raw_table = openalexTbl;
apiRes.normalized_works_table = normalizedWorks;
apiRes.rows = height(normalizedWorks);
apiRes.pages = meta.pages;
apiRes.seed_id = string(seedId);
apiRes.seed_work_id = string(meta.seed_work_id);
apiRes.snowball_mode = string(snowballMode);
end

function apiKey = local_load_api_key_string()
apiKey = strtrim(string(getenv('ANYRESEARCH_OPENALEX_API_KEY')));
if apiKey ~= ""
    return;
end
thisDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(thisDir));
settingsPath = fullfile(projectRoot, 'config', 'settings.json');
if ~isfile(settingsPath)
    return;
end
raw = jsondecode(fileread(settingsPath));
if isfield(raw, 'openalex') && isfield(raw.openalex, 'api_key')
    apiKey = strtrim(string(raw.openalex.api_key));
end
end

function s = local_step_status(res, outputField)
s = struct();
if isstruct(res) && isfield(res, outputField) && strlength(string(res.(outputField))) > 0
    s.status = "ok";
else
    s.status = "error";
end
end

function s = local_step_status_optional(res, outputField, enabled)
s = struct();
if ~enabled
    s.status = "skipped";
    return;
end
if isstruct(res) && isfield(res, outputField) && strlength(string(res.(outputField))) > 0
    s.status = "ok";
else
    s.status = "error";
end
end

function v = local_safe_field(st, field)
v = "";
if isstruct(st) && isfield(st, field)
    v = string(st.(field));
end
end

function local_validate_date_format(dateStr, paramName)
% YYYY-MM-DD format check (empty string is allowed)
if strlength(strtrim(dateStr)) == 0
    return;
end
if isempty(regexp(strtrim(dateStr), '^\d{4}-\d{2}-\d{2}$', 'once'))
    error('run_pipeline:InvalidInput', ...
        '%s has an invalid date format: "%s". Please use YYYY-MM-DD format (e.g., "2023-01-01").', ...
        paramName, dateStr);
end
end

function T_out = local_align_table(T_src, T_ref)
% Reorder T_src columns to match T_ref column names and cast types as needed.
refCols = T_ref.Properties.VariableNames;
srcCols = T_src.Properties.VariableNames;
T_out   = T_src;
for ci = 1:numel(refCols)
    col = refCols{ci};
    if ~ismember(col, srcCols)
        if isa(T_ref.(col), 'double')
            T_out.(col) = nan(height(T_src), 1);
        elseif isa(T_ref.(col), 'logical')
            T_out.(col) = false(height(T_src), 1);
        else
            T_out.(col) = repmat("", height(T_src), 1);
        end
    end
    % Cast logical -> double to match CSV-loaded types (e.g., matlab_mentioned)
    if isa(T_out.(col), 'logical') && isa(T_ref.(col), 'double')
        T_out.(col) = double(T_out.(col));
    elseif isa(T_out.(col), 'double') && isa(T_ref.(col), 'logical')
        T_out.(col) = logical(T_out.(col));
    elseif isa(T_out.(col), 'string') && isa(T_ref.(col), 'double')
        T_out.(col) = str2double(T_out.(col));
    elseif isa(T_out.(col), 'string') && isa(T_ref.(col), 'logical')
        s = lower(strtrim(T_out.(col)));
        T_out.(col) = s == "1" | s == "true" | s == "yes";
    end
end
T_out = T_out(:, refCols);
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

function local_check_api_key(projectRoot)
% Verify OpenAlex API Key from config/settings.json or environment variable
apiKey = getenv('ANYRESEARCH_OPENALEX_API_KEY');
if strlength(apiKey) > 0
    return;  % Already configured via environment variable
end
settingsPath = fullfile(char(projectRoot), 'config', 'settings.json');
if ~isfile(settingsPath)
    error('run_pipeline:NoApiKey', ...
        'OpenAlex API Key is not configured.\n' + ...
        'Create config/settings.json and set openalex.api_key, or\n' + ...
        'set the environment variable ANYRESEARCH_OPENALEX_API_KEY.\n' + ...
        '(Get your API Key for free at https://openalex.org/settings/api)');
end
raw = jsondecode(fileread(settingsPath));
if ~isfield(raw, 'openalex') || ~isfield(raw.openalex, 'api_key') ...
        || strlength(strtrim(string(raw.openalex.api_key))) == 0
    error('run_pipeline:NoApiKey', ...
        'openalex.api_key is not set in config/settings.json.\n' + ...
        'Refer to config/settings.example.json to configure api_key.\n' + ...
        '(Get your API Key for free at https://openalex.org/settings/api)');
end
end
