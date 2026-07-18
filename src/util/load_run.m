function T = load_run(runDir)
arguments
    runDir (1,1) string
end

if ~isfolder(runDir)
    error("load_run:RunDirNotFound", "Run directory not found: %s", runDir);
end

matPath = string(fullfile(runDir, 'search_results.mat'));
if isfile(matPath)
    S = load(matPath, 'T');
    if isfield(S, 'T') && istable(S.T)
        T = S.T;
        return;
    end
    error("load_run:InvalidMatFile", "search_results.mat does not contain a table variable T: %s", matPath);
end

jsonlPath = string(fullfile(runDir, 'search_results.jsonl'));
if isfile(jsonlPath)
    T = read_jsonl(jsonlPath);
    return;
end

error("load_run:NoSearchResults", "Neither search_results.mat nor search_results.jsonl exists in: %s", runDir);
end
