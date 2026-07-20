function runDir = make_run_dir(cfg, label)
%MAKE_RUN_DIR Create an output directory under result/examples/topicmap.

arguments
    cfg (1,1) struct
    label (1,1) string = ""
end

if ~isfield(cfg, "baseOutDir")
    error("topicmap:make_run_dir:MissingBaseOutDir", ...
        "cfg.baseOutDir is required.");
end

baseOutDir = string(cfg.baseOutDir);
if ~isfolder(baseOutDir)
    mkdir(baseOutDir);
end
stamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
suffix = "";
if strlength(strtrim(label)) > 0
    safeLabel = regexprep(char(label), '[^A-Za-z0-9_-]', '_');
    suffix = "_" + string(safeLabel);
end

runDir = fullfile(baseOutDir, stamp + suffix);
if ~isfolder(runDir)
    mkdir(runDir);
end
runDir = string(runDir);
end
