function text = extract_pdf_text_python(pdf_path)
% extract_pdf_text_python - PDF body text extraction (Python wrapper) [DEPRECATED]
%
%   DEPRECATED: do not call this function directly.
%   Only called via local_extract_pdf_text() inside extract_pdf_text_from_report.m.
%   (Acts as a fallback when Engine 1: extractFileText() fails.)
%
%   pdf_path: Path to the PDF file
%   text: Extracted text (empty string on failure)

if count(py.sys.path,'src/python') == 0
    insert(py.sys.path,int32(0),'src/python');
end

try
    py_mod = py.importlib.import_module('extract_pdf_text');
    py_result = py_mod.extract_text(pdf_path);
    text = string(py_result);
catch ME
    warning('Python PDF extraction failed: %s', ME.message);
    text = "";
end
end
