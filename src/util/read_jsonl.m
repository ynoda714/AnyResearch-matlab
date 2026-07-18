function T = read_jsonl(filePath)
%READ_JSONL  Reads a JSONL file and returns it as a MATLAB table.
%
%   T = read_jsonl(filePath)
%
%   - filePath: path to a JSONL file (one JSON object per line)
%   - Returns : MATLAB table (column names from JSON keys, types inferred from values)
%
%   Type inference:
%   - All values are numeric (including null) -> double column (null becomes NaN)
%   - Otherwise -> string column (null becomes "")
%
%   Example:
%     T = read_jsonl("result/intermediate/normalized_works.jsonl");

if ~isfile(filePath)
    error("read_jsonl:NotFound", "File not found: %s", filePath);
end

rawText = fileread(filePath);
lines = strsplit(rawText, newline);
lines = strtrim(string(lines));
lines = lines(strlength(lines) > 0);

if isempty(lines)
    T = table();
    return;
end

n = numel(lines);
structs = cell(n, 1);
for i = 1:n
    structs{i} = jsondecode(char(lines(i)));
end

% Use fields of the first row as the column reference
allFields = fieldnames(structs{1});
nFields = numel(allFields);

colData = cell(1, nFields);
for j = 1:nFields
    fn = allFields{j};

    numVals = zeros(n, 1);
    strVals = strings(n, 1);
    isNumericCol = true;

    for i = 1:n
        if isfield(structs{i}, fn)
            v = structs{i}.(fn);
        else
            v = [];
        end

        if ischar(v)
            isNumericCol = false;
            strVals(i) = string(v);
        elseif isstring(v)
            isNumericCol = false;
            strVals(i) = v;
        elseif isempty(v)
            % JSON null or missing field → NaN / ""
            numVals(i) = NaN;
            strVals(i) = "";
        elseif isnumeric(v) && isscalar(v)
            numVals(i) = double(v);
            strVals(i) = string(v);
        elseif islogical(v) && isscalar(v)
            numVals(i) = double(v);
            strVals(i) = string(v);
        else
            % Complex types (arrays, etc.) -> stringify
            isNumericCol = false;
            strVals(i) = string(jsonencode(v));
        end
    end

    if isNumericCol
        colData{j} = numVals;
    else
        colData{j} = strVals;
    end
end

T = table(colData{:}, 'VariableNames', allFields);
end
