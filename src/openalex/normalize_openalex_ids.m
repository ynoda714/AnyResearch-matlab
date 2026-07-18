function ids = normalize_openalex_ids(vals)
%NORMALIZE_OPENALEX_IDS  Normalizes OpenAlex IDs to canonical trimmed, URL-prefix-stripped form.
%
%   Converts https://openalex.org/I1234 -> I1234,
%   accepts pipe-delimited strings such as "I1|I2",
%   and returns a deduplicated, non-empty string column vector.
%
%   Usage:
%     ids = normalize_openalex_ids("https://openalex.org/I4210115105")
%     ids = normalize_openalex_ids(["I4210115105", "I4210115105"])

vals = string(vals);
vals(ismissing(vals)) = "";

pieces = strings(0, 1);
for i = 1:numel(vals)
    v = strtrim(vals(i));
    if v == ""
        continue;
    end
    splitVals = split(v, "|");
    splitVals = strtrim(splitVals);
    splitVals = splitVals(splitVals ~= "");
    if ~isempty(splitVals)
        pieces = [pieces; splitVals]; %#ok<AGROW>
    end
end

pieces = regexprep(pieces, '^https?://openalex\.org/', '', 'ignorecase');
pieces = upper(pieces);
pieces = pieces(pieces ~= "");
ids = unique(pieces, 'stable');
end
