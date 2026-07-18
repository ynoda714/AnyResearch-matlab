function result = supplement_title_abstract_from_pdf(baseCsv, pdfTextInput, outputCsv)
arguments
    baseCsv (1,1) string
    pdfTextInput (1,1) string
    outputCsv (1,1) string
end

if ~isfile(baseCsv)
    error("supplement_title_abstract_from_pdf:BaseNotFound", "Base CSV not found: %s", baseCsv);
end

B = readtable(baseCsv, "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",", "ReadVariableNames", true);
result = supplement_title_abstract_from_pdf_table(B, pdfTextInput, outputCsv=outputCsv);
if isfield(result, 'T')
    result = rmfield(result, 'T');
end
end
