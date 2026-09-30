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
