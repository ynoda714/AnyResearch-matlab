function result = build_final_csv(baseCsv, outputCsv, queryText, opts)
arguments
    baseCsv (1,1) string
    outputCsv (1,1) string
    queryText (1,1) string
    opts.metadataCsv  (1,1) string = ""
    opts.evidenceCsv  (1,1) string = ""
    opts.pdfReportCsv (1,1) string = ""
end

if ~isfile(baseCsv)
    error("build_final_csv:BaseNotFound", "Base CSV not found: %s", baseCsv);
end

B = readtable(baseCsv, "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",", "ReadVariableNames", true);
M = table();
E = table();
R = table();
if opts.metadataCsv ~= "" && isfile(opts.metadataCsv)
    M = readtable(opts.metadataCsv, "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",", "ReadVariableNames", true);
end
if opts.evidenceCsv ~= "" && isfile(opts.evidenceCsv)
    E = readtable(opts.evidenceCsv, "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",", "ReadVariableNames", true);
end
if opts.pdfReportCsv ~= "" && isfile(opts.pdfReportCsv)
    R = readtable(opts.pdfReportCsv, "TextType", "string", "VariableNamingRule", "preserve", "Delimiter", ",", "ReadVariableNames", true);
end

result = build_final_table(B, queryText, ...
    metadataTable=M, evidenceTable=E, pdfReportTable=R, outputCsv=outputCsv);
end
