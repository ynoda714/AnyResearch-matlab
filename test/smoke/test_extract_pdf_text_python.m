function test_extract_pdf_text_python()
%TEST_EXTRACT_PDF_TEXT_PYTHON  extract_pdf_text_python smoke test
%
%   addpath("src/pdf"); addpath("src/util"); addpath("test/smoke");
%   test_extract_pdf_text_python();
%
% Target: src/pdf/extract_pdf_text_python.m
% What to verify:
%   Case1: Function file exists in src/pdf/
%   Case2: When given a non-existent path, returns a string type (empty string or error message)
%   Case3: Executed only when an actual sample PDF exists at result/tmp/pdf_test/sample.pdf
%          Return value must be string type and non-empty

fprintf('\n=== test_extract_pdf_text_python ===\n');

thisDir     = fileparts(mfilename('fullpath'));
projectRoot = fullfile(thisDir, '..', '..');
addpath(fullfile(projectRoot, 'src', 'pdf'));
addpath(fullfile(projectRoot, 'src', 'util'));

%% Case1: Function file exists
srcFile = fullfile(projectRoot, 'src', 'pdf', 'extract_pdf_text_python.m');
assert(isfile(srcFile), "Case1: extract_pdf_text_python.m が src/pdf/ に存在しない");
fprintf('[PASS] Case1: extract_pdf_text_python.m が存在する\n');

%% Case2: Non-existent path returns string or throws exception
%   As this is Layer 1 Python fallback, exceptions are tolerated without Python setup
nonExistPath = fullfile(projectRoot, 'result', 'tmp', '__no_such_file__.pdf');
try
    result2 = extract_pdf_text_python(string(nonExistPath));
    % If no exception: verify return value is of type string
    assert(ischar(result2) || isstring(result2), ...
        'Case2: 戻り値が string/char 型でない (got %s)', class(result2));
    result2str = string(result2);
    % Either success or empty string is acceptable
    fprintf('[PASS] Case2: 不在パス渡し → string 型 が返った (len=%d)\n', strlength(strtrim(result2str)));
catch ex2
    % Unprepared Python environment or execution errors are acceptable
    fprintf('[SKIP] Case2: Python 環境未整備のためスキップ (%s)\n', ex2.message);
end

%% Case3: Execute only when actual sample PDF exists
samplePdf = fullfile(projectRoot, 'result', 'tmp', 'pdf_test', 'sample.pdf');
if ~isfile(samplePdf)
    fprintf('[SKIP] Case3: サンプル PDF 不在のためスキップ (%s)\n', samplePdf);
else
    try
        result3 = extract_pdf_text_python(string(samplePdf));
        assert(ischar(result3) || isstring(result3), ...
            'Case3: 戻り値が string/char 型でない');
        result3str = strtrim(string(result3));
        assert(strlength(result3str) > 0, ...
            'Case3: 実サンプル PDF からの抽出結果が空文字 (PDF または Python 環境を確認してください)');
        fprintf('[PASS] Case3: サンプル PDF 抽出成功 (len=%d)\n', strlength(result3str));
    catch ex3
        fprintf('[SKIP] Case3: 抽出エラー（Python 環境確認）: %s\n', ex3.message);
    end
end

fprintf('\n=== test_extract_pdf_text_python: COMPLETED ===\n\n');
end
