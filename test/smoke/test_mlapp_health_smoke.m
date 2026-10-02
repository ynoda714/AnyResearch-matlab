function test_mlapp_health_smoke()
%TEST_MLAPP_HEALTH_SMOKE  Verify the release .mlapp starts independently.

projectRoot = fileparts(fileparts(fileparts(mfilename("fullpath"))));
appSourceDir = fullfile(projectRoot, "src", "app");
releaseAppPath = fullfile(projectRoot, "AnyResearchApp.mlapp");
originalDir = pwd;
directoryCleanup = onCleanup(@() cd(originalDir));

assert(isfile(releaseAppPath), ...
    "The release AnyResearchApp.mlapp must exist at the repository root.");
assert(~local_path_contains(appSourceDir), ...
    "src/app must not be on the MATLAB path for the release .mlapp health check.");

clear AnyResearchApp;
cd(projectRoot);

candidateClassFiles = string(which("AnyResearchApp", "-all"));
assert(any(strcmpi(candidateClassFiles, string(releaseAppPath))), ...
    "AnyResearchApp must resolve to the repository-root .mlapp before startup.");
assert(~any(strcmpi(candidateClassFiles, ...
    string(fullfile(appSourceDir, "AnyResearchApp.m")))), ...
    "The development AnyResearchApp.m must not be a load candidate for this test.");

app = AnyResearchApp;
appCleanup = onCleanup(@() local_delete_app(app));
drawnow;

loadedClassFile = string(which(class(app)));
assert(strcmpi(loadedClassFile, string(releaseAppPath)), ...
    "The instantiated app must be loaded from AnyResearchApp.mlapp, not src/app/AnyResearchApp.m.");

assert(numel(app.MainTabGroup.Children) == 4, ...
    "The release app must provide four top-level tabs.");
assert(string(app.SearchTab.Title) == "Search");
assert(string(app.BatchTab.Title) == "Batch");
assert(string(app.AnalyticsPdfTab.Title) == "Analytics & PDF");
assert(string(app.SettingsTab.Title) == "Settings");
assert(string(app.StatusLabel.Text) == "Ready.");
assert(isequal(app.BasicGrid.ColumnWidth, {170, 170, '1x'}), ...
    "The release .mlapp must carry the compact short-input layout (regenerate it from the current src/app).");
assert(isa(app.QueryEditField.Label, "matlab.ui.control.Label") && app.QueryEditField.Label == app.QueryLabel, ...
    "The release .mlapp must associate inputs with their labels (regenerate it from the current src/app).");

% Phase W layout: a stale .mlapp built before the Search tab regrouping lacks these panels.
assert(string(app.BasicPanel.Title) == "Basic" && string(app.FiltersPanel.Title) == "Filters" ...
    && string(app.AdvancedPanel.Title) == "Advanced", ...
    "The release .mlapp must be regenerated from the current src/app (Search tab groups missing).");

% Phase X (v1.13.0): components added after v1.12.3. A .mlapp saved before these existed lacks them
% (or lacks the startupFcn lines that wire the buttons), so these checks make the regeneration a gate.
regenerateHint = " (regenerate AnyResearchApp.mlapp from the current src/app)";
assert(isa(app.MaxRecordsField, "matlab.ui.control.NumericEditField") && app.MaxRecordsField.Value == 1000 ...
    && isequal(app.MaxRecordsField.Limits, [1 Inf]) && app.MaxRecordsField.Label == app.MaxRecordsLabel, ...
    "The release .mlapp must carry the Max records field (default 1000, labelled)." + regenerateHint);
assert(strcmp(app.OpenOutputButton.Text, 'Open output folder') && strcmp(app.OpenOutputButton.Enable, 'off'), ...
    "The release .mlapp must carry the Open output folder button, disabled at start." + regenerateHint);
assert(strcmp(app.IncludeAllButton.Text, 'Include all') && strcmp(app.IncludeNoneButton.Text, 'Include none'), ...
    "The release .mlapp must carry the Include all / Include none buttons." + regenerateHint);
% The three buttons are wired in startupFcn (ButtonPushedFcn assigned in code, not registered as callbacks).
for button = [app.OpenOutputButton, app.IncludeAllButton, app.IncludeNoneButton]
    assert(~isempty(button.ButtonPushedFcn), ...
        "startupFcn of the release .mlapp must assign ButtonPushedFcn for '" + string(button.Text) + "'." + regenerateHint);
end
% ...and the code behind them exists: pressing them on an empty state must not error.
openOutput = app.OpenOutputButton.ButtonPushedFcn;
openOutput(app.OpenOutputButton, []);
app.CandidateTable.Data = cell(0, 8);
includeAll = app.IncludeAllButton.ButtonPushedFcn;
includeAll(app.IncludeAllButton, []);
assert(startsWith(string(app.StatusLabel.Text), "Included 0 of 0 rows"), ...
    "Include all in the release .mlapp gave status '" + string(app.StatusLabel.Text) + "'." + regenerateHint);
app.StatusLabel.Text = 'Ready.';
% Start-up dates follow today (a .mlapp built before v1.13.0 starts at the old fixed dates).
today = dateshift(datetime("now"), "start", "day");
assert(app.ToDatePicker.Value == today && app.FromDatePicker.Value == today - calyears(1) ...
    && app.BatchToDatePicker.Value == today && app.BatchFromDatePicker.Value == today - calyears(1), ...
    "The release .mlapp must start with the last year up to today." + regenerateHint);

delete(app);
assert(~isvalid(app), "The release app must close cleanly when deleted.");

fprintf("Smoke test passed: release AnyResearchApp.mlapp health check\n");
end

function tf = local_path_contains(targetDir)
pathEntries = split(string(path), pathsep);
tf = any(strcmpi(pathEntries, string(targetDir)));
end

function local_delete_app(app)
if isvalid(app) && isvalid(app.UIFigure)
    delete(app);
end
end
