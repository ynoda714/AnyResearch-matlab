function entries = extract_openalex_raw_abstracts(rawPageJson)
%EXTRACT_OPENALEX_RAW_ABSTRACTS Extract raw abstract JSON per work from a page response.
%   entries = EXTRACT_OPENALEX_RAW_ABSTRACTS(rawPageJson) returns a struct array
%   with fields:
%     openalex_id        -- raw OpenAlex work URL id
%     raw_abstract_json  -- abstract_inverted_index JSON object or ""
%
%   This parser is string-aware and brace-balanced, so LaTeX-like keys such as
%   "$\frac{1}{2}$" do not break extraction.

rawStr = char(string(rawPageJson));
entries = struct('openalex_id', {}, 'raw_abstract_json', {});

resultsStart = regexp(rawStr, '"results"\s*:\s*\[', 'once');
if isempty(resultsStart)
    return;
end

arrayOpen = find(rawStr(resultsStart:end) == '[', 1, 'first') + resultsStart - 1;
if isempty(arrayOpen) || arrayOpen < 1
    return;
end

i = arrayOpen + 1;
while i <= strlength(rawStr)
    i = local_skip_ws(rawStr, i);
    if i > strlength(rawStr) || rawStr(i) == ']'
        break;
    end
    if rawStr(i) == ','
        i = i + 1;
        continue;
    end
    if rawStr(i) ~= '{'
        i = i + 1;
        continue;
    end

    objectEnd = local_scan_balanced(rawStr, i, '{', '}');
    if objectEnd < i
        break;
    end

    objStr = rawStr(i:objectEnd);
    [openalexId, hasId] = local_extract_top_level_string_field(objStr, "id");
    [abstractValue, hasAbstractField] = local_extract_top_level_raw_field(objStr, "abstract_inverted_index");
    if hasId
        rawAbstractJson = "";
        if hasAbstractField
            abstractValue = strtrim(string(abstractValue));
            if abstractValue ~= "null"
                rawAbstractJson = abstractValue;
            end
        end
        entries(end+1, 1).openalex_id = openalexId; %#ok<AGROW>
        entries(end).raw_abstract_json = rawAbstractJson;
    end

    i = objectEnd + 1;
end
end

function idx = local_skip_ws(rawStr, idx)
n = strlength(rawStr);
while idx <= n && isspace(rawStr(idx))
    idx = idx + 1;
end
end

function endIdx = local_scan_balanced(rawStr, startIdx, openChar, closeChar)
n = strlength(rawStr);
depth = 0;
inString = false;
isEscaped = false;
endIdx = -1;

for k = startIdx:n
    ch = rawStr(k);
    if inString
        if isEscaped
            isEscaped = false;
        elseif ch == '\'
            isEscaped = true;
        elseif ch == '"'
            inString = false;
        end
        continue;
    end

    if ch == '"'
        inString = true;
    elseif ch == openChar
        depth = depth + 1;
    elseif ch == closeChar
        depth = depth - 1;
        if depth == 0
            endIdx = k;
            return;
        end
    end
end
end

function [value, found] = local_extract_top_level_string_field(objStr, fieldName)
[rawValue, found] = local_extract_top_level_raw_field(objStr, fieldName);
if ~found
    value = "";
    return;
end

rawValue = char(strtrim(string(rawValue)));
if strlength(rawValue) < 2 || rawValue(1) ~= '"' || rawValue(end) ~= '"'
    value = "";
    found = false;
    return;
end

value = local_decode_json_string(rawValue(2:end-1));
end

function [value, found] = local_extract_top_level_raw_field(objStr, fieldName)
value = "";
found = false;
n = strlength(objStr);
if n < 2 || objStr(1) ~= '{'
    return;
end

i = 2;
while i < n
    i = local_skip_ws(objStr, i);
    if i >= n || objStr(i) == '}'
        return;
    end
    if objStr(i) == ','
        i = i + 1;
        continue;
    end
    if objStr(i) ~= '"'
        i = i + 1;
        continue;
    end

    keyEnd = local_scan_json_string(objStr, i);
    if keyEnd <= i
        return;
    end

    keyRaw = objStr(i + 1:keyEnd - 1);
    keyName = local_decode_json_string(keyRaw);

    i = local_skip_ws(objStr, keyEnd + 1);
    if i > n || objStr(i) ~= ':'
        return;
    end

    i = local_skip_ws(objStr, i + 1);
    if i > n
        return;
    end

    valueStart = i;
    switch objStr(i)
        case '"'
            valueEnd = local_scan_json_string(objStr, i);
        case '{'
            valueEnd = local_scan_balanced(objStr, i, '{', '}');
        case '['
            valueEnd = local_scan_balanced(objStr, i, '[', ']');
        otherwise
            valueEnd = i;
            while valueEnd <= n && ~ismember(objStr(valueEnd), [',', '}'])
                valueEnd = valueEnd + 1;
            end
            valueEnd = valueEnd - 1;
    end

    if valueEnd < valueStart
        return;
    end

    if keyName == fieldName
        value = string(objStr(valueStart:valueEnd));
        found = true;
        return;
    end

    i = valueEnd + 1;
end
end

function endIdx = local_scan_json_string(rawStr, startIdx)
n = strlength(rawStr);
isEscaped = false;
endIdx = -1;
for k = startIdx + 1:n
    ch = rawStr(k);
    if isEscaped
        isEscaped = false;
    elseif ch == '\'
        isEscaped = true;
    elseif ch == '"'
        endIdx = k;
        return;
    end
end
end

function value = local_decode_json_string(rawValue)
try
    value = string(jsondecode(['"' char(rawValue) '"']));
catch
    % Fallback keeps extraction resilient if a future payload contains an
    % unexpected escape sequence that jsondecode rejects.
    value = string(rawValue);
    value = regexprep(value, '(?<!\\)\\u([0-9a-fA-F]{4})', '${char(hex2dec($1))}');
    value = replace(value, '\"', '"');
    value = replace(value, '\\', '\');
    value = replace(value, '\/', '/');
end
end
