function result = run_batch_from_institutions_list(institutionsCsv, query, fromDate, toDate, options)
%RUN_BATCH_FROM_INSTITUTIONS_LIST  Batch execution function for processing a list of institutions (v2.0.0)
%
%   Calls run_pipeline for each institution and generates per-institution
%   search_results.xlsx. Merges results across all institutions and outputs
%   batch_search_results.xlsx + batch_summary.csv.
%
%   Usage:
%     result = run_batch_from_institutions_list(institutionsCsv, query, fromDate, toDate)
%     result = run_batch_from_institutions_list(..., Name=Value, ...)
%
%   [Required arguments]
%     institutionsCsv : Institution list CSV path
%                       Legacy: Account, openalex_institution_id
%                       Reviewed v2: account, openalex_institution_id, include, role, ...
%     query           : Search query
%     fromDate        : Start date "YYYY-MM-DD" (optional)
%     toDate          : End date "YYYY-MM-DD" (optional)
%
%   [Return value] result struct
%     .batch_id, .batch_dir
%     .summary_csv
%     .batch_search_results_jsonl, .batch_search_results_xlsx
%     .candidates_jsonl / .xlsx / .md  (when appendToCandidates=true and generated)
%     .total_institutions, .success_count, .failed_count

arguments
    institutionsCsv (1,1) string = "data/list/institutions.csv"
    query           (1,1) string = ""
    fromDate        (1,1) string = ""
    toDate          (1,1) string = ""
    % ── Batch settings ──────────────────────────────────────────────────────────
    options.batchRootDir               (1,1) string  = "result/batch"
    % ── Layer 0: Search filters ─────────────────────────────────────────────
    options.language                   (1,1) string  = "en"
    options.requireOpenAccess          (1,1) logical = true
    options.filterCountryCode          (1,1) string  = ""
    options.sortBy                     (1,1) string  = ""
    options.filterType                 (1,1) string  = ""
    options.citedByMin                 (1,1) double  = 0
    options.citedByMax                 (1,1) double  = 0
    % ── Layer 0: Excel output options ──────────────────────────────────────
    options.topN                       (1,1) double  = 10
    % ── Layer 0: Advanced parameters (use defaults) ─────────────────────
    options.maxPages                   (1,1) double  = 10
    options.candidateMaxPages          (1,1) double  = 10
    options.firstAuthorFilterMode      (1,1) string  = "two_stage"
    % ── Layer 1: PDF extension ──────────────────────────────────────────────
    options.enablePdfDownload          (1,1) logical = false
    options.pdfMaxRows                 (1,1) double  = 20    % ── arXiv extension ─────────────────────────────────────────────────
    options.useArxiv                   (1,1) logical = false
    options.appendToCandidates         (1,1) logical = false
    options.ledgerPath                 (1,1) string  = "result/candidates/candidates.jsonl"
    options.dryRun                     (1,1) logical = false
end

%% Validation
if ~isfile(institutionsCsv)
    error("run_batch_from_institutions_list:InputNotFound", ...
        "institutions CSV not found: %s", institutionsCsv);
end

%% Path setup (same approach as run_pipeline)
thisDir     = fileparts(mfilename('fullpath'));   % src/pipeline/
srcDir      = fileparts(thisDir);                 % src/
projectRoot = fileparts(srcDir);                  % project root
local_addpath_all(projectRoot);

%% Load reviewed institution targets
try
    targets = load_institutions_list(institutionsCsv);
catch ex
    switch ex.identifier
        case "load_institutions_list:MissingColumn"
            error("run_batch_from_institutions_list:MissingColumn", "%s", ex.message);
        case "load_institutions_list:NoRows"
            error("run_batch_from_institutions_list:NoRows", "%s", ex.message);
        case "load_institutions_list:NoTargets"
            error("run_batch_from_institutions_list:NoRows", "%s", ex.message);
        case "load_institutions_list:InputNotFound"
            error("run_batch_from_institutions_list:InputNotFound", "%s", ex.message);
        otherwise
            rethrow(ex);
    end
end

%% Create batch directory
batchId  = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
batchDir = string(fullfile(options.batchRootDir, batchId));
if ~isfolder(batchDir)
    mkdir(batchDir);
end
batchRunsDir = string(fullfile(batchDir, "runs"));

overview = local_collect_target_overview(institutionsCsv, targets);
log_info("batch_id=%s  institutions=%d", batchId, height(targets));
local_log_target_overview(overview, targets);

%% Institution loop
summaryRows = cell(height(targets), 7);
finalTables = cell(0, 1);


for i = 1:height(targets)
    acc = string(targets.account(i));
    instIds = string(targets.institution_ids{i});
    instIdText = strjoin(instIds, "|");
    status      = "ok";
    errMsg      = "";
    rowsFetched = int32(0);
    runId       = "";

    log_progress(i, height(targets), "institutions");

    try
        if options.dryRun
            preview = local_preview_target(query, fromDate, toDate, instIds, options);
            status = "dry_run";
            errMsg = preview.filter_text;
            rowsFetched = int32(preview.total_hits);
            log_info("[DRYRUN][%s] total_hits=%d filter=%s", acc, rowsFetched, preview.filter_text);
        else
            r = run_pipeline(query, fromDate, toDate, ...
                firstAuthorInstitutionId=instIds, ...
                firstAuthorInstitution=acc, ...
                resolveInstitutionIds=false, ...
                showCountPreview=false, ...
                runRootDir=batchRunsDir, ...
                language=options.language, ...
                requireOpenAccess=options.requireOpenAccess, ...
                filterCountryCode=options.filterCountryCode, ...
                sortBy=options.sortBy, ...
                filterType=options.filterType, ...
                citedByMin=options.citedByMin, ...
                citedByMax=options.citedByMax, ...
                topN=options.topN, ...
                maxPages=options.maxPages, ...
                candidateMaxPages=options.candidateMaxPages, ...
                firstAuthorFilterMode=options.firstAuthorFilterMode, ...
                enablePdfDownload=options.enablePdfDownload, ...
                pdfMaxRows=options.pdfMaxRows, ...
                useArxiv=options.useArxiv, ...
                appendToCandidates=options.appendToCandidates, ...
                ledgerPath=options.ledgerPath);

            runId       = r.run_id;
            rowsFetched = int32(r.rows_fetched);

            % Determine JSONL for batch merge
            batchResultJsonl = "";
            if isfield(r, 'search_results_jsonl') ...
                    && isfile(r.search_results_jsonl)
                batchResultJsonl = r.search_results_jsonl;
            end

            % Append to batch merge table
            if batchResultJsonl ~= "" && isfile(batchResultJsonl)
                try
                    T = read_jsonl(batchResultJsonl);
                    T.target_institution_name            = repmat(acc,    height(T), 1);
                    T.target_openalex_institution_id     = repmat(instIdText, height(T), 1);
                    T.batch_id                           = repmat(batchId, height(T), 1);
                    T.run_id                             = repmat(runId,  height(T), 1);
                    finalTables{end+1, 1} = T; %#ok<AGROW>
                catch readEx
                    log_warn("[%s] Failed to read JSONL (skipping batch merge): %s", acc, readEx.message);
                end
            end
        end

    catch ex
        status = "failed";
        errMsg = string(ex.message);
        log_error("[%s] run_pipeline failed: %s", acc, errMsg);
    end

    summaryRows(i, :) = {batchId, runId, acc, instIdText, status, rowsFetched, errMsg};
end

%% Batch summary CSV output
summaryTbl = cell2table(summaryRows, 'VariableNames', { ...
    'batch_id', 'run_id', 'institution_name', 'openalex_institution_id', ...
    'status', 'rows_fetched', 'error_message'});
summaryPath = string(fullfile(batchDir, 'batch_summary.csv'));
local_write_csv_utf8_bom(summaryTbl, summaryPath);

%% Batch merged JSONL + Excel output
batchJsonlPath = "";
batchXlsxPath  = "";
if ~isempty(finalTables)
    finalAll       = local_vertcat_tables(finalTables);
    batchJsonlPath = string(fullfile(batchDir, 'batch_search_results.jsonl'));
    batchXlsxPath  = string(fullfile(batchDir, 'batch_search_results.xlsx'));
    try
        write_jsonl(finalAll, batchJsonlPath);
        batchXlsCfg = struct( ...
            'query',      char(query), ...
            'from_date',  char(fromDate), ...
            'to_date',    char(toDate), ...
            'run_id',     char(batchId), ...
            'created_at', char(string(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'))));
        export_excel_workbook(batchJsonlPath, batchXlsxPath, batchXlsCfg);
        log_info("batch_search_results.xlsx: %s", batchXlsxPath);
    catch bxEx
        log_warn("Failed to generate batch xlsx (continuing): %s", bxEx.message);
        batchXlsxPath  = "";
        batchJsonlPath = "";
    end

    % Cross-institution comparison sheet
    try
        write_batch_comparison_xlsx(finalAll, batchDir);
    catch cmpEx
        log_warn("Failed to generate batch_comparison.xlsx (continuing): %s", cmpEx.message);
    end
end

%% Return value
result = struct();
result.batch_id                   = batchId;
result.batch_dir                  = batchDir;
result.summary_csv                = summaryPath;
result.batch_search_results_jsonl = batchJsonlPath;
result.batch_search_results_xlsx  = batchXlsxPath;
result.dry_run                   = options.dryRun;
result.total_institutions = int32(height(targets));
result.success_count      = int32(nnz(string(summaryTbl.status) == "ok"));
result.failed_count       = int32(nnz(string(summaryTbl.status) == "failed"));
result.dry_run_count      = int32(nnz(string(summaryTbl.status) == "dry_run"));

if options.appendToCandidates
    ledgerJsonl = string(options.ledgerPath);
    ledgerXlsx = strrep(ledgerJsonl, ".jsonl", ".xlsx");
    ledgerMd = string(fullfile(fileparts(char(ledgerJsonl)), "repro_candidates.md"));
    if isfile(ledgerJsonl)
        result.candidates_jsonl = ledgerJsonl;
    end
    if isfile(ledgerXlsx)
        result.candidates_xlsx = ledgerXlsx;
    end
    if isfile(ledgerMd)
        result.candidates_md = ledgerMd;
    end
end

compXlsx = string(fullfile(batchDir, 'batch_comparison.xlsx'));
if isfile(compXlsx)
    result.batch_comparison_xlsx = compXlsx;
end

function overview = local_collect_target_overview(institutionsCsv, targets)
overview = struct();
overview.targets = int32(height(targets));
overview.total_ids = int32(sum(double(targets.n_ids)));
overview.multi_id_targets = int32(nnz(double(targets.n_ids) > 1));
overview.excluded_rows = int32(0);

opts = detectImportOptions(institutionsCsv, ...
    "VariableNamingRule", "preserve", ...
    "Delimiter", ",");
opts = setvartype(opts, opts.VariableNames, "string");
L = readtable(institutionsCsv, opts);
vars = string(L.Properties.VariableNames);

accountCol = local_find_column(vars, ["account", "Account"]);
idCol = local_find_column(vars, "openalex_institution_id");
includeCol = local_find_column(vars, "include");
if accountCol == "" || idCol == ""
    return;
end

accountVals = strtrim(string(L.(accountCol)));
idVals = strtrim(string(L.(idCol)));
validMask = accountVals ~= "" & idVals ~= "";
if includeCol == ""
    includeVals = true(height(L), 1);
else
    includeVals = local_parse_include_values(L.(includeCol));
end
overview.excluded_rows = int32(nnz(validMask & ~includeVals));
end

function local_log_target_overview(overview, targets)
log_info("targets=%d ids=%d multi_id_targets=%d excluded_rows=%d", ...
    overview.targets, overview.total_ids, overview.multi_id_targets, overview.excluded_rows);
for i = 1:height(targets)
    nIds = double(targets.n_ids(i));
    if nIds >= 4
        roles = string(targets.roles{i});
        roles = unique(roles(strlength(strtrim(roles)) > 0), "stable");
        roleText = "";
        if ~isempty(roles)
            roleText = " (" + strjoin(roles, " / ") + ")";
        end
        log_warn('"%s": %d ids%s -- confirm this is intended', ...
            targets.account(i), nIds, roleText);
    end
end
end

function preview = local_preview_target(query, fromDate, toDate, institutionIds, options)
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
apiKey = load_openalex_api_key(fullfile(projectRoot, 'config', 'settings.json'), true);
filterText = build_openalex_filter( ...
    fromDate, toDate, options.language, options.requireOpenAccess, ...
    institutionIds, options.filterCountryCode, options.filterType, true, true, options.citedByMin, options.citedByMax);
[~, meta] = fetch_openalex_works( ...
    searchQuery=query, ...
    filter=filterText, ...
    sort=options.sortBy, ...
    apiKey=apiKey, ...
    dryRun=true, ...
    maxPages=1, ...
    perPage=1);
preview = struct();
preview.filter_text = filterText;
preview.total_hits = int32(meta.total_count);
end

function col = local_find_column(vars, candidates)
if ischar(candidates) || isstring(candidates)
    candidates = string(candidates);
end
col = "";
for i = 1:numel(candidates)
    idx = find(strcmpi(vars, candidates(i)), 1, "first");
    if ~isempty(idx)
        col = vars(idx);
        return;
    end
end
end

function includeVals = local_parse_include_values(raw)
s = string(raw);
s(ismissing(s)) = "";
includeVals = false(size(s));
for i = 1:numel(s)
    v = lower(strtrim(s(i)));
    if v == ""
        includeVals(i) = false;
    elseif any(v == ["1", "true", "yes", "y"])
        includeVals(i) = true;
    elseif any(v == ["0", "false", "no", "n"])
        includeVals(i) = false;
    else
        numVal = str2double(v);
        includeVals(i) = ~isnan(numVal) && numVal ~= 0;
    end
end
includeVals = logical(includeVals);
end

log_info("batch done: institutions=%d success=%d failed=%d", ...
    result.total_institutions, result.success_count, result.failed_count);
log_info("summary=%s", result.summary_csv);
if batchXlsxPath ~= ""
    log_info("batch_excel=%s", batchXlsxPath);
end
if isfield(result, 'batch_comparison_xlsx')
    log_info("batch_comparison=%s", result.batch_comparison_xlsx);
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

function out = local_vertcat_tables(tbls)
if isempty(tbls)
    out = table();
    return;
end
allVars = strings(0, 1);
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

function local_write_csv_utf8_bom(T, filePath)
parentDir = fileparts(filePath);
if strlength(parentDir) > 0 && ~isfolder(parentDir)
    mkdir(parentDir);
end
writetable(T, filePath, "Encoding", "UTF-8");
% Prepend BOM if not already present
fid = fopen(filePath, 'r');
if fid < 0; return; end
cleanupIn = onCleanup(@() fclose(fid));
bytes = fread(fid, Inf, '*uint8');
bom = uint8([239; 187; 191]);
if numel(bytes) >= 3 && all(bytes(1:3) == bom); return; end
clear cleanupIn;
fidw = fopen(filePath, 'w');
if fidw < 0; return; end
cleanupOut = onCleanup(@() fclose(fidw));
fwrite(fidw, bom, 'uint8');
fwrite(fidw, bytes, 'uint8');
end
