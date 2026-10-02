function p = build_openalex_search_params(query, searchField)
%BUILD_OPENALEX_SEARCH_PARAMS  Split a Query into OpenAlex search= / filter parts (ADR-004).
%
%   P = BUILD_OPENALEX_SEARCH_PARAMS(QUERY, SEARCHFIELD)
%
%   SEARCHFIELD "all" (default behavior): P.search carries the query and OpenAlex
%   also searches full text. "title_and_abstract": P.filterPart carries
%   "title_and_abstract.search:<query>" to be appended to the filter.
%   Commas are removed from the filter value because they separate filters.
arguments
    query (1,1) string
    searchField (1,1) string = "all"
end

if ~any(searchField == ["all", "title_and_abstract"])
    error("build_openalex_search_params:BadField", ...
        "searchField must be ""all"" or ""title_and_abstract"" (got ""%s"").", searchField);
end

e = parse_search_expression(query);
p = struct('search', "", 'filterPart', "");
if e.openalex == ""
    return;
end
if searchField == "all"
    p.search = e.openalex;
else
    p.filterPart = "title_and_abstract.search:" + strtrim(replace(e.openalex, ",", " "));
end
end
