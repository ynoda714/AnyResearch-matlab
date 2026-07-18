function values = normalize_candidate_doi(values)
%NORMALIZE_CANDIDATE_DOI  Normalize DOI-like values to lowercase DOI body.
%
%   Converts:
%     - "10.1000/ABC" -> "10.1000/abc"
%     - "https://doi.org/10.1000/ABC" -> "10.1000/abc"
%     - "doi:10.1000/ABC" -> "10.1000/abc"

values = string(values);
values(ismissing(values)) = "";
values = strtrim(values);
values = regexprep(values, '^https?://(dx\.)?doi\.org/', '', 'ignorecase');
values = regexprep(values, '^doi:', '', 'ignorecase');
values = lower(strtrim(values));
values(values == "") = "";
end
