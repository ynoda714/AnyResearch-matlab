classdef AnyResearchApp < matlab.apps.App

    % Used to locate and load the app's XML configuration file
    properties (Access = public, Constant)
        AppConfigFilename = './AnyResearchApp.xml'; % File path to the app configuration file containing component layout and settings
    end

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        RootGrid                        matlab.ui.container.GridLayout
        StatusLabel                     matlab.ui.control.Label
        MainTabGroup                    matlab.ui.container.TabGroup
        SearchTab                       matlab.ui.container.Tab
        SearchGrid                      matlab.ui.container.GridLayout
        SearchRunButton                 matlab.ui.control.Button
        SearchParametersPanel           matlab.ui.container.Panel
        SearchParametersGrid            matlab.ui.container.GridLayout
        AdvancedPanel                   matlab.ui.container.Panel
        AdvancedGrid                    matlab.ui.container.GridLayout
        FiltersPanel                    matlab.ui.container.Panel
        FiltersGrid                     matlab.ui.container.GridLayout
        BasicPanel                      matlab.ui.container.Panel
        BasicGrid                       matlab.ui.container.GridLayout
        InstitutionIdEditField          matlab.ui.control.EditField
        InstitutionIdLabel              matlab.ui.control.Label
        InstitutionEditField            matlab.ui.control.EditField
        InstitutionLabel                matlab.ui.control.Label
        CountryCodeEditField            matlab.ui.control.EditField
        CountryCodeLabel                matlab.ui.control.Label
        RequireAbstractCheckBox         matlab.ui.control.CheckBox
        RequireOpenAccessCheckBox       matlab.ui.control.CheckBox
        LanguageEditField               matlab.ui.control.EditField
        LanguageLabel                   matlab.ui.control.Label
        TopNField                       matlab.ui.control.NumericEditField
        TopNLabel                       matlab.ui.control.Label
        SnowballModeDropDown            matlab.ui.control.DropDown
        SnowballModeLabel               matlab.ui.control.Label
        SeedIdEditField                 matlab.ui.control.EditField
        SeedIdLabel                     matlab.ui.control.Label
        CitedByMaxField                 matlab.ui.control.NumericEditField
        CitedByMaxLabel                 matlab.ui.control.Label
        CitedByMinField                 matlab.ui.control.NumericEditField
        CitedByMinLabel                 matlab.ui.control.Label
        FilterTypeEditField             matlab.ui.control.EditField
        FilterTypeLabel                 matlab.ui.control.Label
        SortByDropDown                  matlab.ui.control.DropDown
        SortByLabel                     matlab.ui.control.Label
        ToDatePicker                    matlab.ui.control.DatePicker
        ToDateLabel                     matlab.ui.control.Label
        FromDatePicker                  matlab.ui.control.DatePicker
        FromDateLabel                   matlab.ui.control.Label
        QueryEditField                  matlab.ui.control.EditField
        QueryLabel                      matlab.ui.control.Label
        BatchTab                        matlab.ui.container.Tab
        BatchGrid                       matlab.ui.container.GridLayout
        BatchBackButton                 matlab.ui.control.Button
        BatchContentGrid                matlab.ui.container.GridLayout
        BatchRunPanel                   matlab.ui.container.Panel
        BatchRunGrid                    matlab.ui.container.GridLayout
        RunBatchButton                  matlab.ui.control.Button
        BatchDryRunCheckBox             matlab.ui.control.CheckBox
        BatchToDatePicker               matlab.ui.control.DatePicker
        BatchToDateLabel                matlab.ui.control.Label
        BatchFromDatePicker             matlab.ui.control.DatePicker
        BatchFromDateLabel              matlab.ui.control.Label
        BatchQueryEditField             matlab.ui.control.EditField
        BatchQueryLabel                 matlab.ui.control.Label
        BatchPromotePanel               matlab.ui.container.Panel
        BatchPromoteGrid                matlab.ui.container.GridLayout
        PromoteCandidatesButton         matlab.ui.control.Button
        PromoteHelpLabel                matlab.ui.control.Label
        BatchReviewPanel                matlab.ui.container.Panel
        BatchReviewGrid                 matlab.ui.container.GridLayout
        ReviewCandidatesButton          matlab.ui.control.Button
        CandidateTable                  matlab.ui.control.Table
        BatchGeneratePanel              matlab.ui.container.Panel
        BatchGenerateGrid               matlab.ui.container.GridLayout
        GenerateCandidatesButton        matlab.ui.control.Button
        PrepareCountryEditField         matlab.ui.control.EditField
        PrepareCountryLabel             matlab.ui.control.Label
        TargetNamesTextArea             matlab.ui.control.TextArea
        TargetNamesLabel                matlab.ui.control.Label
        BatchStepLabel                  matlab.ui.control.Label
        AnalyticsPdfTab                 matlab.ui.container.Tab
        AnalyticsPdfGrid                matlab.ui.container.GridLayout
        PdfPanel                        matlab.ui.container.Panel
        PdfOptionsGrid                  matlab.ui.container.GridLayout
        EnableKeywordEvidenceCheckBox   matlab.ui.control.CheckBox
        EnablePdfTextCheckBox           matlab.ui.control.CheckBox
        PdfMaxRowsField                 matlab.ui.control.NumericEditField
        PdfMaxRowsLabel                 matlab.ui.control.Label
        EnablePdfDownloadCheckBox       matlab.ui.control.CheckBox
        AnalyticsPanel                  matlab.ui.container.Panel
        AnalyticsStatusLabel            matlab.ui.control.Label
        SettingsTab                     matlab.ui.container.Tab
        SettingsGrid                    matlab.ui.container.GridLayout
        SettingsHelpLabel               matlab.ui.control.Label
        SaveApiKeyButton                matlab.ui.control.Button
        ApiKeyEditField                 matlab.ui.control.EditField
        ApiKeyLabel                     matlab.ui.control.Label
        AppTitleLabel                   matlab.ui.control.Label
    end

    properties (Access = private)
        BatchCandidatePath = "data/list/institutions_candidate.csv"
        BatchStep = 1
        ReviewedInstitutionsPath = "data/list/institutions.csv"
        SettingsPathOverride
    end

    methods (Access = private)

        function options = getBatchPrepareOptions(app)
            names = string(app.TargetNamesTextArea.Value);
            options = struct('targetNames', names, 'countryFilter', strtrim(string(app.PrepareCountryEditField.Value)), ...
                'candidatePath', app.BatchCandidatePath, 'reviewedPath', app.ReviewedInstitutionsPath);
        end

        function options = getBatchRunOptions(app)
            if strlength(strtrim(string(app.BatchQueryEditField.Value))) == 0
                error('AnyResearch:emptyBatchQuery', 'Enter a search query before running the batch.');
            end
            options = struct('institutionsCsv', app.ReviewedInstitutionsPath, 'query', strtrim(string(app.BatchQueryEditField.Value)), ...
                'fromDate', string(app.BatchFromDatePicker.Value, "yyyy-MM-dd"), ...
                'toDate', string(app.BatchToDatePicker.Value, "yyyy-MM-dd"), ...
                'batchRootDir', "result/batch", 'dryRun', logical(app.BatchDryRunCheckBox.Value));
        end

        function searchOptions = getSearchOptions(app)
            fromDate = ""; if ~isnat(app.FromDatePicker.Value); fromDate = string(app.FromDatePicker.Value, "yyyy-MM-dd"); end
            toDate = ""; if ~isnat(app.ToDatePicker.Value); toDate = string(app.ToDatePicker.Value, "yyyy-MM-dd"); end
            searchOptions = struct('query', strtrim(string(app.QueryEditField.Value)), 'fromDate', fromDate, 'toDate', toDate, ...
                'language', strtrim(string(app.LanguageEditField.Value)), 'requireOpenAccess', logical(app.RequireOpenAccessCheckBox.Value), ...
                'requireAbstract', logical(app.RequireAbstractCheckBox.Value), 'filterCountryCode', strtrim(string(app.CountryCodeEditField.Value)), ...
                'sortBy', string(app.SortByDropDown.Value), 'filterType', strtrim(string(app.FilterTypeEditField.Value)), ...
                'citedByMin', double(app.CitedByMinField.Value), 'citedByMax', double(app.CitedByMaxField.Value), ...
                'seedId', strtrim(string(app.SeedIdEditField.Value)), 'snowballMode', string(app.SnowballModeDropDown.Value), ...
                'topN', double(app.TopNField.Value), 'firstAuthorInstitution', strtrim(string(app.InstitutionEditField.Value)), ...
                'firstAuthorInstitutionId', strtrim(string(app.InstitutionIdEditField.Value)), ...
                'enablePdfDownload', logical(app.EnablePdfDownloadCheckBox.Value), 'pdfMaxRows', double(app.PdfMaxRowsField.Value), ...
                'enablePdfTextExtraction', logical(app.EnablePdfTextCheckBox.Value), ...
                'enableKeywordEvidence', logical(app.EnableKeywordEvidenceCheckBox.Value));
        end

        function loadCandidateReview(app)
            candidateTable = readtable(app.BatchCandidatePath, TextType="string");
            app.CandidateTable.Data = table2cell(candidateTable);
        end

        function onBatchRunComplete(app, result, err)
            if ~isempty(err)
                app.StatusLabel.Text = 'Batch failed.';
                uialert(app.UIFigure, err.message, 'Batch failed');
                return;
            end
            app.StatusLabel.Text = sprintf('Batch complete: %d/%d institutions succeeded. Output: %s', result.success_count, result.total_institutions, result.batch_dir);
        end

        function onPrepareInstitutionsComplete(app, result, err)
            if ~isempty(err)
                app.StatusLabel.Text = 'Candidate generation failed.';
                uialert(app.UIFigure, err.message, 'Candidate generation failed');
                return;
            end
            app.BatchCandidatePath = string(result);
            app.loadCandidateReview();
            app.StatusLabel.Text = 'Candidates generated. Review the include, role, and note columns.';
            app.showBatchStep(2);
        end

        function onSearchComplete(app, result, err)
            if ~isempty(err)
                app.StatusLabel.Text = 'Search failed.';
                uialert(app.UIFigure, err.message, 'Search failed');
                return;
            end
            app.StatusLabel.Text = sprintf('Search complete: %d works. Output: %s', result.rows_fetched, result.run_dir);
        end

        function settingsPath = resolveSettingsPath(app)
            if strlength(string(app.SettingsPathOverride)) > 0
                settingsPath = string(app.SettingsPathOverride);
                return;
            end
            projectRoot = AnyResearchApp.resolveProjectRoot();
            settingsPath = fullfile(projectRoot, 'config', 'settings.json');
        end

        function saveApiKey(app)
            apiKey = strtrim(string(app.ApiKeyEditField.Value));
            if strlength(apiKey) == 0
                uialert(app.UIFigure, 'Enter an API key before saving.', 'API key required');
                return;
            end
            settingsPath = app.resolveSettingsPath();
            if isfile(settingsPath); settings = jsondecode(fileread(settingsPath)); else; settings = struct(); end
            if ~isfield(settings, 'openalex'); settings.openalex = struct(); end
            settings.openalex.api_key = char(apiKey);
            settingsJson = string(jsonencode(settings, PrettyPrint=true));
            topLevelFields = string(fieldnames(settings));
            for fieldIndex = 1:numel(topLevelFields)
                fieldName = topLevelFields(fieldIndex);
                if startsWith(fieldName, 'x_')
                    restoredFieldName = '_' + extractAfter(fieldName, 'x_');
                    jsonField = string(newline) + string('  ') + char(34) + fieldName + char(34) + string(':');
                    restoredJsonField = string(newline) + string('  ') + char(34) + restoredFieldName + char(34) + string(':');
                    settingsJson = replace(settingsJson, jsonField, restoredJsonField);
                end
            end
            writelines(settingsJson, settingsPath);
            app.ApiKeyEditField.Value = '';
            if strlength(string(app.SettingsPathOverride)) > 0
                app.StatusLabel.Text = 'API key saved to the isolated test settings file.';
            else
                app.StatusLabel.Text = 'API key saved to config/settings.json. An environment variable still takes precedence.';
            end
        end

        function saveCandidateReview(app)
            candidateTable = readtable(app.BatchCandidatePath, TextType="string");
            candidateTable{:,:} = app.CandidateTable.Data;
            writetable(candidateTable, app.BatchCandidatePath);
        end

        function showBatchStep(app, step)
            step = max(1, min(4, step));
            heights = {0, 0, 0, 0}; heights{step} = '1x';
            app.BatchContentGrid.RowHeight = heights;
            app.BatchGeneratePanel.Visible = step == 1; app.BatchReviewPanel.Visible = step == 2;
            app.BatchPromotePanel.Visible = step == 3; app.BatchRunPanel.Visible = step == 4;
            app.BatchBackButton.Enable = matlab.lang.OnOffSwitchState(step > 1);
            app.BatchStep = step;
        end

    end

    methods (Access = public)

        function options = getBatchRunOptionsForTesting(app)
            options = app.getBatchRunOptions();
        end

        function options = getBatchPrepareOptionsForTesting(app)
            options = app.getBatchPrepareOptions();
        end

        function searchOptions = getSearchOptionsForTesting(app)
            searchOptions = app.getSearchOptions();
        end

        function promoteCandidatesForTesting(app)
            app.PromoteCandidatesButtonPushed([]);
        end

        function reviewCandidatesForTesting(app)
            app.ReviewCandidatesButtonPushed([]);
        end

        function runBatchForTesting(app)
            app.RunBatchButtonPushed([]);
        end

        function runSearchForTesting(app)
            app.SearchRunButtonPushed([]);
        end

        function saveApiKeyForTesting(app)
            app.SaveApiKeyButtonPushed([]);
        end

        function setBatchPathsForTesting(app, candidatePath, reviewedPath)
            arguments
                app
                candidatePath (1,1) string
                reviewedPath (1,1) string
            end
            app.BatchCandidatePath = candidatePath;
            app.ReviewedInstitutionsPath = reviewedPath;
        end

        function setBatchStepForTesting(app, step)
            arguments
                app
                step (1,1) double
            end
            app.showBatchStep(step);
        end

        function setSettingsPathForTesting(app, settingsPath)
            arguments
                app
                settingsPath (1,1) string
            end
            app.SettingsPathOverride = settingsPath;
        end

    end

    methods (Static)

        function projectRoot = resolveProjectRoot()
            % mfilename('fullpath') does not resolve correctly when this
            % class is loaded from the packaged AnyResearchApp.mlapp (it
            % resolves to a path outside the repository), so project-root
            % lookups must go through which() on the class name instead,
            % which resolves correctly for both the plain-text src/app/
            % source and the packaged .mlapp.
            appFilePath = which('AnyResearchApp');
            if isempty(appFilePath)
                appFilePath = mfilename('fullpath');
            end
            if endsWith(lower(appFilePath), '.mlapp')
                projectRoot = fileparts(appFilePath);
            else
                projectRoot = fileparts(fileparts(fileparts(appFilePath)));
            end
        end

        function candidatePath = prepareInstitutions(options)
            projectRoot = AnyResearchApp.resolveProjectRoot();
            addpath(fullfile(projectRoot, "src", "openalex"));
            addpath(fullfile(projectRoot, "src", "config"));
            addpath(fullfile(projectRoot, "src", "util"));
            candidatePath = prepare_institutions_csv(options.targetNames, ...
                outputPath=options.candidatePath, countryFilter=options.countryFilter, ...
                maxCandidates=3, mergeWith=options.reviewedPath);
        end

        function result = runBatchPipeline(options)
            projectRoot = AnyResearchApp.resolveProjectRoot();
            addpath(fullfile(projectRoot, "src", "pipeline"));
            result = run_batch_from_institutions_list(options.institutionsCsv, options.query, options.fromDate, options.toDate, ...
                batchRootDir=options.batchRootDir, dryRun=options.dryRun);
        end

        function result = runSearchPipeline(searchOptions)
            projectRoot = AnyResearchApp.resolveProjectRoot();
            addpath(fullfile(projectRoot, "src", "pipeline"));
            result = run_pipeline(searchOptions.query, searchOptions.fromDate, searchOptions.toDate, ...
                language=searchOptions.language, requireOpenAccess=searchOptions.requireOpenAccess, ...
                requireAbstract=searchOptions.requireAbstract, filterCountryCode=searchOptions.filterCountryCode, ...
                sortBy=searchOptions.sortBy, filterType=searchOptions.filterType, ...
                citedByMin=searchOptions.citedByMin, citedByMax=searchOptions.citedByMax, ...
                seedId=searchOptions.seedId, snowballMode=searchOptions.snowballMode, topN=searchOptions.topN, ...
                firstAuthorInstitution=searchOptions.firstAuthorInstitution, ...
                firstAuthorInstitutionId=searchOptions.firstAuthorInstitutionId, ...
                enablePdfDownload=searchOptions.enablePdfDownload, pdfMaxRows=searchOptions.pdfMaxRows, ...
                enablePdfTextExtraction=searchOptions.enablePdfTextExtraction, ...
                enableKeywordEvidence=searchOptions.enableKeywordEvidence);
        end

    end

    % Callbacks that handle component events
    methods

        % Code that executes after component creation
        function startupFcn(app)
            app.FromDatePicker.Value = datetime(2026, 1, 1);
            app.ToDatePicker.Value = datetime(2026, 7, 18);
            app.StatusLabel.Text = 'Ready. Configure Search and select Run Search.';
            app.BatchFromDatePicker.Value = datetime(2025, 1, 1);
            app.BatchToDatePicker.Value = datetime(2025, 12, 31);
            app.showBatchStep(1);
            app.CandidateTable.ColumnEditable = logical([0 0 0 0 1 1 1 0]);
        end

        % Close request function: UIFigure
        function CloseRequestFcn(app, event)
            delete(app.UIFigure);
        end

        % Button pushed function: SearchRunButton
        function SearchRunButtonPushed(app, event)
            if strlength(strtrim(string(app.QueryEditField.Value))) == 0
                uialert(app.UIFigure, 'Enter a search query before running.', 'Query required');
                return;
            end
            app.SearchRunButton.Enable = 'off';
            app.StatusLabel.Text = 'Search is running...';
            drawnow;
            try
                result = AnyResearchApp.runSearchPipeline(app.getSearchOptions());
                app.onSearchComplete(result, []);
            catch err
                app.onSearchComplete([], err);
            end
            app.SearchRunButton.Enable = 'on';
        end

        % Button pushed function: GenerateCandidatesButton
        function GenerateCandidatesButtonPushed(app, event)
            app.GenerateCandidatesButton.Enable = 'off';
            app.StatusLabel.Text = 'Generating institution candidates...';
            drawnow;
            try
                result = AnyResearchApp.prepareInstitutions(app.getBatchPrepareOptions());
                app.onPrepareInstitutionsComplete(result, []);
            catch err
                app.onPrepareInstitutionsComplete([], err);
            end
            app.GenerateCandidatesButton.Enable = 'on';
        end

        % Button pushed function: ReviewCandidatesButton
        function ReviewCandidatesButtonPushed(app, event)
            if ~isfile(app.BatchCandidatePath)
                uialert(app.UIFigure, 'Generate institution candidates before reviewing.', 'Candidates required');
                return;
            end
            app.saveCandidateReview();
            app.showBatchStep(3);
        end

        % Button pushed function: PromoteCandidatesButton
        function PromoteCandidatesButtonPushed(app, event)
            if ~isfile(app.BatchCandidatePath)
                uialert(app.UIFigure, 'Generate institution candidates before promoting.', 'Candidates required');
                return;
            end
            app.saveCandidateReview();
            promote_reviewed_institutions_csv(app.BatchCandidatePath, app.ReviewedInstitutionsPath);
            app.StatusLabel.Text = 'Reviewed institutions promoted.';
            app.showBatchStep(4);
        end

        % Button pushed function: RunBatchButton
        function RunBatchButtonPushed(app, event)
            if ~isfile(app.ReviewedInstitutionsPath)
                uialert(app.UIFigure, 'Promote reviewed candidates before running the batch.', 'Institutions required');
                return;
            end
            app.RunBatchButton.Enable = 'off';
            app.StatusLabel.Text = 'Batch is running...';
            drawnow;
            try
                result = AnyResearchApp.runBatchPipeline(app.getBatchRunOptions());
                app.onBatchRunComplete(result, []);
            catch err
                app.onBatchRunComplete([], err);
            end
            app.RunBatchButton.Enable = 'on';
        end

        % Button pushed function: BatchBackButton
        function BatchBackButtonPushed(app, event)
            app.showBatchStep(max(1, app.BatchStep - 1));
        end

        % Button pushed function: SaveApiKeyButton
        function SaveApiKeyButtonPushed(app, event)
            app.saveApiKey();
        end
    end

    % App creation
    methods (Access = public)

        % Construct app
        function app = AnyResearchApp(varargin)
            app = app@matlab.apps.App(varargin{:});

            if nargout == 0
                clear app
            end
        end
    end
end