function normalizedWorks = arxiv_to_normalized_works(arxivTable, options)
% ARXIV_TO_NORMALIZED_WORKS  Converts arXiv worksTable to unified normalized works schema.
%
% Input:
%   arxivTable -- table from fetch_arxiv_works with columns:
%     arxiv_id, title, abstract, published, doi, pdf_url,
%     primary_category, journal_ref, authors, affiliations
%
% Output:
%   normalizedWorks -- table with the same schema as openalex_to_normalized_works:
%     record_id, title, abstract, openalex_id, doi, doi_normalized,
%     publication_year, cited_by_count, source_dataset,
%     first_author_name, first_author_institutions,
%     last_author_name, last_author_institutions,
%     matlab_mentioned, is_oa, type, source_name, open_access_url, topics, language
%
% Field mapping:
%   arxiv_id            -> openalex_id  ("arxiv:" + arxiv_id)
%   title               -> title        (strtrim)
%   abstract            -> abstract     (strtrim; "" if missing)
%   published (ISO8601) -> publication_year (4-digit double)
%   doi                 -> doi, doi_normalized (lower+trim)
%   pdf_url             -> open_access_url
%   primary_category    -> topics
%   journal_ref         -> source_name  ("preprint" if empty)
%   authors[0]          -> first_author_name
%   affiliations[0]     -> first_author_institutions
%   authors[-1]         -> last_author_name  (* last in list, not "corresponding author")
%   affiliations[-1]    -> last_author_institutions
%   fixed NaN           -> cited_by_count   (arXiv provides no citation data)
%   fixed 1.0 (double)  -> is_oa            (arXiv is always open access)
%   fixed "preprint"    -> type
%   fixed "arxiv"       -> source_dataset
%   fixed ""            -> language         (arXiv does not provide language info)

arguments
    arxivTable table
    options.StrictValidation (1,1) logical = false  % arXiv: title-only required
    options.ReproSignalsConfigPath (1,1) string = ""
end

n = height(arxivTable);
if n == 0
    normalizedWorks = local_empty_schema();
    return;
end

arxivIdVec    = local_str_col(arxivTable, 'arxiv_id',         n);
titleVec      = strtrim(local_str_col(arxivTable, 'title',    n));
abstractVec   = strtrim(local_str_col(arxivTable, 'abstract', n));
publishedVec  = local_str_col(arxivTable, 'published',        n);
doiVec        = local_str_col(arxivTable, 'doi',              n);
pdfUrlVec     = local_str_col(arxivTable, 'pdf_url',          n);
primaryCatVec = local_str_col(arxivTable, 'primary_category', n);
journalRefVec = local_str_col(arxivTable, 'journal_ref',      n);
authorsVec    = local_str_col(arxivTable, 'authors',          n);
affilsVec     = local_str_col(arxivTable, 'affiliations',     n);

if options.StrictValidation
    invalidMask = strlength(titleVec) == 0;
    if any(invalidMask)
        error("arxiv_to_normalized_works:InvalidTitle", ...
            "Found %d rows with empty title.", nnz(invalidMask));
    end
end

% record_id / openalex_id
recordIdVec   = "arxiv:" + arxivIdVec;
openalexIdVec = "arxiv:" + arxivIdVec;
emptyIdMask   = strlength(arxivIdVec) == 0;
recordIdVec(emptyIdMask)   = "row_" + string(find(emptyIdMask));
openalexIdVec(emptyIdMask) = "";

% publication_year: extract 4-digit year from ISO 8601 "YYYY-MM-DDTHH:MM:SSZ"
pubYearVec = nan(n, 1);
for i = 1:n
    tok = regexp(char(publishedVec(i)), '^(\d{4})', 'tokens', 'once');
    if ~isempty(tok)
        pubYearVec(i) = str2double(tok{1});
    end
end

% doi_normalized: lowercase + trim
doiNormVec = lower(strtrim(doiVec));
doiNormVec(ismissing(doiNormVec)) = "";

% source_name: journal_ref, fallback "preprint"
sourceNameVec = journalRefVec;
sourceNameVec(strlength(strtrim(sourceNameVec)) == 0) = "preprint";

% first_author / last_author from "; "-separated author/affiliation strings
% Note: arXiv "last author" is the final element of the author list.
%       This differs from OpenAlex's "corresponding author" concept.
firstAuthorNameVec = strings(n, 1);
firstAuthorInstVec = strings(n, 1);
lastAuthorNameVec  = strings(n, 1);
lastAuthorInstVec  = strings(n, 1);
for i = 1:n
    names  = strtrim(strsplit(authorsVec(i),  "; "));
    affils = strtrim(strsplit(affilsVec(i),   "; "));
    if numel(names) >= 1 && names(1) ~= ""
        firstAuthorNameVec(i) = names(1);
        lastAuthorNameVec(i)  = names(end);
    end
    if numel(affils) >= 1 && affils(1) ~= ""
        firstAuthorInstVec(i) = affils(1);
        lastAuthorInstVec(i)  = affils(end);
    end
end

signalTable = detect_repro_signals(titleVec, abstractVec, ConfigPath=options.ReproSignalsConfigPath);

% Fixed values for all arXiv records
citedByCount  = nan(n, 1);           % arXiv does not provide citation counts
isOaVec       = ones(n, 1);          % arXiv is always open access
%   is_oa stored as double (1.0/0.0) to match openalex schema after CSV round-trip
typeVec       = repmat("preprint", n, 1);
sourceDataset = repmat("arxiv",    n, 1);
languageVec   = repmat("",         n, 1);  % arXiv does not provide language info

normalizedWorks = table( ...
    recordIdVec, ...
    titleVec, ...
    abstractVec, ...
    openalexIdVec, ...
    doiVec, ...
    doiNormVec, ...
    pubYearVec, ...
    citedByCount, ...
    sourceDataset, ...
    firstAuthorNameVec, ...
    firstAuthorInstVec, ...
    lastAuthorNameVec, ...
    lastAuthorInstVec, ...
    signalTable.mentions_dataset, ...
    signalTable.mentions_code, ...
    signalTable.mentions_library, ...
    signalTable.mentions_metrics, ...
    signalTable.repro_signal_score, ...
    signalTable.matlab_mentioned, ...
    isOaVec, ...
    typeVec, ...
    sourceNameVec, ...
    pdfUrlVec, ...
    primaryCatVec, ...
    languageVec, ...
    'VariableNames', { ...
        'record_id', 'title', 'abstract', 'openalex_id', 'doi', 'doi_normalized', ...
        'publication_year', 'cited_by_count', 'source_dataset', ...
        'first_author_name', 'first_author_institutions', ...
        'last_author_name', 'last_author_institutions', ...
        'mentions_dataset', 'mentions_code', 'mentions_library', 'mentions_metrics', ...
        'repro_signal_score', 'matlab_mentioned', 'is_oa', 'type', 'source_name', 'open_access_url', ...
        'topics', 'language'} ...
    );
end

% ─── Local helpers ────────────────────────────────────────────────────────────

function vals = local_str_col(tbl, colName, n)
% Returns string column from table, or n-length empty-string vector if absent.
if ismember(colName, string(tbl.Properties.VariableNames))
    vals = string(tbl.(colName));
    vals(ismissing(vals)) = "";
else
    vals = repmat("", n, 1);
end
vals = vals(:);
end

function T = local_empty_schema()
% Returns empty table with the unified normalized works schema.
varNames = { ...
    'record_id', 'title', 'abstract', 'openalex_id', 'doi', 'doi_normalized', ...
    'publication_year', 'cited_by_count', 'source_dataset', ...
    'first_author_name', 'first_author_institutions', ...
    'last_author_name', 'last_author_institutions', ...
    'mentions_dataset', 'mentions_code', 'mentions_library', 'mentions_metrics', ...
    'repro_signal_score', 'matlab_mentioned', 'is_oa', 'type', 'source_name', 'open_access_url', ...
    'topics', 'language'};
varTypes = { ...
    'string', 'string', 'string', 'string', 'string', 'string', ...
    'double', 'double', 'string', ...
    'string', 'string', ...
    'string', 'string', ...
    'logical', 'logical', 'logical', 'logical', ...
    'double', 'logical', 'double', 'string', 'string', 'string', 'string', 'string'};
T = table('Size', [0, numel(varNames)], ...
    'VariableTypes', varTypes, 'VariableNames', varNames);
end
