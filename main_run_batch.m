%% main_run_batch.m (v2.0.0)
% Front script for batch execution across multiple institutions.
% For single-keyword search, use main_run_pipeline.m.
%
% Usage:
%   1. Edit parameters in Section 0.
%   2. If you need to refresh the institution list, set prepareList=true and run Section 0.5.
%   3. Review include/role/note in institutions_candidate.csv or institutions.csv.
%   4. Run Section 1 with "Run Section" (Ctrl+Enter).

%% 0) Parameters (edit here only)

% Input / output
institutionsCsv       = "data/list/institutions.csv";
batchRootDir          = "result/batch";
prepareList           = false;   % true = run Section 0.5 to refresh candidate CSV
dryRun                = false;   % true = preview filters and counts only, no full fetch
targetNames           = ["Nagoya University", "Example Medical University"];
prepareCountryFilter  = "JP";
prepareMaxCandidates  = 3;

% Layer 0: Search query (required)
query    = "machine learning";
fromDate = "2025-01-01";
toDate   = "2025-12-31";
% Query syntax:
%   AND : separate with spaces  e.g. "deep learning classification"
%   OR  : use |                 e.g. "solar|wind energy"
%   Phrase: wrap in quotes      e.g. '"machine learning"'

% Layer 0: Sort order & document type filter (optional)
sortBy     = "cited_by_count:desc";   % "cited_by_count:desc" / "publication_date:desc" / "relevance_score" / ""
filterType = "";                       % "" (all types) / "article" / "review" / "article,review"
topN       = 10;                       % Number of top papers and journals shown in the Summary sheet

% Layer 0: Search filters (optional)
language          = "en";     % Language code. Empty = no language filter
requireOpenAccess = true;     % true = Open Access papers only
filterCountryCode = "JP";     % e.g. "JP". Empty = no country filter

% Layer 1: PDF extraction (optional)
enablePdfDownload = false;   % true = automatically download and extract Open Access PDFs

% arXiv extension (optional)
useArxiv = false;   % true = also fetch preprints from arXiv and merge (deduped by DOI)

% Candidate ledger append (optional)
appendToCandidates = false;                    % true = append each institution run to a ledger
ledgerPath         = "result/candidates/candidates.jsonl";  % e.g. "result/candidates/other_campaign.jsonl"

%% 0.5) Target list preparation (run only when prepareList = true)
if prepareList
    thisDir = fileparts(mfilename('fullpath'));
    if ~isfolder(fullfile(thisDir, 'src')), thisDir = pwd; end   % Run Section / unsaved buffer: mfilename is a temp path, use Current Folder
    assert(isfolder(fullfile(thisDir, 'src')), 'AnyResearch:BadRoot', ...
        'Set the MATLAB Current Folder to the AnyResearch repo root (the folder with main_run_batch.m and src/), then run again.');
    addpath(fullfile(thisDir, 'src', 'openalex'));
    addpath(fullfile(thisDir, 'src', 'config'));
    addpath(fullfile(thisDir, 'src', 'util'));
    prepare_institutions_csv(targetNames, ...
        countryFilter=prepareCountryFilter, ...
        maxCandidates=prepareMaxCandidates, ...
        mergeWith=institutionsCsv);
end

%% 1) Run (do not edit)
thisDir = fileparts(mfilename('fullpath'));
if ~isfolder(fullfile(thisDir, 'src')), thisDir = pwd; end   % Run Section / unsaved buffer: mfilename is a temp path, use Current Folder
assert(isfolder(fullfile(thisDir, 'src')), 'AnyResearch:BadRoot', ...
    'Set the MATLAB Current Folder to the AnyResearch repo root (the folder with main_run_batch.m and src/), then run again.');
addpath(fullfile(thisDir, 'src', 'pipeline'));
addpath(fullfile(thisDir, 'src', 'util'));

batchResult = run_batch_from_institutions_list( ...
    institutionsCsv, query, fromDate, toDate, ...
    batchRootDir=batchRootDir, ...
    language=language, ...
    requireOpenAccess=requireOpenAccess, ...
    filterCountryCode=filterCountryCode, ...
    sortBy=sortBy, ...
    filterType=filterType, ...
    topN=topN, ...
    enablePdfDownload=enablePdfDownload, ...
    useArxiv=useArxiv, ...
    appendToCandidates=appendToCandidates, ...
    ledgerPath=ledgerPath, ...
    dryRun=dryRun);
disp(batchResult);
