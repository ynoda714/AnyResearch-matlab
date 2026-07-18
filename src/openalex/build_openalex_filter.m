function filterText = build_openalex_filter( ...
        fromDate, toDate, language, requireOpenAccess, firstAuthorInstitutionIds, filterCountryCode, filterType, requireAbstract, excludeRetracted, citedByMin, citedByMax)
%BUILD_OPENALEX_FILTER  Builds a filter string for the OpenAlex API.
%
%   Returns a comma-separated filter= string joining all specified conditions.
%   If no conditions are given, returns "is_oa:true,language:en" as default.
%
%   Usage:
%     f = build_openalex_filter("2023-01-01","2025-12-31","en",true,[],"","article",true,true,100,500)

if nargin < 6
    filterCountryCode = "";
end
if nargin < 7
    filterType = "";
end
if nargin < 8
    requireAbstract = true;
end
if nargin < 9
    excludeRetracted = true;
end
if nargin < 10
    citedByMin = 0;
end
if nargin < 11
    citedByMax = 0;
end
parts = strings(0,1);
firstAuthorInstitutionIds = normalize_openalex_ids(firstAuthorInstitutionIds);
if ~isempty(firstAuthorInstitutionIds)
    parts(end+1) = "authorships.institutions.id:" + strjoin(firstAuthorInstitutionIds, "|"); %#ok<AGROW>
end
if strlength(strtrim(fromDate)) > 0
    parts(end+1) = "from_publication_date:" + string(fromDate); %#ok<AGROW>
end
if strlength(strtrim(toDate)) > 0
    parts(end+1) = "to_publication_date:" + string(toDate); %#ok<AGROW>
end
if requireOpenAccess
    parts(end+1) = "is_oa:true"; %#ok<AGROW>
end
if requireAbstract
    parts(end+1) = "has_abstract:true"; %#ok<AGROW>
end
if excludeRetracted
    parts(end+1) = "is_retracted:false"; %#ok<AGROW>
end
if ~isempty(citedByMin) && isfinite(citedByMin) && citedByMin > 0
    parts(end+1) = "cited_by_count:>" + string(round(citedByMin)); %#ok<AGROW>
end
if ~isempty(citedByMax) && isfinite(citedByMax) && citedByMax > 0
    parts(end+1) = "cited_by_count:<" + string(round(citedByMax)); %#ok<AGROW>
end
if strlength(strtrim(language)) > 0
    parts(end+1) = "language:" + string(language); %#ok<AGROW>
end
if strlength(strtrim(filterCountryCode)) > 0
    parts(end+1) = "authorships.institutions.country_code:" + strtrim(string(filterCountryCode)); %#ok<AGROW>
end
% filterType: multiple types can be given as "article,review". Pipe-separated values are expanded to type:val|val.
if strlength(strtrim(filterType)) > 0
    types = strtrim(strsplit(strtrim(string(filterType)), ","));
    types = types(strlength(types) > 0);
    if numel(types) == 1
        parts(end+1) = "type:" + types(1); %#ok<AGROW>
    elseif numel(types) > 1
        parts(end+1) = "type:" + strjoin(types, "|"); %#ok<AGROW>
    end
end
if isempty(parts)
    filterText = "is_oa:true,language:en";
else
    filterText = strjoin(parts, ",");
end
end
