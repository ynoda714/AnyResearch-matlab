function write_jsonl(T, filePath)
%WRITE_JSONL  Writes a MATLAB table to a JSONL file (one JSON object per line).
%
%   write_jsonl(T, filePath)
%
%   - T       : MATLAB table
%   - filePath: output file path (.jsonl extension recommended)
%   - Encoding: UTF-8 (no BOM)
%   - Each row is an independent JSON object
%
%   Type handling:
%   - string (missing) -> ""
%   - NaN (numeric)    -> JSON null
%   - logical          -> JSON true/false
%
%   Example:
%     T = table(["W001"; "W002"], [1.5; NaN], 'VariableNames', ["id", "score"]);
%     write_jsonl(T, "result/intermediate/normalized_works.jsonl");

outDir = fileparts(filePath);
if strlength(outDir) > 0 && ~isfolder(outDir)
    mkdir(outDir);
end

fid = fopen(filePath, 'w', 'n', 'UTF-8');
if fid < 0
    error("write_jsonl:OpenFailed", "Cannot open file: %s", filePath);
end
cleanup = onCleanup(@() fclose(fid));

colNames = string(T.Properties.VariableNames);
nCols = numel(colNames);

for i = 1:height(T)
    s = struct();
    for j = 1:nCols
        cn = char(colNames(j));
        v = T.(cn)(i);
        if isstring(v)
            if ismissing(v)
                s.(cn) = "";
            else
                s.(cn) = char(v);
            end
        elseif iscell(v)
            cv = v{1};
            if isstring(cv) && ismissing(cv)
                s.(cn) = "";
            elseif isstring(cv) || ischar(cv)
                s.(cn) = char(cv);
            else
                s.(cn) = cv;
            end
        elseif isnumeric(v) && isscalar(v)
            % NaN -> JSON null is handled automatically by jsonencode
            s.(cn) = v;
        elseif islogical(v) && isscalar(v)
            s.(cn) = v;
        else
            % All other types -> stringify
            s.(cn) = char(string(v));
        end
    end
    fprintf(fid, '%s\n', jsonencode(s));
end
end
