function outputPath = export_candidates_xlsx(inputPath, outputPath)
%EXPORT_CANDIDATES_XLSX  Write the candidate ledger as a single-sheet Excel view.

arguments
    inputPath  (1,1) string = "result/candidates/candidates.jsonl"
    outputPath (1,1) string = "result/candidates/candidates.xlsx"
end

local_addpath_util(mfilename('fullpath'));
T = local_load_candidates(inputPath);
T = local_reorder_columns(T);
headers = T.Properties.VariableNames;
data = local_table_to_cell(T);

outDir = fileparts(outputPath);
if strlength(outDir) > 0 && ~isfolder(outDir)
    mkdir(outDir);
end
if isfile(outputPath)
    delete(outputPath);
end

if excel_check_com_available()
    try
        local_write_com(outputPath, headers, data);
        return;
    catch
        if isfile(outputPath)
            delete(outputPath);
        end
    end
end

writecell([headers; data], outputPath, "Sheet", "Candidates", "FileType", "spreadsheet");
end

function T = local_load_candidates(inputPath)
if ~isfile(inputPath)
    error("export_candidates_xlsx:InputNotFound", "Input file not found: %s", inputPath);
end
T = read_jsonl(inputPath);
end

function T = local_reorder_columns(T)
preferred = [ ...
    "status", "note", "first_seen_run_id", "last_seen_run_id", ...
    "repro_signal_score", "fwci", "citation_percentile", "cited_by_count", "publication_year", ...
    "title", "doi", "doi_normalized", "openalex_id", "source_name", "type", ...
    "first_author_name", "first_author_institution", "last_author_name", "last_author_institution", ...
    "is_oa", "language", "topics"];

vars = string(T.Properties.VariableNames);
ordered = strings(0, 1);
for i = 1:numel(preferred)
    if any(vars == preferred(i))
        ordered(end+1, 1) = preferred(i); %#ok<AGROW>
    end
end
for i = 1:numel(vars)
    if ~any(ordered == vars(i))
        ordered(end+1, 1) = vars(i); %#ok<AGROW>
    end
end
T = T(:, cellstr(ordered));
end

function data = local_table_to_cell(T)
nRows = height(T);
nCols = width(T);
data = cell(nRows, nCols);
vars = T.Properties.VariableNames;

for r = 1:nRows
    for c = 1:nCols
        value = T.(vars{c})(r, :);
        if isstring(value)
            data{r, c} = char(value);
        elseif isnumeric(value) && isscalar(value)
            if isnan(value)
                data{r, c} = "";
            else
                data{r, c} = value;
            end
        elseif islogical(value) && isscalar(value)
            data{r, c} = double(value);
        else
            data{r, c} = char(string(value));
        end
    end
end
end

function local_write_com(outputPath, headers, data)
excel = actxserver("Excel.Application");
excel.Visible = false;
excel.DisplayAlerts = false;
wb = [];

try
    wb = excel.Workbooks.Add;
    while wb.Worksheets.Count > 1
        wb.Worksheets.Item(wb.Worksheets.Count).Delete;
    end

    ws = wb.Worksheets.Item(1);
    ws.Name = "Candidates";
    fullData = [headers; data];
    if ~isempty(fullData)
        rng = ws.Range(char(excel_a1_range(1, 1, size(fullData, 1), size(fullData, 2))));
        rng.Value = fullData;
    end
    excel_apply_header_style(ws, numel(headers));

    if ~isempty(data)
        try
            dataRange = ws.Range(char(excel_a1_range(1, 1, size(fullData, 1), size(fullData, 2))));
            tbl = ws.ListObjects.Add(1, dataRange, [], 1);
            tbl.Name = "CandidatesTable";
            tbl.TableStyle = "TableStyleMedium2";
        catch
        end
    end

    try
        ws.Activate;
        ws.Application.ActiveWindow.SplitRow = 1;
        ws.Application.ActiveWindow.FreezePanes = true;
        ws.Columns.AutoFit;
    catch
    end

    wb.SaveAs(char(local_abs_path(outputPath)), 51);
    wb.Close(false);
catch ex
    if ~isempty(wb)
        try; wb.Close(false); catch; end %#ok<TRYNC>
    end
    excel.Quit;
    excel.delete;
    rethrow(ex);
end

excel.Quit;
excel.delete;
end

function absPath = local_abs_path(pathText)
p = char(pathText);
if ispc
    if numel(p) >= 3 && p(2) == ":" && (p(3) == "\" || p(3) == "/")
        absPath = string(p);
        return;
    end
else
    if ~isempty(p) && p(1) == "/"
        absPath = string(p);
        return;
    end
end
absPath = string(fullfile(pwd, p));
end

function local_addpath_util(thisFileFullPath)
srcDir = fileparts(thisFileFullPath);
utilDir = fullfile(srcDir, '..', 'util');
if isfolder(utilDir) && ~any(strcmp(strsplit(path, pathsep), char(string(utilDir))))
    addpath(char(utilDir));
end
end
