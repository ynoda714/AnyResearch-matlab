function test_app_gesture_smoke()
%TEST_APP_GESTURE_SMOKE  Offline UI gesture coverage for AnyResearchApp.

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
appSourceDir = fullfile(projectRoot, "src", "app");
originalDir = pwd;
directoryCleanup = onCleanup(@() cd(originalDir));
clear AnyResearchApp;
cd(appSourceDir);

testCase = matlab.uitest.TestCase.forInteractiveUse;
app = AnyResearchApp;
appCleanup = onCleanup(@() local_delete_app(app));
drawnow;

%% Four top-level tabs are available after startup.
assert(numel(app.MainTabGroup.Children) == 4, ...
    "The app must provide four top-level tabs.");
assert(string(app.SearchTab.Title) == "Search");
assert(string(app.BatchTab.Title) == "Batch");
assert(string(app.AnalyticsPdfTab.Title) == "Analytics & PDF");
assert(string(app.SettingsTab.Title) == "Settings");

%% The startup status is not tied to one tab (the status bar is shared by all tabs).
assert(string(app.StatusLabel.Text) == "Ready.", ...
    "The startup status must be tab-neutral. Actual: %s", string(app.StatusLabel.Text));

%% Every labelled input is associated with its visible label (screen readers announce it).
labelPairs = [ ...
    "QueryEditField", "QueryLabel"; "FromDatePicker", "FromDateLabel"; "ToDatePicker", "ToDateLabel"; ...
    "SortByDropDown", "SortByLabel"; "FilterTypeEditField", "FilterTypeLabel"; ...
    "CitedByMinField", "CitedByMinLabel"; "CitedByMaxField", "CitedByMaxLabel"; ...
    "LanguageEditField", "LanguageLabel"; "CountryCodeEditField", "CountryCodeLabel"; ...
    "SeedIdEditField", "SeedIdLabel"; "SnowballModeDropDown", "SnowballModeLabel"; ...
    "TopNField", "TopNLabel"; "InstitutionEditField", "InstitutionLabel"; ...
    "InstitutionIdEditField", "InstitutionIdLabel"; "TargetNamesTextArea", "TargetNamesLabel"; ...
    "PrepareCountryEditField", "PrepareCountryLabel"; "BatchQueryEditField", "BatchQueryLabel"; ...
    "BatchFromDatePicker", "BatchFromDateLabel"; "BatchToDatePicker", "BatchToDateLabel"; ...
    "PdfMaxRowsField", "PdfMaxRowsLabel"; "ApiKeyEditField", "ApiKeyLabel"];
for pairIndex = 1:size(labelPairs, 1)
    fieldName = labelPairs(pairIndex, 1);
    labelName = labelPairs(pairIndex, 2);
    assert(isa(app.(fieldName).Label, "matlab.ui.control.Label") && app.(fieldName).Label == app.(labelName), ...
        "%s must be associated with %s.", fieldName, labelName);
end

%% Batch wizard transitions are local UI state changes; no API call is made.
app.MainTabGroup.SelectedTab = app.BatchTab;
local_verify_batch_step(testCase, app, 1);
for step = 2:4
    app.setBatchStepForTesting(step);
    drawnow;
    local_verify_batch_step(testCase, app, step);
end

app.setBatchStepForTesting(2);
drawnow;
assert(string(app.CandidateTable.Visible) == "on");
assert(isequal(logical(app.CandidateTable.ColumnEditable), ...
    logical([0 0 0 0 1 1 1 0])), ...
    "Only include, role, and note may be edited during candidate review.");
assert(isequal(string(app.CandidateTable.ColumnName), ...
    ["account", "openalex_institution_id", "display_name", "country_code", ...
     "include", "role", "note", "status"]'));

%% Save API key through the Settings UI into an isolated settings file.
tmpDir = fullfile(tempdir, "smoke_app_gesture");
if isfolder(tmpDir)
    rmdir(tmpDir, "s");
end
mkdir(tmpDir);
tmpCleanup = onCleanup(@() rmdir(tmpDir, "s"));

isolatedSettingsPath = fullfile(tmpDir, "settings.json");
writelines('{"search":{"query":"preserved"}}', isolatedSettingsPath);
projectSettingsPath = fullfile(projectRoot, "config", "settings.json");
[projectSettingsExisted, projectSettingsBefore] = local_read_file(projectSettingsPath);

app.setSettingsPathForTesting(isolatedSettingsPath);
app.MainTabGroup.SelectedTab = app.SettingsTab;
testCase.type(app.ApiKeyEditField, "gesture_test_api_key");
testCase.press(app.SaveApiKeyButton);
drawnow;

savedSettings = jsondecode(fileread(isolatedSettingsPath));
assert(string(savedSettings.openalex.api_key) == "gesture_test_api_key");
assert(string(savedSettings.search.query) == "preserved");
assert(string(app.ApiKeyEditField.Value) == "");
assert(string(app.StatusLabel.Text) == ...
    "API key saved to the isolated test settings file.");
local_verify_file_unchanged(projectSettingsPath, ...
    projectSettingsExisted, projectSettingsBefore);

fprintf("Smoke test passed: AnyResearchApp offline gestures and isolated API key save\n");
end

function local_verify_batch_step(~, app, step)
expectedVisible = false(1, 4);
expectedVisible(step) = true;
actualVisible = [logical(app.BatchGeneratePanel.Visible), ...
    logical(app.BatchReviewPanel.Visible), logical(app.BatchPromotePanel.Visible), ...
    logical(app.BatchRunPanel.Visible)];

assert(isequal(actualVisible, expectedVisible), ...
    sprintf("Batch step %d must display exactly its own panel.", step));
assert(logical(app.BatchBackButton.Enable) == (step > 1));
end

function [exists, contents] = local_read_file(path)
exists = isfile(path);
if exists
    contents = fileread(path);
else
    contents = "";
end
end

function local_verify_file_unchanged(path, expectedExists, expectedContents)
assert(isfile(path) == expectedExists, ...
    "The production config/settings.json file must not be created or removed.");
if expectedExists
    assert(string(fileread(path)) == string(expectedContents), ...
        "The production config/settings.json file must remain byte-for-byte unchanged.");
end
end

function local_delete_app(app)
if isvalid(app) && isvalid(app.UIFigure)
    delete(app.UIFigure);
end
end
