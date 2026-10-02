function folder = app_source_dir(projectRoot)
%APP_SOURCE_DIR  Folder to cd into so that AnyResearchApp resolves to the copy under test.
%
%   By default the development source (src/app/AnyResearchApp.m). With the environment variable
%   ANYRESEARCH_TEST_APP=mlapp, the repository root, where only the release AnyResearchApp.mlapp
%   exists: the same GUI tests then run against the file that is actually published
%   (run_smoke_tests("mlapp") sets the variable and checks that src/app is not on the path).

arguments
    projectRoot (1,1) string
end

if strcmpi(getenv("ANYRESEARCH_TEST_APP"), "mlapp")
    folder = projectRoot;
else
    folder = fullfile(projectRoot, "src", "app");
end
end
