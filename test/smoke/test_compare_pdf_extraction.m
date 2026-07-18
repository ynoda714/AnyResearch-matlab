%% test_compare_pdf_extraction.m
% Quality comparison: extractFileText() (MATLAB Text Analytics Toolbox) vs Python pdfminer
% + Verify the integrated local_extract_pdf_text() engine (including fallback)
%
% Objectives:
%   - Assess feasibility of MATLAB-native PDF extraction and removing Python dependency
%   - Verify that encrypted PDF (W4318693047) triggers ok_python_fallback via Python fallback
%   - For each PDF: output extraction result, char count, keyword presence, and head preview
%
% Prerequisites:
%   - Text Analytics Toolbox is installed
%   - PDFs stored in result/runs/20260312_130355/
%
% How to run (MATLAB command window) --- Toolbox only:
%   cd('d:\workspace\20260207_ML_MCP\20260308_ML_MCP_OpenAlex_v2');
%   addpath('test/smoke'); addpath('src/pdf');
%   test_compare_pdf_extraction()
%
% How to run --- Integration test including Python fallback (pyenv setup required):
%   pyenv('Version', 'd:\workspace\20260207_ML_MCP\20260308_ML_MCP_OpenAlex_v2\venv\Scripts\python.exe')
%   cd('d:\workspace\20260207_ML_MCP\20260308_ML_MCP_OpenAlex_v2');
%   addpath('test/smoke'); addpath('src/pdf');
%   test_compare_pdf_extraction()
%
% Note: pyenv only needs to be configured once after MATLAB session startup.
%   Check current setting: pyenv()
%   To reset: pyenv('Version','MATLABRoot')

function test_compare_pdf_extraction()

%% --- Settings ---
runDir      = "result/runs/20260312_130355";
pdfAutoDir  = fullfile(runDir, "pdf_cache", "auto");
pdfManDir   = fullfile(runDir, "pdf_cache", "manual");
jsonlPath   = fullfile(runDir, "intermediate", "pdf_text_extracted.jsonl");
keyword     = "matlab";
previewLen  = 150;

% Python full-text character counts (reference: after cleaning)
% W3012508418:100735, W3157865770:31500, W4249458080:35746,
% W4280594706:48731,  W4283214927:48386, W4318693047:35448,
% W4318954850:46072,  W4389804441:58743, W3121483063:110017
% Contains MATLAB: W4280594706 only False, others True

%% --- Path settings ---
% Add path to use local_extract_pdf_text() from src/pdf
thisDir     = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(thisDir));  % test/smoke -> test -> root
addpath(fullfile(projectRoot, 'src', 'pdf'));

%% --- Toolbox check ---
if ~local_has_text_analytics_toolbox()
    error('test_compare_pdf_extraction:NoToolbox', ...
        'Text Analytics Toolbox が見つかりません。addons コマンドで確認してください。');
end

%% --- PDF file listing ---
d1 = dir(fullfile(pdfAutoDir, "*.pdf"));
d2 = dir(fullfile(pdfManDir,  "*.pdf"));
pdfFiles = [d1; d2];

if isempty(pdfFiles)
    error('test_compare_pdf_extraction:NoPDF', 'PDFが見つかりません: %s', runDir);
end

%% --- Load Python-extracted JSONL as reference (full text verified separately) ---
pyRef = local_load_jsonl(jsonlPath);

%% --- Header output ---
fprintf('\n========== PDF抽出比較: extractFileText() vs Python pdfminer ==========\n');
fprintf('キーワード: "%s"\n', keyword);
fprintf('%-22s %9s %9s %10s %10s  %s\n', ...
    'ID', 'ML_chars', 'Py_chars', 'ML_kw', 'Py_kw', 'status');
fprintf('%s\n', repmat('-', 1, 80));

%% --- Main loop ---
nOk = 0; nFail = 0;
for i = 1:numel(pdfFiles)
    pdfPath   = string(fullfile(pdfFiles(i).folder, pdfFiles(i).name));
    workId    = strrep(string(pdfFiles(i).name), ".pdf", "");
    openalexId = "https://openalex.org/" + workId;

    % --- MATLAB extractFileText ---
    mlText  = "";
    mlOk    = false;
    mlMsg   = "";
    try
        mlText = extractFileText(pdfPath);
        mlOk   = true;
    catch ex
        mlMsg = string(ex.message);
    end

    % --- Python reference values (from JSONL / truncated to 8000 chars, reference only) ---
    pyExcerpt = "";
    for j = 1:numel(pyRef)
        if pyRef(j).openalex_id == openalexId
            pyExcerpt = pyRef(j).body_text_excerpt;
            break;
        end
    end

    mlLen = strlength(mlText);
    pyLen = strlength(pyExcerpt);  % Note: JSONL truncated at maxBodyChars=8000, reference only
    mlKw  = contains(lower(mlText),    lower(keyword));
    pyKw  = contains(lower(pyExcerpt), lower(keyword));  % match within excerpt (may differ from full text)

    if mlOk
        nOk = nOk + 1;
        statusStr = "OK";
    else
        nFail = nFail + 1;
        statusStr = "FAIL";
    end

    fprintf('%-22s %9d %9d %10s %10s  %s\n', ...
        workId, mlLen, pyLen, string(mlKw), string(pyKw), statusStr);

    % Head preview
    if mlOk && mlLen > 0
        preview = extractBefore(mlText + " ", min(previewLen + 1, mlLen + 1));
        preview = regexprep(preview, '\s+', ' ');
        fprintf('  [ML先頭] %s\n', preview);
    elseif ~mlOk
        fprintf('  [ML ERROR] %s\n', mlMsg);
    end
end

%% --- Summary ---
fprintf('%s\n', repmat('-', 1, 80));
fprintf('結果: OK=%d / FAIL=%d / 計=%d\n', nOk, nFail, numel(pdfFiles));
fprintf('\n注記:\n');
fprintf('  Py_chars は比較対象JSONL内 excerpt の文字数。\n');
fprintf('  既存JSONLが古い場合は旧 maxBodyChars=8000 で切断済みの可能性がある。\n');
fprintf('  新規実行後のJSONLでは main_run_pipeline の pdfTextMaxBodyChars 設定値（既定100000）が適用される。\n');
fprintf('  ML_kw / Py_kw はそれぞれの抽出範囲での "%s" 含有。\n', keyword);
fprintf('==========================================================================\n\n');

if nFail == 0
    fprintf('[判定] extractFileText() で全件抽出成功。\n');
else
    fprintf('[判定] %d件で extractFileText() が失敗。Python フォールバックを下記で確認してください。\n', nFail);
end
fprintf('\n');

%% --- Section 2: local_extract_pdf_text() integration engine test ---
% Verify that Python fallback works for encrypted PDF (W4318693047).
% If pyenv is not configured, engine2_status will be "error" (expected).

fprintf('========== 統合エンジン (local_extract_pdf_text) テスト ==========\n');

% Check pyenv setting
pe = pyenv();
if strlength(string(pe.Version)) == 0
    fprintf('[pyenv] 未設定。Python フォールバックは利用不可。\n');
    fprintf('        pyenv 設定コマンド:\n');
    fprintf('        pyenv(''Version'',''%s'')\n', ...
        fullfile(strtrim(string(projectRoot)), 'venv', 'Scripts', 'python.exe'));
    fprintf('        上記コマンド実行後にこの関数を再実行してください。\n\n');
else
    fprintf('[pyenv] Version=%s\n\n', string(pe.Version));
end

% Directly test the two-stage engine with encrypted PDF
encPdf = fullfile(runDir, "pdf_cache", "auto", "W4318693047.pdf");
if isfile(encPdf)
    [t, s, m] = extract_pdf_text_engine(encPdf);
    fprintf('W4318693047 (暗号化PDF)\n');
    fprintf('  status  : %s\n', s);
    fprintf('  chars   : %d\n', strlength(t));
    if strlength(m) > 0
        fprintf('  message : %s\n', m);
    end
    if s == "ok_python_fallback"
        fprintf('  [OK] Python フォールバック成功\n');
    elseif s == "ok"
        fprintf('  [INFO] extractFileText() で抽出成功（暗号化が解除されているか確認してください）\n');
    else
        fprintf('  [INFO] 両エンジン失敗。pyenv 未設定か venv が正しく構築されていない可能性があります。\n');
    end
else
    fprintf('W4318693047.pdf が見つかりません: %s\n', encPdf);
end
fprintf('==========================================================================\n\n');

end

%% --- Local functions ---

function tf = local_has_text_analytics_toolbox()
    v = ver;
    names = {v.Name};
    tf = any(strcmp(names, 'Text Analytics Toolbox'));
end

function rows = local_load_jsonl(jsonlPath)
    rows = struct('openalex_id', {}, 'body_text_excerpt', {}, 'extract_status', {});
    if ~isfile(jsonlPath)
        warning('JSONL not found: %s', jsonlPath);
        return;
    end
    lines = readlines(jsonlPath);
    idx = 1;
    for i = 1:numel(lines)
        line = strtrim(lines(i));
        if strlength(line) == 0, continue; end
        try
            j = jsondecode(char(line));
            rows(idx).openalex_id = string(j.openalex_id);
            be = "";
            if isfield(j, 'body_text_excerpt') && ~isempty(j.body_text_excerpt)
                be = string(j.body_text_excerpt);
            end
            rows(idx).body_text_excerpt = be;
            es = "";
            if isfield(j, 'extract_status'), es = string(j.extract_status); end
            rows(idx).extract_status = es;
            idx = idx + 1;
        catch
            % skip malformed line
        end
    end
end
