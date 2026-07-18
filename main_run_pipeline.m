%% main_run_pipeline.m (v3.0.0)
% Front script for single-keyword search.
% For batch execution (multiple institutions), use main_run_batch.m.
%
% Usage:
%   Set parameters in Section 0, then run Section 1 with "Run Section" (Ctrl+Enter).

%% 0) Parameters (edit here only)

% ── Layer 0: Search query (required) ────────────────────────────────
query    = "machine learning";
fromDate = "2025-01-01";
toDate   = "2025-03-31";
% Query syntax:
%   AND : separate with spaces  e.g. "deep learning classification"
%   OR  : use |                 e.g. "solar|wind energy"
%   Phrase: wrap in quotes      e.g. '"machine learning"'

% ── Layer 0: Sort order & document type filter (optional) ───────────
sortBy     = "cited_by_count:desc";   % "cited_by_count:desc" / "publication_date:desc" / "relevance_score" / ""
filterType = "";                       % "" (all types) / "article" / "review" / "article,review"
citedByMin = 0;                        % 0 = disabled. Example: 100 keeps highly cited papers only
citedByMax = 0;                        % 0 = disabled. Example: 500 excludes very old classics
seedId     = "";                       % Optional: DOI or OpenAlex Work ID for 1-hop snowball retrieval
snowballMode = "citing";               % "citing" / "referenced" (used only when seedId is non-empty)
topN       = 10;                       % Number of top papers and journals shown in the Summary sheet
% ── Layer 0: Search filters (optional) ──────────────────────────────
language          = "en";     % Language code. Empty = no language filter
requireOpenAccess = true;     % true = Open Access papers only
requireAbstract   = true;     % true = papers with abstract only (set false to include latest papers)
filterCountryCode = "JP";     % e.g. "JP". Empty = no country filter

% ── Layer 0: Institution filter (optional) ──────────────────────────
% Set only to narrow results to a specific institution. Empty = all institutions.
% Tip: use lookup_institution_id("institution name") to find the correct ID.
%      One name may return multiple ID candidates — pick the most suitable one.
firstAuthorInstitution   = "";   % e.g. "The University of Tokyo"
firstAuthorInstitutionId = "";   % e.g. "I26973366"  (more reliable than name alone)

% ── Layer 1: PDF extraction (optional) ──────────────────────────────
enablePdfDownload = false;   % true = automatically download and extract Open Access PDFs
% ── arXiv extension (optional) ───────────────────────────────────
useArxiv = true;   % true = also fetch preprints from arXiv and merge (deduped by DOI)
appendToCandidates = false;  % true = append this run to result/candidates/candidates.jsonl

%% 1) Run (do not edit)
thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, 'src', 'pipeline'));
addpath(fullfile(thisDir, 'src', 'util'));

result = run_pipeline(query, fromDate, toDate, ...
    language=language, ...
    requireOpenAccess=requireOpenAccess, ...
    requireAbstract=requireAbstract, ...
    filterCountryCode=filterCountryCode, ...
    sortBy=sortBy, ...
    filterType=filterType, ...
    citedByMin=citedByMin, ...
    citedByMax=citedByMax, ...
    seedId=seedId, ...
    snowballMode=snowballMode, ...
    topN=topN, ...
    firstAuthorInstitution=firstAuthorInstitution, ...
    firstAuthorInstitutionId=firstAuthorInstitutionId, ...
    enablePdfDownload=enablePdfDownload, ...
    useArxiv=useArxiv, ...
    appendToCandidates=appendToCandidates);
disp(result);
