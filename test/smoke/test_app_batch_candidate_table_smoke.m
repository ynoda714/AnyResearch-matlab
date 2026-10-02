function test_app_batch_candidate_table_smoke()
%TEST_APP_BATCH_CANDIDATE_TABLE_SMOKE  Offline Batch candidate CSV <-> review table round trip.
%
% The candidate CSV written by prepare_institutions_csv has nine columns
% (including works_count) while the Step 2 review table shows eight. Loading it
% into the table and saving the review back must neither be rejected by uitable
% nor drop or reorder the CSV columns that the table does not display.

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
appSourceDir = fullfile(projectRoot, "src", "app");
originalDir = pwd;
directoryCleanup = onCleanup(@() cd(originalDir));
clear AnyResearchApp;
cd(app_source_dir(projectRoot));

app = AnyResearchApp;
appCleanup = onCleanup(@() local_delete_app(app));
drawnow;

%% Fixture in the exact column layout of prepare_institutions_csv.
candidatePath = string(tempname) + "_candidate.csv";
reviewedPath = string(tempname) + "_reviewed.csv";
fileCleanup = onCleanup(@() local_delete_files([candidatePath, reviewedPath]));
variableNames = {'account','openalex_institution_id','display_name','country_code', ...
    'works_count','include','role','note','status'};
candidates = table( ...
    ["Nagoya University"; "Nagoya University"; "No Such Institute"], ...
    ["I111"; "I222"; ""], ...
    ["Nagoya University"; "Nagoya University Hospital"; ""], ...
    ["JP"; "JP"; ""], ...
    [123456; 7890; 0], ...
    [0; 0; 0], ...
    ["";"hospital";""], ...
    ["";"";""], ...
    ["found"; "found"; "not_found"], ...
    'VariableNames', variableNames);
writetable(candidates, candidatePath);
app.setBatchPathsForTesting(candidatePath, reviewedPath);

%% Loading the nine-column CSV into the eight-column review table succeeds.
app.loadCandidateReviewForTesting();
data = app.CandidateTable.Data;
assert(isequal(size(data), [3 8]), ...
    "The review table must show three rows and the eight displayed columns.");
assert(isequal(string(app.CandidateTable.ColumnName(:))', ...
    string({'account','status','openalex_institution_id','display_name', ...
    'include','role','note','country_code'})), ...
    "The review table columns must stay unchanged.");
assert(string(data{1, 1}) == "Nagoya University" && string(data{2, 4}) == "Nagoya University Hospital");
assert(string(data{2, 6}) == "hospital", "The proposed role must be shown in the role column.");
assert(isempty(char(string(data{1, 7}))), "An empty note must load as an empty value, not <missing>.");
assert(isnumeric(data{1, 5}) && data{1, 5} == 0, "The include column must load as a number.");

%% Reviewer edits are written back without disturbing the hidden works_count column.
data{1, 5} = 1;
data{1, 6} = 'reference';
data{1, 7} = 'main campus';
data{3, 7} = 'not found upstream';
app.CandidateTable.Data = data;
app.promoteCandidatesForTesting();
drawnow;

saved = readtable(candidatePath, TextType="string");
assert(isequal(string(saved.Properties.VariableNames), string(variableNames)), ...
    "Saving the review must keep all nine CSV columns in their original order.");
assert(isequal(saved.works_count, [123456; 7890; 0]), ...
    "The works_count column must survive the review round trip.");
assert(isequal(double(saved.include), [1; 0; 0]), "The include edit must be saved.");
assert(saved.role(1) == "reference" && saved.role(2) == "hospital", ...
    "The role edit must be saved and unedited roles must be kept.");
assert(saved.note(1) == "main campus" && saved.note(3) == "not found upstream");
savedIds = string(saved.openalex_institution_id);
savedIds(ismissing(savedIds)) = "";
assert(isequal(savedIds, ["I111"; "I222"; ""]), ...
    "Identifier columns must be unchanged.");

assert(~contains(fileread(candidatePath), "NaN"), ...
    "Blank cells must be written back blank, not as NaN.");

promoted = readtable(reviewedPath, TextType="string");
assert(height(promoted) == 3 && width(promoted) == 9, ...
    "Promotion must copy the reviewed nine-column CSV.");

fprintf("Smoke test passed: AnyResearchApp Batch candidate table round trip\n");
end

function local_delete_files(paths)
for path = paths
    if isfile(path)
        delete(path);
    end
end
end

function local_delete_app(app)
if isvalid(app) && isvalid(app.UIFigure)
    delete(app.UIFigure);
end
end
