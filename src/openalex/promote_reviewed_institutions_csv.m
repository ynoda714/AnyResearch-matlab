function result = promote_reviewed_institutions_csv(sourceCsv, targetCsv)
%PROMOTE_REVIEWED_INSTITUTIONS_CSV  Copies reviewed institution candidates to the batch input CSV.
%
%   result = promote_reviewed_institutions_csv(sourceCsv, targetCsv)
%
%   Copies sourceCsv, usually data/list/institutions_candidate.csv, to
%   targetCsv, usually data/list/institutions.csv. If targetCsv already exists,
%   it is first copied to targetCsv.bak.<yyyyMMdd_HHmmss>. The reviewed target
%   list is never overwritten before the backup copy succeeds.

arguments
    sourceCsv (1,1) string = "data/list/institutions_candidate.csv"
    targetCsv (1,1) string = "data/list/institutions.csv"
end

thisDir = fileparts(mfilename('fullpath'));
srcDir = fileparts(thisDir);
projectRoot = fileparts(srcDir);
if isfolder(fullfile(projectRoot, 'src', 'util'))
    addpath(fullfile(projectRoot, 'src', 'util'));
end

sourcePath = local_resolve_path(sourceCsv, projectRoot);
targetPath = local_resolve_path(targetCsv, projectRoot);

if strcmpi(char(sourcePath), char(targetPath))
    error('promote_reviewed_institutions_csv:SamePath', ...
        'Candidate CSV and target institutions CSV must be different paths: %s', sourcePath);
end

if ~isfile(sourcePath)
    error('promote_reviewed_institutions_csv:SourceNotFound', ...
        ['Reviewed candidate CSV not found: %s\n', ...
         'Run Section 0.5 with prepareList=true, review include/role/note in the candidate CSV, ', ...
         'then set promoteReviewed=true and run Section 0.6 again.'], sourcePath);
end

targetDir = fileparts(char(targetPath));
if strlength(string(targetDir)) > 0 && ~isfolder(targetDir)
    mkdir(targetDir);
end

backupPath = "";
if isfile(targetPath)
    timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    backupPath = targetPath + ".bak." + timestamp;
    [backupOk, backupMsg] = copyfile(char(targetPath), char(backupPath), 'f');
    if ~backupOk
        error('promote_reviewed_institutions_csv:BackupFailed', ...
            'Failed to back up existing institutions CSV to %s: %s', backupPath, backupMsg);
    end
    log_info('Backed up existing institutions CSV: %s', backupPath);
end

[copyOk, copyMsg] = copyfile(char(sourcePath), char(targetPath), 'f');
if ~copyOk
    error('promote_reviewed_institutions_csv:CopyFailed', ...
        'Failed to promote reviewed candidate CSV to %s: %s', targetPath, copyMsg);
end

log_info('Promoted reviewed candidate CSV: %s -> %s', sourcePath, targetPath);

result = struct( ...
    'sourceCsv', sourcePath, ...
    'targetCsv', targetPath, ...
    'backupCsv', backupPath);
end

function outPath = local_resolve_path(pathValue, projectRoot)
p = strtrim(string(pathValue));
if strlength(p) == 0
    error('promote_reviewed_institutions_csv:EmptyPath', 'CSV path must not be empty.');
end

if local_is_absolute(p)
    outPath = p;
else
    outPath = string(fullfile(projectRoot, char(p)));
end
end

function result = local_is_absolute(p)
s = char(strtrim(string(p)));
result = ~isempty(s) && ...
    (s(1) == '/' || s(1) == '\' || ...
     (length(s) >= 3 && s(2) == ':' && (s(3) == '/' || s(3) == '\')));
end
