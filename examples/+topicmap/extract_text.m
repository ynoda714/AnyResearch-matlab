function text = extract_text(data, opts)
%EXTRACT_TEXT Build example-ready text from title and abstract columns.
%
%   text = topicmap.extract_text(T)
%
%   Input:
%     T : table with title and optional abstract columns
%
%   Output:
%     text : string vector. Each row uses:
%            - title + newline + abstract when abstract is present
%            - title only when abstract is empty

arguments
    data
    opts.maxChars (1,1) double = inf
end

if ~istable(data)
    error("topicmap:extract_text:TableRequired", ...
        "Input must be a table.");
end

vars = string(data.Properties.VariableNames);
if ~ismember("title", vars)
    error("topicmap:extract_text:MissingTitle", ...
        "title column is required.");
end

titleVals = string(data.title);
if ismember("abstract", vars)
    abstractVals = string(data.abstract);
else
    abstractVals = repmat("", height(data), 1);
end

titleVals(ismissing(titleVals)) = "";
abstractVals(ismissing(abstractVals)) = "";

text = strings(height(data), 1);
for i = 1:height(data)
    titlePart = strtrim(titleVals(i));
    abstractPart = strtrim(abstractVals(i));

    if strlength(titlePart) == 0 && strlength(abstractPart) == 0
        text(i) = "";
    elseif strlength(abstractPart) == 0
        text(i) = titlePart;
    elseif strlength(titlePart) == 0
        text(i) = abstractPart;
    else
        text(i) = titlePart + newline + abstractPart;
    end

    if isfinite(opts.maxChars) && strlength(text(i)) > opts.maxChars
        text(i) = extractBetween(text(i), 1, opts.maxChars);
    end
end
end
