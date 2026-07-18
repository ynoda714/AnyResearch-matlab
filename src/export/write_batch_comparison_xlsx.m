function xlsxPath = write_batch_comparison_xlsx(finalAll, batchDir, options)
%WRITE_BATCH_COMPARISON_XLSX  Generate a cross-institution comparison Excel from batch run results
%
%   Outputs a per-institution x per-year matrix of paper count, OA count, and average citations to one sheet.
%   Called from run_batch_from_institutions_list.
%
%   Usage:
%     xlsxPath = write_batch_comparison_xlsx(finalAll, batchDir)
%
%   Arguments:
%     finalAll (table) — Merged table for all institutions
%                        Required columns: target_institution_name / publication_year /
%                                cited_by_count / is_oa
%     batchDir (string) — Batch output directory
%
%   [Name=Value options]
%     outputXlsx (string) — Output file path (default: batchDir/batch_comparison.xlsx)
%
%   [Return value]
%     xlsxPath (string) — Path of the generated .xlsx file (empty string on failure)
%
%   Sheet layout: "Comparison" (1 sheet)
%     Section 1 — Paper Count          (institution x year, with Total row/column)
%     Section 2 — OA Count             (same layout)
%     Section 3 — Avg Cited By Count   (same layout; Total row is weighted average)
%     Section 4 — Institution Dominance (institution | paper_share | citation_share | dominance_score)

arguments
    finalAll  table
    batchDir  (1,1) string
    options.outputXlsx (1,1) string = ""
end

xlsxPath = "";

if height(finalAll) == 0
    return;
end

% Output path
outXlsx = options.outputXlsx;
if strlength(outXlsx) == 0
    outXlsx = string(fullfile(char(batchDir), 'batch_comparison.xlsx'));
end

% ── Analytics: addpath ────────────────────────────────────────────────────────
local_addpath_analytics(mfilename('fullpath'));

% ── Data aggregation ───────────────────────────────────────────────────────────
hasInst  = ismember('target_institution_name', finalAll.Properties.VariableNames);
hasYear  = ismember('publication_year',         finalAll.Properties.VariableNames);
hasCited = ismember('cited_by_count',           finalAll.Properties.VariableNames);
hasOa    = ismember('is_oa',                    finalAll.Properties.VariableNames);

if ~hasInst || ~hasYear
    return;
end

institutions = unique(string(finalAll.target_institution_name), 'stable');
institutions = institutions(strlength(strtrim(institutions)) > 0);
if isempty(institutions)
    return;
end

yearVals = double(finalAll.publication_year);
validYears = sort(unique(yearVals(~isnan(yearVals))));
if isempty(validYears)
    return;
end

nInst  = numel(institutions);
nYears = numel(validYears);

% Three matrices: [nInst x nYears]
matCount  = zeros(nInst, nYears);
matOa     = zeros(nInst, nYears);
matAvgCit = nan(nInst, nYears);  % NaN = no data (do not use 0 for averages)

for ii = 1:nInst
    instMask = string(finalAll.target_institution_name) == institutions(ii);
    for yi = 1:nYears
        yr    = validYears(yi);
        mask  = instMask & (yearVals == yr);
        cnt   = nnz(mask);
        matCount(ii, yi) = cnt;
        if cnt == 0; continue; end

        if hasOa
            oaVals = finalAll.is_oa(mask);
            matOa(ii, yi) = local_oa_sum(oaVals);
        end
        if hasCited
            cited = double(finalAll.cited_by_count(mask));
            cited = cited(~isnan(cited));
            if ~isempty(cited)
                matAvgCit(ii, yi) = mean(cited);
            end
        end
    end
end

% ── Cell data construction ───────────────────────────────────────────────────────
yearHeaders = arrayfun(@(y) y, validYears, 'UniformOutput', false);  % keep as double
nCols       = nYears + 2;  % institution_name | year1 ... yearN | Total

% Section construction helpers
sec1 = local_build_section('Paper Count',         institutions, yearHeaders, matCount,  false);
sec2 = local_build_section('OA Count',            institutions, yearHeaders, matOa,     false);
sec3 = local_build_section('Avg Cited By Count',  institutions, yearHeaders, matAvgCit, true);

% ── Section 4: Institution Dominance ─────────────────────────────────────────
% Use first_author_institutions if target_institution_name is not set at paper level
instColForDominance = 'first_author_institutions';
if ~ismember(instColForDominance, finalAll.Properties.VariableNames)
    instColForDominance = 'target_institution_name';
end
sec4 = local_build_dominance_section(finalAll, instColForDominance, nCols);

emptyRow = repmat({''}, 1, nCols);
data = [sec1; emptyRow; sec2; emptyRow; sec3; emptyRow; sec4];

% sectionRows: fullData row indices of section headings (bold highlight)
nSec1Rows = size(sec1, 1);
nSec2Rows = size(sec2, 1);
nSec3Rows = size(sec3, 1);
sec1LabelRow = 2;
sec2LabelRow = 2 + nSec1Rows + 1;
sec3LabelRow = 2 + nSec1Rows + 1 + nSec2Rows + 1;
sec4LabelRow = 2 + nSec1Rows + 1 + nSec2Rows + 1 + nSec3Rows + 1;

sectionRows = [sec1LabelRow, sec1LabelRow + 1, ...
               sec2LabelRow, sec2LabelRow + 1, ...
               sec3LabelRow, sec3LabelRow + 1, ...
               sec4LabelRow, sec4LabelRow + 1];

% Header row (column names)
colHeader = [{'institution_name'}, yearHeaders(:)', {'Total'}];

spec.sheetName  = 'Comparison';
spec.headers    = colHeader;
spec.data       = data;
spec.hyperlinks = struct('row', {}, 'col', {}, 'url', {}, 'display', {});
spec.nCols      = nCols;
spec.sectionRows = sectionRows;

% ── Excel write ───────────────────────────────────────────────────────
if ~isfolder(char(batchDir))
    mkdir(char(batchDir));
end
if isfile(char(outXlsx))
    delete(char(outXlsx));
end

local_addpath_util(mfilename('fullpath'));

if excel_check_com_available()
    try
        local_write_com(char(outXlsx), spec, nCols);
        xlsxPath = outXlsx;
        log_info("batch_comparison.xlsx (COM): %s", outXlsx);
        return;
    catch comEx
        log_warn("batch_comparison COM write failed. Switching to fallback: %s", comEx.message);
        if isfile(char(outXlsx)); delete(char(outXlsx)); end
    end
end

% writecell fallback
fullData = [spec.headers; spec.data];
local_strip_nan(fullData);
writecell(fullData, char(outXlsx), 'Sheet', char(spec.sheetName), 'FileType', 'spreadsheet');
xlsxPath = outXlsx;
log_info("batch_comparison.xlsx (fallback): %s", outXlsx);
end

% ── Section construction ────────────────────────────────────────────────────────

function sec = local_build_section(label, institutions, yearHeaders, mat, isAvg)
% label     : section name (char)
% mat       : [nInst x nYears] numeric matrix
% isAvg     : true -> Total column is weighted average over all years; false -> sum
nInst  = numel(institutions);
nYears = numel(yearHeaders);
nCols  = nYears + 2;   % institution_name + years + Total

% Row 1: section label
labelRow = [{label}, repmat({''}, 1, nCols - 1)];
% Row 2: column headers
subHeader = [{'institution_name'}, yearHeaders(:)', {'Total'}];

% Rows 3+: per-institution data
rows = cell(nInst + 1, nCols);
for ii = 1:nInst
    rows{ii, 1} = char(institutions(ii));
    for yi = 1:nYears
        v = mat(ii, yi);
        if ~isnan(v)
            if isAvg && v == 0 && mat(ii, yi) == 0
                rows{ii, yi + 1} = '';
            else
                rows{ii, yi + 1} = round(v * 10) / 10;  % 1 decimal place
            end
        else
            rows{ii, yi + 1} = '';
        end
    end
    % Total column
    if isAvg
        validVals = mat(ii, ~isnan(mat(ii,:)));
        if ~isempty(validVals) && any(validVals > 0)
            rows{ii, nCols} = round(mean(validVals(validVals > 0)) * 10) / 10;
        else
            rows{ii, nCols} = '';
        end
    else
        rows{ii, nCols} = sum(mat(ii,:));
    end
end

% Total row (institution sum/average)
rows{nInst + 1, 1} = 'Total';
for yi = 1:nYears
    colVals = mat(:, yi);
    validVals = colVals(~isnan(colVals));
    if isempty(validVals)
        rows{nInst + 1, yi + 1} = '';
    elseif isAvg
        nzVals = validVals(validVals > 0);
        if isempty(nzVals)
            rows{nInst + 1, yi + 1} = '';
        else
            rows{nInst + 1, yi + 1} = round(mean(nzVals) * 10) / 10;
        end
    else
        rows{nInst + 1, yi + 1} = sum(validVals);
    end
end
% Total × Total
if isAvg
    allValid = mat(~isnan(mat));
    nzAll = allValid(allValid > 0);
    if isempty(nzAll)
        rows{nInst + 1, nCols} = '';
    else
        rows{nInst + 1, nCols} = round(mean(nzAll) * 10) / 10;
    end
else
    rows{nInst + 1, nCols} = sum(mat(:));
end

sec = [labelRow; subHeader; rows];
end

% ── COM write ─────────────────────────────────────────────────────────

function local_write_com(xlsxPath, spec, nCols)
excel = actxserver('Excel.Application');
excel.Visible = false;
excel.DisplayAlerts = false;
wb = [];
try
    wb = excel.Workbooks.Add;
    while wb.Worksheets.Count > 1
        wb.Worksheets.Item(wb.Worksheets.Count).Delete;
    end
    ws = wb.Worksheets.Item(1);
    ws.Name = char(spec.sheetName);

    fullData = [spec.headers; spec.data];
    nRows = size(fullData, 1);

    % Replace NaN with empty string
    for ri = 1:nRows
        for ci = 1:nCols
            v = fullData{ri, ci};
            if isnumeric(v) && isscalar(v) && isnan(v)
                fullData{ri, ci} = '';
            end
        end
    end

    if nRows > 0
        rng = ws.Range(char(excel_a1_range(1, 1, nRows, nCols)));
        rng.Value = fullData;
    end

    % Column header (row 1) style
    excel_apply_header_style(ws, nCols);

    % Section heading row style (bold + light blue)
    if isfield(spec, 'sectionRows')
        for si = 1:numel(spec.sectionRows)
            rowIdx = spec.sectionRows(si);
            try
                secRng = ws.Range(char(excel_a1_range(rowIdx, 1, rowIdx, nCols)));
                secRng.Font.Bold = true;
                secRng.Interior.Color = hex2dec('D9E1F2');
            catch %#ok<TRYNC>
            end
        end
    end

    try
        ws.Columns.AutoFit;
    catch %#ok<TRYNC>
    end
    try
        ws.Activate;
        ws.Application.ActiveWindow.SplitRow = 1;
        ws.Application.ActiveWindow.SplitColumn = 0;
        ws.Application.ActiveWindow.FreezePanes = true;
    catch %#ok<TRYNC>
    end

    % Save with absolute path
    if ispc && numel(xlsxPath) >= 3 && xlsxPath(2) == ':'
        absPath = xlsxPath;
    else
        absPath = char(string(fullfile(pwd, xlsxPath)));
    end
    wb.SaveAs(absPath, 51);
    wb.Close(false);
    wb = []; %#ok<NASGU>
catch ME
    if ~isempty(wb)
        try; wb.Close(false); catch; end %#ok<TRYNC>
    end
    excel.Quit;
    excel.delete;
    rethrow(ME);
end
excel.Quit;
excel.delete;
end

% ── Utilities ───────────────────────────────────────────────────────

function s = local_oa_sum(oaVals)
s = 0;
for vi = 1:numel(oaVals)
    raw = oaVals(vi);
    if islogical(raw)
        if raw; s = s + 1; end
    elseif isnumeric(raw)
        if raw == 1; s = s + 1; end
    elseif isstring(raw) || ischar(raw)
        sv = lower(strtrim(char(string(raw))));
        if any(strcmpi(sv, {'true','1','yes'})); s = s + 1; end
    end
end
end

function local_strip_nan(data)
% Replace NaN with '' in cell array (in-place: cell is a reference)
for ri = 1:size(data,1)
    for ci = 1:size(data,2)
        v = data{ri,ci};
        if isnumeric(v) && isscalar(v) && isnan(v)
            data{ri,ci} = ''; %#ok<NASGU>
        end
    end
end
end

function local_addpath_util(thisFileFullPath)
srcDir  = fileparts(thisFileFullPath);
utilDir = fullfile(srcDir, '..', 'util');
if isfolder(utilDir) && ~any(strcmp(strsplit(path, pathsep), char(string(utilDir))))
    addpath(char(utilDir));
end
end

function local_addpath_analytics(thisFileFullPath)
srcDir       = fileparts(thisFileFullPath);
analyticsDir = fullfile(srcDir, '..', 'analytics');
if isfolder(analyticsDir) && ~any(strcmp(strsplit(path, pathsep), char(string(analyticsDir))))
    addpath(char(analyticsDir));
end
end

function sec = local_build_dominance_section(T, instCol, nCols)
% Build Section 4: Institution Dominance Score
% Calls institution_dominance() on the batch-merged table.
% nCols: total column width of the sheet (must match other sections).
%   The dominance section has 6 data columns; padded to nCols when nCols>6,
%   truncated to nCols when nCols<6.
labelRow = [{'Institution Dominance Score'}, repmat({''}, 1, nCols - 1)];

subHdrFull = {'institution_name', 'paper_count', 'total_citations', ...
              'paper_share', 'citation_share', 'dominance_score'};
if nCols >= 6
    subHdrRow = [subHdrFull, repmat({''}, 1, nCols - 6)];
else
    subHdrRow = subHdrFull(1:nCols);
end

nDataCols = min(6, nCols);  % number of data columns to fill

try
    idResult = institution_dominance(T, institutionCol=instCol, topN=50);
    tbl = idResult.by_institution;
    if height(tbl) == 0
        dataRows = repmat({''}, 1, nCols);
        dataRows{1} = '(no data)';
        sec = [labelRow; subHdrRow; dataRows];
        return;
    end
    nR = height(tbl);
    dataRows = repmat({''}, nR, nCols);
    allVals = { ...
        @(i) char(tbl.institution(i)), ...
        @(i) tbl.paper_count(i), ...
        @(i) tbl.total_citations(i), ...
        @(i) round(tbl.paper_share(i), 4), ...
        @(i) round(tbl.citation_share(i), 4), ...
        @(i) round(tbl.dominance_score(i), 4)};
    for i = 1:nR
        for ci = 1:nDataCols
            dataRows{i, ci} = allVals{ci}(i);
        end
    end
catch ex
    dataRows = repmat({''}, 1, nCols);
    dataRows{1} = sprintf('(institution_dominance error: %s)', ex.message);
end

sec = [labelRow; subHdrRow; dataRows];
end
