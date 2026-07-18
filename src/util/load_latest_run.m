function T = load_latest_run(runRootDir)
arguments
    runRootDir (1,1) string = "result/runs"
end

if ~isfolder(runRootDir)
    error("load_latest_run:RunRootNotFound", "Run root directory not found: %s", runRootDir);
end

d = dir(runRootDir);
d = d([d.isdir]);
names = string({d.name})';
names = names(names ~= "." & names ~= "..");
if isempty(names)
    error("load_latest_run:NoRunsFound", "No run directories found under: %s", runRootDir);
end

names = sort(names);
latestRunDir = string(fullfile(runRootDir, names(end)));
T = load_run(latestRunDir);
end
