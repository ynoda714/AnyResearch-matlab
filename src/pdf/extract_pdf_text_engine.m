function [text, status, message] = extract_pdf_text_engine(pdfPath)
% extract_pdf_text_engine - PDF text extraction (two-stage engine)
%
%   Priority:
%     1. extractFileText() — MATLAB Text Analytics Toolbox (license required)
%     2. Python pdfminer/pdfplumber — src/python/extract_pdf_text.py (venv required)
%
%   Engine 2 is tried only when Engine 1 fails (e.g. encrypted PDF).
%   Returns status="error" when both engines fail.
%
%   Return values:
%     text    : Extracted text (empty string on failure)
%     status  : "ok" | "ok_python_fallback" | "empty" | "error"
%     message : Error message (empty string on success)
%
%   Distribution note:
%     If the Python environment (venv) is not available, Engine 2 cannot be used,
%     and encrypted PDFs will not be supported. Normal PDFs are handled by Engine 1.

text    = "";
status  = "error";  %#ok<NASGU>
message = "";       %#ok<NASGU>

% --- Engine 1: MATLAB extractFileText() ---
try
    text = extractFileText(string(pdfPath));
    text = string(text);
    if strlength(strtrim(text)) > 0
        status  = "ok";
        message = "";
        return;
    else
        % Extraction succeeded but returned empty text -> fall back to Engine 2
        message = "extractFileText returned empty text";
    end
catch ex1
    message = string(ex1.message);
    % Engine 1 failed (e.g. encrypted PDF) -> fall back to Engine 2
end

% --- Engine 2: Python pdfminer (fallback) ---
try
    if count(py.sys.path, 'src/python') == 0
        insert(py.sys.path, int32(0), 'src/python');
    end
    py_mod = py.importlib.import_module('extract_pdf_text');
    py_result = py_mod.extract_text(pdfPath);
    pyText = string(py_result);
    if strlength(strtrim(pyText)) > 0
        text    = pyText;
        status  = "ok_python_fallback";
        message = "";
        return;
    else
        status  = "empty";
        message = "both engines returned empty text";
    end
catch ex2
    status  = "error";
    message = "engine1: " + message + " / engine2: " + string(ex2.message);
end
end
