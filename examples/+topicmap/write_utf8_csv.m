function write_utf8_csv(T, outputPath)
%WRITE_UTF8_CSV Write a table to CSV with a UTF-8 BOM.

arguments
    T table
    outputPath (1,1) string
end

outDir = fileparts(char(outputPath));
if strlength(string(outDir)) > 0 && ~isfolder(outDir)
    mkdir(outDir);
end

tmpPath = string(tempname(fileparts(char(outputPath)))) + ".csv";
writetable(T, tmpPath, Encoding="UTF-8");

fidIn = fopen(tmpPath, "r");
if fidIn < 0
    error("topicmap:write_utf8_csv:OpenTempFailed", ...
        "Failed to open temporary CSV: %s", tmpPath);
end
bytes = fread(fidIn, Inf, "*uint8");
fclose(fidIn);

fidOut = fopen(outputPath, "w");
if fidOut < 0
    error("topicmap:write_utf8_csv:OpenOutputFailed", ...
        "Failed to open output CSV: %s", outputPath);
end
fwrite(fidOut, uint8([239 187 191]), "uint8");
fwrite(fidOut, bytes, "uint8");
fclose(fidOut);

delete(tmpPath);
end
