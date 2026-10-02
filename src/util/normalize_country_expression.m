function text = normalize_country_expression(input)
%NORMALIZE_COUNTRY_EXPRESSION  Normalize the Country filter for OpenAlex (ADR-004).
%
%   TEXT = NORMALIZE_COUNTRY_EXPRESSION(INPUT)
%
%   "|" = OR, "+" = AND (works with authors from every listed country).
%   "," and ";" are accepted as OR separators. Codes are upper-cased 2-letter
%   ISO codes; duplicates are removed. AND and OR cannot be mixed.
%   Empty input returns "". Invalid input throws
%   normalize_country_expression:<BadCode|BadSeparator|MixedOperators>.
arguments
    input (1,1) string
end

s = strtrim(input);
if s == ""
    text = "";
    return;
end
s = replace(replace(s, ",", "|"), ";", "|");
hasOr = contains(s, "|");
hasAnd = contains(s, "+");
if hasOr && hasAnd
    error("normalize_country_expression:MixedOperators", ...
        "Country: do not mix | (OR) and + (AND); use one of them.");
end
op = "|";
if hasAnd
    op = "+";
end

parts = strtrim(split(s, op));
for i = 1:numel(parts)
    if ~isempty(regexp(char(parts(i)), '\s', 'once'))
        error("normalize_country_expression:BadSeparator", ...
            "Country: separate codes with | (OR) or + (AND), not spaces: %s", input);
    end
    if isempty(regexp(char(parts(i)), '^[A-Za-z]{2}$', 'once'))
        error("normalize_country_expression:BadCode", ...
            "Country: each code must be 2 letters (e.g. JP|US); got '%s'.", parts(i));
    end
end
text = strjoin(unique(upper(parts), 'stable'), op);
end
