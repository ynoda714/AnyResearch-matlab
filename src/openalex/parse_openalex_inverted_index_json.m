function abstractText = parse_openalex_inverted_index_json(absJson)
%PARSE_OPENALEX_INVERTED_INDEX_JSON Reconstruct abstract text from raw JSON.
%   absJson must be a JSON object string in the format
%   '{"word1":[0,3],"word2":[1],...}'.

abstractText = "";
if isempty(absJson) || string(absJson) == "" || string(absJson) == "{}"
    return;
end

rawStr = char(string(absJson));

[~, kv] = regexp(rawStr, ...
    '"((?:[^"\\]|\\.)*)"\s*:\s*\[([^\]]*)\]', ...
    'match', 'tokens');

if isempty(kv)
    return;
end

maxPos = 0;
for k = 1:numel(kv)
    posStr = strtrim(kv{k}{2});
    if isempty(posStr)
        continue;
    end
    nums = str2double(strsplit(posStr, ','));
    nums = nums(~isnan(nums) & nums >= 0);
    if ~isempty(nums)
        maxPos = max(maxPos, max(nums));
    end
end

if maxPos < 0
    return;
end

tokenArr = repmat({""}, maxPos + 2, 1);
for k = 1:numel(kv)
    word = local_decode_json_string(kv{k}{1});
    posStr = strtrim(kv{k}{2});
    if isempty(posStr)
        continue;
    end
    nums = str2double(strsplit(posStr, ','));
    for j = 1:numel(nums)
        p = nums(j);
        if ~isnan(p) && p >= 0
            idx = p + 1;
            if idx <= numel(tokenArr)
                tokenArr{idx} = char(word);
            end
        end
    end
end

nonEmpty = tokenArr(~strcmp(tokenArr, ""));
abstractText = strtrim(strjoin(string(nonEmpty), " "));
end

function value = local_decode_json_string(rawValue)
try
    value = string(jsondecode(['"' char(rawValue) '"']));
catch
    value = string(rawValue);
    value = regexprep(value, '(?<!\\)\\u([0-9a-fA-F]{4})', '${char(hex2dec($1))}');
    value = replace(value, '\"', '"');
    value = replace(value, '\\', '\');
    value = replace(value, '\/', '/');
end
end
