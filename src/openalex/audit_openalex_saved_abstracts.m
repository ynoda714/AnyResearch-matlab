function report = audit_openalex_saved_abstracts(rawDir)
%AUDIT_OPENALEX_SAVED_ABSTRACTS Compare saved OpenAlex abstracts with raw-page reconstruction.
%   report = AUDIT_OPENALEX_SAVED_ABSTRACTS(rawDir) reads:
%     rawDir/openalex_raw.jsonl
%     rawDir/openalex_page_*.json
%   and returns a table of mismatches plus summary counts.

arguments
    rawDir (1,1) string
end

rawDir = strtrim(rawDir);
if rawDir == "" || ~isfolder(rawDir)
    error("audit_openalex_saved_abstracts:RawDirNotFound", ...
        "Raw directory not found: %s", rawDir);
end

savedJsonlPath = fullfile(rawDir, 'openalex_raw.jsonl');
if ~isfile(savedJsonlPath)
    error("audit_openalex_saved_abstracts:SavedJsonlNotFound", ...
        "Saved OpenAlex JSONL not found: %s", savedJsonlPath);
end

savedTable = read_jsonl(savedJsonlPath);
if ~ismember("openalex_id", string(savedTable.Properties.VariableNames)) || ...
        ~ismember("abstract", string(savedTable.Properties.VariableNames))
    error("audit_openalex_saved_abstracts:MissingColumns", ...
        "Saved JSONL must include openalex_id and abstract columns.");
end

pageFiles = dir(fullfile(rawDir, 'openalex_page_*.json'));
if isempty(pageFiles)
    error("audit_openalex_saved_abstracts:RawPagesNotFound", ...
        "No raw OpenAlex page files found under: %s", rawDir);
end
pageNames = sort(string({pageFiles.name}));

rebuiltMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:numel(pageNames)
    rawPageJson = fileread(fullfile(rawDir, pageNames(i)));
    entries = extract_openalex_raw_abstracts(rawPageJson);
    for j = 1:numel(entries)
        rebuiltMap(char(entries(j).openalex_id)) = ...
            parse_openalex_inverted_index_json(entries(j).raw_abstract_json);
    end
end

savedIds = string(savedTable.openalex_id);
savedAbstracts = string(savedTable.abstract);
mismatchId = strings(0,1);
savedAbstract = strings(0,1);
rebuiltAbstract = strings(0,1);
for i = 1:numel(savedIds)
    oid = savedIds(i);
    if oid == "" || ~isKey(rebuiltMap, char(oid))
        continue;
    end
    rebuilt = string(rebuiltMap(char(oid)));
    if savedAbstracts(i) ~= rebuilt
        mismatchId(end+1,1) = oid; %#ok<AGROW>
        savedAbstract(end+1,1) = savedAbstracts(i); %#ok<AGROW>
        rebuiltAbstract(end+1,1) = rebuilt; %#ok<AGROW>
    end
end

report = struct();
report.raw_dir = rawDir;
report.saved_rows = int32(height(savedTable));
report.rebuilt_rows = int32(rebuiltMap.Count);
report.mismatch_count = int32(numel(mismatchId));
report.mismatches = table(mismatchId, savedAbstract, rebuiltAbstract, ...
    'VariableNames', {'openalex_id', 'saved_abstract', 'rebuilt_abstract'});
end
