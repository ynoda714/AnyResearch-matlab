function export_excel_workbook(jsonlPath, xlsxPath, cfg)
%EXPORT_EXCEL_WORKBOOK  Generate a 4-sheet Excel workbook from JSONL/CSV (entry point)
%
%   export_excel_workbook(jsonlPath, xlsxPath, cfg)
%
%   Arguments:
%     jsonlPath (string) — Input JSONL file path
%                          Falls back to .csv of the same name if .jsonl is absent
%     xlsxPath  (string) — Output .xlsx file path
%     cfg       (struct) — Runtime config struct (optional)
%
%   cfg fields (optional; missing fields filled with defaults):
%     cfg.query        — Search query
%     cfg.from_date    — Search start date
%     cfg.to_date      — Search end date
%     cfg.filter       — OpenAlex filter string
%     cfg.run_id       — Run ID
%     cfg.run_dir      — Run directory path
%     cfg.rows_fetched — Number of rows fetched (defaults to row count of T)
%     cfg.total_hits   — Total API hit count
%     cfg.created_at   — Generation timestamp (defaults to current time)
%
%   Output: 4-sheet Excel workbook (Overview / Detail / Summary / Config)
%
%   Write mode:
%     COM available (Windows + Excel installed) → writes via actxserver
%       - Supports DOI hyperlinks / header style / auto column width / freeze panes
%     COM unavailable → writecell fallback (Unicode-safe, no formatting)
%
%   Character encoding notes:
%     COM mode: writes directly to cells via Excel COM — no encoding issues
%     Fallback: writecell + FileType=spreadsheet for xlsx output (UTF-8)

arguments
    jsonlPath (1,1) string
    xlsxPath  (1,1) string
    cfg       (1,1) struct = struct()
end

% Add src/util to path (resolve dependencies: write_jsonl / read_jsonl, etc.)
local_addpath_util(mfilename('fullpath'));

% Load input data
T = local_load_data(jsonlPath);
log_info("excel export: rows=%d  input=%s", height(T), jsonlPath);

% Fill cfg.created_at with current time if not set
if ~isfield(cfg, 'created_at') || strlength(string(cfg.created_at)) == 0
    cfg.created_at = string(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
end

% Compute analytics (citation velocity, topic growth rate, institution dominance)
% and attach to cfg for use by excel_write_summary
if ~isfield(cfg, 'analytics') && height(T) > 0
    try
        cfg.analytics = compute_analytics(T);
    catch analyticsEx
        log_warn("compute_analytics skipped: %s", analyticsEx.message);
    end
end

% Build sheet data specs
specs = { ...
    excel_write_overview(T, cfg), ...
    excel_write_detail(T, cfg), ...
    excel_write_summary(T, cfg), ...
    excel_write_config(T, cfg) ...
};

% Ensure output directory exists
outDir = fileparts(xlsxPath);
if strlength(outDir) > 0 && ~isfolder(outDir)
    mkdir(outDir);
end

% Delete existing file (treat as fresh creation, not overwrite)
if isfile(xlsxPath)
    delete(xlsxPath);
end

% Write
if excel_check_com_available()
    try
        local_write_com(xlsxPath, specs);
        local_write_test_hook(cfg, "com");
        log_info("excel (COM): saved %s", xlsxPath);
        return;
    catch comEx
        log_warn("Excel COM write failed. Switching to fallback: %s", comEx.message);
        % Re-delete file in case a corrupt file was left behind
        if isfile(xlsxPath)
            delete(xlsxPath);
        end
    end
end

% Fallback (writecell-based)
local_write_fallback(xlsxPath, specs);
local_write_test_hook(cfg, "fallback");
log_info("excel (fallback): saved %s", xlsxPath);
end

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  COM write
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function local_write_com(xlsxPath, specs)
% Generate Excel workbook via COM
% Path passed to SaveAs must be absolute

excel = actxserver('Excel.Application');
excel.Visible = false;
excel.DisplayAlerts = false;
wb = [];

try
    wb = excel.Workbooks.Add;

    % Delete extra default sheets (Excel creates multiple sheets by default)
    while wb.Worksheets.Count > 1
        wb.Worksheets.Item(wb.Worksheets.Count).Delete;
    end

    % Configure the first sheet with spec(1)
    prevWs = wb.Worksheets.Item(1);
    prevWs.Name = char(specs{1}.sheetName);
    local_fill_sheet_com(prevWs, specs{1});

    % Add remaining sheets
    for i = 2:numel(specs)
        ws = wb.Worksheets.Add([], prevWs);
        ws.Name = char(specs{i}.sheetName);
        local_fill_sheet_com(ws, specs{i});
        prevWs = ws;
    end

    % Save as .xlsx using absolute path (51 = xlOpenXMLWorkbook)
    absPath = local_abs_path(xlsxPath);
    wb.SaveAs(char(absPath), 51);
    wb.Close(false);
    wb = [];

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

function local_fill_sheet_com(ws, spec)
% Write one sheet's header + data via COM

nRows = size(spec.data, 1);
nCols = spec.nCols;
if nCols == 0
    return;
end

% Combine header + data into cell array and write all at once (fast)
fullData = [spec.headers; spec.data];
totalRows = size(fullData, 1);

% Replace NaN with empty string (NaN may become 0 in Excel)
for ri = 1:totalRows
    for ci = 1:nCols
        v = fullData{ri, ci};
        if isnumeric(v) && isscalar(v) && isnan(v)
            fullData{ri, ci} = '';
        end
    end
end

if totalRows > 0
    rng = ws.Range(char(excel_a1_range(1, 1, totalRows, nCols)));
    rng.Value = fullData;
end

% Header style (bold + background color)
excel_apply_header_style(ws, nCols);

% Hyperlinks (DOI, etc.)
for i = 1:numel(spec.hyperlinks)
    h = spec.hyperlinks(i);
    try
        ws.Hyperlinks.Add(ws.Range(char(excel_a1_range(h.row, h.col))), h.url, '', '', h.display);
    catch
        % Ignore hyperlink add failure (existing text is preserved)
    end
end

% Freeze panes (row 1)
try
    ws.Activate;
    ws.Application.ActiveWindow.SplitRow = 1;
    ws.Application.ActiveWindow.SplitColumn = 0;
    ws.Application.ActiveWindow.FreezePanes = true;
catch
end

% Set up Excel Table (ListObject): applied to Overview / Detail sheets only
% ListObject enables one-click filtering and sorting
sheetName = string(ws.Name);
if nRows > 0 && (sheetName == "Overview" || sheetName == "Detail")
    try
        dataRange = ws.Range(char(excel_a1_range(1, 1, nRows + 1, nCols)));
        tbl = ws.ListObjects.Add(1, dataRange, [], 1);  % 1=xlSrcRange, 1=xlYes(has header)
        tbl.Name = char(sheetName + "Table");
        tbl.TableStyle = 'TableStyleMedium2';
    catch
        % Ignore ListObject add failure (header style already applied)
    end
end

% Section header row style (for Summary sheet)
% spec.sectionRows is a list of 1-indexed row numbers based on fullData
if isfield(spec, 'sectionRows') && ~isempty(spec.sectionRows)
    for si = 1:numel(spec.sectionRows)
        rowIdx = spec.sectionRows(si);
        try
            secRange = ws.Range(char(excel_a1_range(rowIdx, 1, rowIdx, nCols)));
            secRange.Font.Bold = true;
            secRange.Interior.Color = hex2dec('D9E1F2');  % light blue (for subsections)
        catch
        end
    end
end

% Auto-fit column widths
try
    ws.Columns.AutoFit;
catch
end
end

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  Fallback write (writecell-based)
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function local_write_fallback(xlsxPath, specs)
% Write each sheet in order using writecell + FileType=spreadsheet
% Unicode (Japanese) is preserved correctly in xlsx format
for i = 1:numel(specs)
    spec = specs{i};
    fullData = [spec.headers; spec.data];

    % Convert NaN to empty string
    for ri = 1:size(fullData, 1)
        for ci = 1:size(fullData, 2)
            v = fullData{ri, ci};
            if isnumeric(v) && isscalar(v) && isnan(v)
                fullData{ri, ci} = '';
            end
        end
    end

    writecell(fullData, xlsxPath, ...
        'Sheet',    char(spec.sheetName), ...
        'FileType', 'spreadsheet');
end
end

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  Data loading
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function T = local_load_data(inputPath)
% Load JSONL preferentially. Fall back to CSV of the same name if absent.
p = char(inputPath);
if isfile(p)
    [~, ~, ext] = fileparts(p);
    if strcmpi(ext, '.jsonl')
        T = read_jsonl(inputPath);
    else
        T = readtable(inputPath, "TextType", "string", ...
            "VariableNamingRule", "preserve", "Delimiter", ",", ...
            "ReadVariableNames", true);
    end
    return;
end

% CSV fallback
csvPath = strrep(p, '.jsonl', '.csv');
if isfile(csvPath)
    T = readtable(csvPath, "TextType", "string", ...
        "VariableNamingRule", "preserve", "Delimiter", ",", ...
        "ReadVariableNames", true);
    return;
end

error("export_excel_workbook:InputNotFound", ...
    "Input file not found: %s", inputPath);
end

% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
%  Utilities
% ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function absPath = local_abs_path(path)
% Convert a relative path to an absolute path
p = char(path);
if ispc
    % Windows: with drive letter (e.g. C:\...)
    if numel(p) >= 3 && p(2) == ':' && (p(3) == '\' || p(3) == '/')
        absPath = string(p);
        return;
    end
    % UNC path
    if numel(p) >= 2 && p(1) == '\' && p(2) == '\'
        absPath = string(p);
        return;
    end
else
    if numel(p) >= 1 && p(1) == '/'
        absPath = string(p);
        return;
    end
end
absPath = string(fullfile(pwd, p));
end

function local_addpath_util(thisFileFullPath)
% Add src/util and src/analytics to MATLAB path
srcDir      = fileparts(thisFileFullPath);          % src/export/
utilDir     = fullfile(srcDir, '..', 'util');
analyticsDir = fullfile(srcDir, '..', 'analytics');
if isfolder(utilDir) && ~any(strcmp(strsplit(path, pathsep), char(string(utilDir))))
    addpath(char(utilDir));
end
if isfolder(analyticsDir) && ~any(strcmp(strsplit(path, pathsep), char(string(analyticsDir))))
    addpath(char(analyticsDir));
end
end

function local_write_test_hook(cfg, mode)
if ~isfield(cfg, 'testHookWriteModePath')
    return;
end
hookPath = string(cfg.testHookWriteModePath);
if strlength(strtrim(hookPath)) == 0
    return;
end
parentDir = fileparts(hookPath);
if strlength(parentDir) > 0 && ~isfolder(parentDir)
    mkdir(parentDir);
end
fid = fopen(hookPath, 'w');
if fid < 0
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, char(mode), 'char');
end
