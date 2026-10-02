classdef AnyResearchApp < matlab.apps.App

    % Used to locate and load the app's XML configuration file
    properties (Access = public, Constant)
        AppConfigFilename = './AnyResearchApp.xml'; % File path to the app configuration file containing component layout and settings
    end

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        RootGrid                        matlab.ui.container.GridLayout
        OpenOutputButton                matlab.ui.control.Button
        StatusLabel                     matlab.ui.control.Label
        MainTabGroup                    matlab.ui.container.TabGroup
        SearchTab                       matlab.ui.container.Tab
        SearchGrid                      matlab.ui.container.GridLayout
        SearchRunButton                 matlab.ui.control.Button
        SearchParametersPanel           matlab.ui.container.Panel
        SearchParametersGrid            matlab.ui.container.GridLayout
        AdvancedPanel                   matlab.ui.container.Panel
        AdvancedGrid                    matlab.ui.container.GridLayout
        InstitutionIdEditField          matlab.ui.control.EditField
        InstitutionIdLabel              matlab.ui.control.Label
        InstitutionEditField            matlab.ui.control.EditField
        InstitutionLabel                matlab.ui.control.Label
        MaxRecordsField                 matlab.ui.control.NumericEditField
        MaxRecordsLabel                 matlab.ui.control.Label
        TopNField                       matlab.ui.control.NumericEditField
        TopNLabel                       matlab.ui.control.Label
        SnowballModeDropDown            matlab.ui.control.DropDown
        SnowballModeLabel               matlab.ui.control.Label
        SeedIdEditField                 matlab.ui.control.EditField
        SeedIdLabel                     matlab.ui.control.Label
        FiltersPanel                    matlab.ui.container.Panel
        FiltersGrid                     matlab.ui.container.GridLayout
        RequireAbstractCheckBox         matlab.ui.control.CheckBox
        RequireOpenAccessCheckBox       matlab.ui.control.CheckBox
        CountryCodeEditField            matlab.ui.control.EditField
        LanguageEditField               matlab.ui.control.EditField
        CountryCodeLabel                matlab.ui.control.Label
        LanguageLabel                   matlab.ui.control.Label
        CitedByMaxField                 matlab.ui.control.NumericEditField
        CitedByMinField                 matlab.ui.control.NumericEditField
        CitedByMaxLabel                 matlab.ui.control.Label
        CitedByMinLabel                 matlab.ui.control.Label
        FilterTypeEditField             matlab.ui.control.EditField
        FilterTypeLabel                 matlab.ui.control.Label
        BasicPanel                      matlab.ui.container.Panel
        BasicGrid                       matlab.ui.container.GridLayout
        SortByDropDown                  matlab.ui.control.DropDown
        SortByLabel                     matlab.ui.control.Label
        ToDatePicker                    matlab.ui.control.DatePicker
        FromDatePicker                  matlab.ui.control.DatePicker
        ToDateLabel                     matlab.ui.control.Label
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
        BatchFromDatePicker             matlab.ui.control.DatePicker
        BatchToDateLabel                matlab.ui.control.Label
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
        IncludeNoneButton               matlab.ui.control.Button
        IncludeAllButton                matlab.ui.control.Button
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
        PromotionConfirmAnswer = []   % empty: ask; true/false: answer given by a test
        SeedHintAnswer = []           % empty: ask; "move"/"keyword"/"cancel": answer given by a test
        CountPreviewForTesting = []   % empty: call preview_search_count
        SearchRunnerForTesting = []   % empty: call runSearchPipeline
        LimitAnswerForTesting = []    % empty: ask with uiconfirm
        LastOutputFolder = ""
        FolderOpener = []             % empty: call the operating system
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
            AnyResearchApp.assertDateRange(app.BatchFromDatePicker.Value, app.BatchToDatePicker.Value);
            fromDate = ""; if ~isnat(app.BatchFromDatePicker.Value); fromDate = string(app.BatchFromDatePicker.Value, "yyyy-MM-dd"); end
            toDate = ""; if ~isnat(app.BatchToDatePicker.Value); toDate = string(app.BatchToDatePicker.Value, "yyyy-MM-dd"); end
            options = struct('institutionsCsv', app.ReviewedInstitutionsPath, 'query', strtrim(string(app.BatchQueryEditField.Value)), ...
                'fromDate', fromDate, ...
                'toDate', toDate, ...
                'batchRootDir', string(fullfile(AnyResearchApp.resolveProjectRoot(), 'result', 'batch')), 'dryRun', logical(app.BatchDryRunCheckBox.Value));
        end

        function associateFieldLabels(app)
            % Associate each input with its visible label so screen readers announce the
            % label text. The plain-text XML loader cannot resolve Label references
            % (R2026b), so the association is made after the components exist.
            pairs = {'QueryEditField', 'QueryLabel'; 'FromDatePicker', 'FromDateLabel'; ...
                'ToDatePicker', 'ToDateLabel'; 'SortByDropDown', 'SortByLabel'; ...
                'FilterTypeEditField', 'FilterTypeLabel'; 'CitedByMinField', 'CitedByMinLabel'; ...
                'CitedByMaxField', 'CitedByMaxLabel'; 'LanguageEditField', 'LanguageLabel'; ...
                'CountryCodeEditField', 'CountryCodeLabel'; 'SeedIdEditField', 'SeedIdLabel'; ...
                'SnowballModeDropDown', 'SnowballModeLabel'; 'TopNField', 'TopNLabel'; ...
                'MaxRecordsField', 'MaxRecordsLabel'; ...
                'InstitutionEditField', 'InstitutionLabel'; 'InstitutionIdEditField', 'InstitutionIdLabel'; ...
                'TargetNamesTextArea', 'TargetNamesLabel'; 'PrepareCountryEditField', 'PrepareCountryLabel'; ...
                'BatchQueryEditField', 'BatchQueryLabel'; 'BatchFromDatePicker', 'BatchFromDateLabel'; ...
                'BatchToDatePicker', 'BatchToDateLabel'; 'PdfMaxRowsField', 'PdfMaxRowsLabel'; ...
                'ApiKeyEditField', 'ApiKeyLabel'};
            for index = 1:size(pairs, 1)
                app.(pairs{index, 1}).Label = app.(pairs{index, 2});
            end
        end

        function tf = hasSearchQuery(app)
            % run_pipeline accepts an empty query when a seed ID starts a snowball search.
            tf = strlength(strtrim(string(app.QueryEditField.Value))) > 0 ...
                || strlength(strtrim(string(app.SeedIdEditField.Value))) > 0;
        end

        function proceed = confirmSeedLikeQuery(app)
            query = strtrim(string(app.QueryEditField.Value));
            seedId = strtrim(string(app.SeedIdEditField.Value));
            if ~AnyResearchApp.looksLikeSeedId(query) || strlength(seedId) > 0
                proceed = true;
                return;
            end

            if isempty(app.SeedHintAnswer)
                choice = uiconfirm(app.UIFigure, ...
                    ['This looks like a DOI or OpenAlex Work ID. Put it in the Seed field to fetch works ' ...
                    'citing it or its referenced works. Searching it as a keyword often returns only one unrelated result.'], ...
                    'Use Seed field?', 'Options', {'Move to Seed field', 'Search as keyword', 'Cancel'}, ...
                    'DefaultOption', 1, 'CancelOption', 3, 'Icon', 'warning');
            else
                choice = app.SeedHintAnswer;
            end

            switch string(choice)
                case {"Move to Seed field", "move"}
                    app.SeedIdEditField.Value = char(query);
                    app.QueryEditField.Value = '';
                    app.StatusLabel.Text = 'Moved to the Seed field. Choose Snowball mode (citing or referenced), then run the search.';
                    proceed = false;
                case {"Search as keyword", "keyword"}
                    proceed = true;
                otherwise
                    proceed = false;
            end
        end

        function setBusy(app, tf)
            buttonNames = ["SearchRunButton", "GenerateCandidatesButton", "ReviewCandidatesButton", ...
                "PromoteCandidatesButton", "RunBatchButton", "SaveApiKeyButton"];
            if tf
                value = 'off';
            else
                value = 'on';
            end
            for name = buttonNames
                app.(name).Enable = value;
            end
            if tf
                app.BatchBackButton.Enable = 'off';
            else
                app.showBatchStep(app.BatchStep);
            end
        end

        function restoreIdleAfterBusyError(app)
            app.setBusy(false);
        end

        function rememberOutputFolder(app, folder)
            app.LastOutputFolder = string(folder);
            app.OpenOutputButton.Enable = 'on';
            app.OpenOutputButton.Tooltip = "Open the output folder: " + app.LastOutputFolder;
        end

        function openOutputFolder(app)
            folder = string(app.LastOutputFolder);
            if strlength(folder) == 0
                return;
            end
            if ~isfolder(folder)
                app.StatusLabel.Text = "Output folder not found: " + folder;
                return;
            end
            try
                if isempty(app.FolderOpener)
                    AnyResearchApp.openFolderInOs(folder);
                else
                    app.FolderOpener(folder);
                end
            catch err
                app.StatusLabel.Text = "Could not open the output folder: " + string(err.message);
            end
        end

        function searchOptions = getSearchOptions(app)
            AnyResearchApp.assertDateRange(app.FromDatePicker.Value, app.ToDatePicker.Value);
            if app.CitedByMaxField.Value > 0 && app.CitedByMinField.Value > app.CitedByMaxField.Value
                error('AnyResearch:invalidCitationRange', ...
                    'Minimum citations must not exceed maximum citations (set the maximum to 0 for no limit).');
            end
            fromDate = ""; if ~isnat(app.FromDatePicker.Value); fromDate = string(app.FromDatePicker.Value, "yyyy-MM-dd"); end
            toDate = ""; if ~isnat(app.ToDatePicker.Value); toDate = string(app.ToDatePicker.Value, "yyyy-MM-dd"); end
            searchOptions = struct('query', strtrim(string(app.QueryEditField.Value)), 'fromDate', fromDate, 'toDate', toDate, ...
                'language', strtrim(string(app.LanguageEditField.Value)), 'requireOpenAccess', logical(app.RequireOpenAccessCheckBox.Value), ...
                'requireAbstract', logical(app.RequireAbstractCheckBox.Value), 'filterCountryCode', strtrim(string(app.CountryCodeEditField.Value)), ...
                'sortBy', string(app.SortByDropDown.Value), 'filterType', strtrim(string(app.FilterTypeEditField.Value)), ...
                'citedByMin', double(app.CitedByMinField.Value), 'citedByMax', double(app.CitedByMaxField.Value), ...
                'seedId', strtrim(string(app.SeedIdEditField.Value)), 'snowballMode', string(app.SnowballModeDropDown.Value), ...
                'topN', double(app.TopNField.Value), 'maxRecords', double(app.MaxRecordsField.Value), ...
                'firstAuthorInstitution', strtrim(string(app.InstitutionEditField.Value)), ...
                'firstAuthorInstitutionId', strtrim(string(app.InstitutionIdEditField.Value)), ...
                'enablePdfDownload', logical(app.EnablePdfDownloadCheckBox.Value), 'pdfMaxRows', double(app.PdfMaxRowsField.Value), ...
                'enablePdfTextExtraction', logical(app.EnablePdfTextCheckBox.Value), ...
                'enableKeywordEvidence', logical(app.EnableKeywordEvidenceCheckBox.Value));
        end

        function loadCandidateReview(app)
            % The candidate CSV can carry columns the review table does not
            % show (works_count), and uitable rejects string cells, so select
            % the displayed columns by name and convert text to char.
            candidateTable = AnyResearchApp.readCandidateCsv(app.BatchCandidatePath);
            displayedNames = string(app.CandidateTable.ColumnName(:))';
            missingNames = setdiff(displayedNames, string(candidateTable.Properties.VariableNames));
            if ~isempty(missingNames)
                error('AnyResearch:candidateColumns', ...
                    'The candidate CSV is missing column(s): %s', strjoin(missingNames, ', '));
            end
            displayed = candidateTable(:, cellstr(displayedNames));
            cells = cell(height(displayed), width(displayed));
            for column = 1:width(displayed)
                values = displayed.(column);
                for row = 1:height(displayed)
                    if displayedNames(column) == "include"
                        cells{row, column} = AnyResearchApp.includeValue(values(row));
                    else
                        cells{row, column} = char(values(row));
                    end
                end
            end
            app.CandidateTable.Data = cells;
            app.styleCarriedRows(candidateTable);
        end

        function styleCarriedRows(app, candidateTable)
            removeStyle(app.CandidateTable);
            carriedRows = find(AnyResearchApp.carriedCandidateMask(candidateTable));
            if isempty(carriedRows)
                return;
            end
            carriedStyle = uistyle('FontColor', [0.65 0.65 0.65]);
            addStyle(app.CandidateTable, carriedStyle, 'row', carriedRows);
        end

        function setAllInclude(app, tf)
            data = app.CandidateTable.Data;
            total = size(data, 1);
            columnNames = string(app.CandidateTable.ColumnName(:))';
            includeColumn = find(columnNames == "include", 1);
            idColumn = find(columnNames == "openalex_institution_id", 1);
            included = 0;
            for row = 1:total
                if tf && strlength(strtrim(string(data{row, idColumn}))) > 0
                    data{row, includeColumn} = 1;
                    included = included + 1;
                else
                    data{row, includeColumn} = 0;
                end
            end
            app.CandidateTable.Data = data;
            status = sprintf('Included %d of %d rows.', included, total);
            if tf && included < total
                status = status + " Rows without an OpenAlex institution ID were left out.";
            end
            app.StatusLabel.Text = status;
        end

        function [newRows, carriedRows] = countCandidateRows(app)
            candidateTable = AnyResearchApp.readCandidateCsv(app.BatchCandidatePath);
            carriedMask = AnyResearchApp.carriedCandidateMask(candidateTable);
            newRows = nnz(~carriedMask);
            carriedRows = nnz(carriedMask);
        end

        function onBatchRunComplete(app, result, err)
            if ~isempty(err)
                failure = AnyResearchApp.describeFailure(err, "Batch");
                app.StatusLabel.Text = failure.status;
                uialert(app.UIFigure, err.message, failure.title);
                return;
            end
            app.rememberOutputFolder(result.batch_dir);
            if result.dry_run
                app.StatusLabel.Text = sprintf('Batch dry run complete: %d/%d institutions previewed (no works fetched). Output: %s', result.dry_run_count, result.total_institutions, result.batch_dir);
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
            [newRows, carriedRows] = app.countCandidateRows();
            app.StatusLabel.Text = sprintf('Candidates generated: %d new rows, %d carried over from the current list. Review include, role and note.', newRows, carriedRows);
            app.showBatchStep(2);
        end

        function onSearchComplete(app, result, err, searchOptions)
            if nargin < 4
                searchOptions = struct();
            end
            if ~isempty(err)
                failure = AnyResearchApp.describeFailure(err, "Search");
                app.StatusLabel.Text = failure.status;
                uialert(app.UIFigure, err.message, failure.title);
                return;
            end
            app.rememberOutputFolder(result.run_dir);
            app.StatusLabel.Text = sprintf('Search complete: %s. Output: %s', ...
                AnyResearchApp.describeSearchSummary(result, searchOptions), result.run_dir);
        end

        function preview = getSearchCountPreview(app, searchOptions)
            if isempty(app.CountPreviewForTesting)
                preview = AnyResearchApp.previewSearchCount(searchOptions);
                return;
            end
            try
                preview = app.CountPreviewForTesting(searchOptions);
            catch err
                preview = struct('ok', false, 'total', NaN, 'message', string(err.message));
            end
        end

        function answer = getLimitAnswer(app, maxRecords, total)
            if ~isempty(app.LimitAnswerForTesting)
                answer = string(app.LimitAnswerForTesting);
                return;
            end
            limitLabel = sprintf('Fetch first %d', maxRecords);
            allLabel = sprintf('Fetch all %d', total);
            choice = uiconfirm(app.UIFigure, ...
                sprintf('%d works match this search. Choose how many to fetch.', total), ...
                'Search result limit', 'Options', {limitLabel, allLabel, 'Cancel'}, ...
                'DefaultOption', 1, 'CancelOption', 3, 'Icon', 'warning');
            if strcmp(choice, limitLabel)
                answer = "limit";
            elseif strcmp(choice, allLabel)
                answer = "all";
            else
                answer = "cancel";
            end
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
            try
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
            catch err
                app.StatusLabel.Text = 'API key save failed.';
                uialert(app.UIFigure, err.message, 'API key save failed');
                return;
            end
            app.ApiKeyEditField.Value = '';
            if strlength(string(app.SettingsPathOverride)) > 0
                app.StatusLabel.Text = 'API key saved to the isolated test settings file.';
            else
                app.StatusLabel.Text = 'API key saved to config/settings.json. An environment variable still takes precedence.';
            end
        end

        function tf = confirmPromotion(app)
            % Promoting overwrites the reviewed institutions list. Ask first when a list
            % already exists (the first promotion has nothing to lose).
            summary = AnyResearchApp.describePromotion(app.BatchCandidatePath, app.ReviewedInstitutionsPath);
            if ~summary.replacesExisting
                tf = true;
                return;
            end
            if ~isempty(app.PromotionConfirmAnswer)
                tf = logical(app.PromotionConfirmAnswer);
            else
                choice = uiconfirm(app.UIFigure, char(summary.message), 'Replace institutions list?', ...
                    'Options', {'Promote', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
                tf = strcmp(choice, 'Promote');
            end
            if ~tf
                app.StatusLabel.Text = 'Promotion cancelled. The institutions list was not changed.';
            end
        end

        function saveCandidateReview(app)
            % Write back only the reviewer-editable columns so every other CSV
            % column (works_count included) and the row order stay untouched.
            candidateTable = AnyResearchApp.readCandidateCsv(app.BatchCandidatePath);
            reviewed = app.CandidateTable.Data;
            if size(reviewed, 1) ~= height(candidateTable)
                error('AnyResearch:candidateRows', ...
                    'The review table has %d rows but the candidate CSV has %d.', ...
                    size(reviewed, 1), height(candidateTable));
            end
            displayedNames = string(app.CandidateTable.ColumnName(:))';
            for name = ["include", "role", "note"]
                column = find(displayedNames == name, 1);
                if isempty(column); continue; end
                values = reviewed(:, column);
                if name == "include"
                    candidateTable.include = cellfun(@AnyResearchApp.includeValue, values);
                else
                    texts = strings(numel(values), 1);
                    for row = 1:numel(values)
                        texts(row) = string(values{row});
                    end
                    candidateTable.(name) = texts;
                end
            end
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

        function onBatchRunCompleteForTesting(app, result, err)
            app.onBatchRunComplete(result, err);
        end

        function onPrepareInstitutionsCompleteForTesting(app, result, err)
            app.onPrepareInstitutionsComplete(result, err);
        end

        function onSearchCompleteForTesting(app, result, err)
            app.onSearchComplete(result, err);
        end

        function loadCandidateReviewForTesting(app)
            app.loadCandidateReview();
        end

        function options = getBatchPrepareOptionsForTesting(app)
            options = app.getBatchPrepareOptions();
        end

        function searchOptions = getSearchOptionsForTesting(app)
            searchOptions = app.getSearchOptions();
        end

        function summary = describePromotionForTesting(app)
            summary = AnyResearchApp.describePromotion(app.BatchCandidatePath, app.ReviewedInstitutionsPath);
        end

        function setPromotionConfirmForTesting(app, answer)
            app.PromotionConfirmAnswer = answer;
        end

        function setSeedHintAnswerForTesting(app, answer)
            app.SeedHintAnswer = answer;
        end

        function setCountPreviewForTesting(app, fn)
            app.CountPreviewForTesting = fn;
        end

        function setSearchRunnerForTesting(app, fn)
            app.SearchRunnerForTesting = fn;
        end

        function setLimitAnswerForTesting(app, answer)
            app.LimitAnswerForTesting = answer;
        end

        function setFolderOpenerForTesting(app, fn)
            app.FolderOpener = fn;
        end

        function proceed = confirmSeedLikeQueryForTesting(app)
            proceed = app.confirmSeedLikeQuery();
        end

        function setBusyForTesting(app, tf)
            app.setBusy(tf);
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

        function openFolderInOs(folderPath)
            folderPath = char(string(folderPath));
            if ispc
                winopen(folderPath);
                return;
            end
            quotedPath = ['"' strrep(folderPath, '"', '\\"') '"'];
            if ismac
                [status, message] = system(['open ' quotedPath]);
            else
                [status, message] = system(['xdg-open ' quotedPath]);
            end
            if status ~= 0
                error('AnyResearch:openOutputFolder', '%s', strtrim(message));
            end
        end

        function period = defaultPeriod(asOf)
            toDate = dateshift(asOf, 'start', 'day');
            period = struct('from', toDate - calyears(1), 'to', toDate);
        end

        function assertDateRange(fromDate, toDate)
            % An unset (NaT) side leaves that end of the range open.
            if ~isnat(fromDate) && ~isnat(toDate) && fromDate > toDate
                error('AnyResearch:invalidDateRange', 'From date must not be later than To date.');
            end
        end

        function info = describeFailure(err, kind)
            kind = string(kind);
            inputErrorIds = ["AnyResearch:invalidDateRange", ...
                "AnyResearch:invalidCitationRange", "AnyResearch:emptyBatchQuery"];
            if ismember(string(err.identifier), inputErrorIds)
                info = struct('title', "Check your input", 'status', "Check your input.");
            else
                info = struct('title', kind + " failed", 'status', kind + " failed.");
            end
        end

        function preview = previewSearchCount(searchOptions)
            preview = struct('ok', false, 'total', NaN, 'message', "");
            try
                projectRoot = AnyResearchApp.resolveProjectRoot();
                addpath(fullfile(projectRoot, "src", "pipeline"));
                raw = preview_search_count(searchOptions.query, searchOptions.fromDate, searchOptions.toDate, ...
                    language=searchOptions.language, requireOpenAccess=searchOptions.requireOpenAccess, ...
                    requireAbstract=searchOptions.requireAbstract, filterCountryCode=searchOptions.filterCountryCode, ...
                    filterType=searchOptions.filterType, citedByMin=searchOptions.citedByMin, ...
                    citedByMax=searchOptions.citedByMax, ...
                    firstAuthorInstitutionId=searchOptions.firstAuthorInstitutionId);
                preview = struct('ok', true, 'total', double(raw.total_hits), 'message', "");
            catch err
                preview.message = string(err.message);
            end
        end

        function summary = describeSearchSummary(result, searchOptions)
            rows = double(result.rows_fetched);
            hasTotal = isfield(result, 'total_hits') && isfinite(double(result.total_hits));
            if hasTotal
                total = double(result.total_hits);
            else
                total = NaN;
            end
            limitReached = isfield(result, 'limit_reached') && logical(result.limit_reached);
            hasInstitution = isfield(searchOptions, 'firstAuthorInstitution') && ...
                strlength(strtrim(string(searchOptions.firstAuthorInstitution))) > 0;
            hasInstitutionId = isfield(searchOptions, 'firstAuthorInstitutionId') && ...
                strlength(strtrim(string(searchOptions.firstAuthorInstitutionId))) > 0;
            if hasInstitution || hasInstitutionId
                if limitReached && hasTotal
                    summary = sprintf('%d works (limit reached: not all of the %d matches were checked against the first-author institution)', rows, total);
                elseif hasTotal
                    summary = sprintf('%d works (OpenAlex matched %d before the first-author filter)', rows, total);
                else
                    summary = sprintf('%d works', rows);
                end
            elseif limitReached && hasTotal
                summary = sprintf('%d of %d works (limit reached)', rows, total);
            else
                summary = sprintf('%d works', rows);
            end
        end

        function tf = looksLikeSeedId(text)
            text = strtrim(string(text));
            doiPattern = '^(?:doi:|https://doi\.org/|http://dx\.doi\.org/)?10\.\d{4,9}/\S+$';
            workIdPattern = '^(?:https://openalex\.org/)?W\d{6,}$';
            tf = ~isempty(regexp(text, doiPattern, 'once', 'ignorecase')) ...
                || ~isempty(regexp(text, workIdPattern, 'once', 'ignorecase'));
        end

        function summary = describePromotion(candidatePath, reviewedPath)
            % What promoting will do to an existing reviewed list: how many institutions are
            % included in the new list and in the current one (a legacy two-column file counts
            % every row as included, as the batch does).
            projectRoot = AnyResearchApp.resolveProjectRoot();
            addpath(fullfile(projectRoot, "src", "openalex"));
            candidate = AnyResearchApp.readCandidateCsv(candidatePath);
            newIncluded = nnz(arrayfun(@AnyResearchApp.includeValue, candidate.include) > 0);
            summary = struct('replacesExisting', isfile(reviewedPath), 'newIncluded', newIncluded, ...
                'currentIncluded', 0, 'currentIsLegacy', false, 'message', "");
            if ~summary.replacesExisting
                return;
            end
            try
                [current, isLegacy] = read_institutions_review_csv(reviewedPath);
                summary.currentIncluded = nnz(arrayfun(@AnyResearchApp.includeValue, current.include) > 0);
                summary.currentIsLegacy = isLegacy;
            catch
                summary.currentIncluded = -1;   % unreadable: still ask before replacing it
            end
            if summary.currentIncluded < 0
                currentText = "an unreadable list";
            else
                currentText = string(summary.currentIncluded) + " in the current list";
                if summary.currentIsLegacy
                    currentText = currentText + " (the old list format counts every row as included)";
                end
            end
            summary.message = "This replaces the current institutions list:" + newline + string(reviewedPath) + newline + newline + ...
                "Included institutions: " + newIncluded + " in the new list, " + currentText + "." + newline + ...
                "The current file is saved as a backup copy (.bak) first.";
        end

        function candidateTable = readCandidateCsv(csvPath)
            % Text columns are read as string with blanks as "" (an all-blank
            % column such as note would otherwise become NaN doubles and be
            % written back as "NaN"); only include and works_count are numeric.
            importOptions = detectImportOptions(csvPath, TextType="string");
            textVariables = setdiff(string(importOptions.VariableNames), ["include", "works_count"]);
            importOptions = setvartype(importOptions, cellstr(textVariables), "string");
            importOptions = setvaropts(importOptions, cellstr(textVariables), FillValue="");
            candidateTable = readtable(csvPath, importOptions);
        end

        function mask = carriedCandidateMask(candidateTable)
            mask = contains(string(candidateTable.note), "not returned by API on");
        end

        function value = includeValue(cellValue)
            % Review-table include cell -> 1/0 (blank or unparsable means skip).
            if isnumeric(cellValue) || islogical(cellValue)
                value = double(cellValue);
            else
                value = str2double(string(cellValue));
            end
            if isempty(value) || isnan(value)
                value = 0;
            end
        end

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
                maxRecords=searchOptions.maxRecords, showCountPreview=false, ...
                enablePdfDownload=searchOptions.enablePdfDownload, pdfMaxRows=searchOptions.pdfMaxRows, ...
                enablePdfTextExtraction=searchOptions.enablePdfTextExtraction, ...
                enableKeywordEvidence=searchOptions.enableKeywordEvidence);
            if isfield(searchOptions, 'previewTotal') && isfinite(searchOptions.previewTotal)
                result.total_hits = int32(searchOptions.previewTotal);
                result.limit_reached = searchOptions.previewTotal > searchOptions.maxRecords;
            end
        end

    end

    % Callbacks that handle component events
    methods

        % Code that executes after component creation
        function startupFcn(app)
            period = AnyResearchApp.defaultPeriod(datetime('now'));
            app.FromDatePicker.Value = period.from;
            app.ToDatePicker.Value = period.to;
            app.BatchFromDatePicker.Value = period.from;
            app.BatchToDatePicker.Value = period.to;
            projectRoot = AnyResearchApp.resolveProjectRoot();
            app.BatchCandidatePath = string(fullfile(projectRoot, 'data', 'list', 'institutions_candidate.csv'));
            app.ReviewedInstitutionsPath = string(fullfile(projectRoot, 'data', 'list', 'institutions.csv'));
            app.showBatchStep(1);
            app.CandidateTable.ColumnEditable = logical([0 0 0 0 1 1 1 0]);
            app.associateFieldLabels();
            app.OpenOutputButton.ButtonPushedFcn = @(~, ~) app.openOutputFolder();
            app.IncludeAllButton.ButtonPushedFcn = @(~, ~) app.setAllInclude(true);
            app.IncludeNoneButton.ButtonPushedFcn = @(~, ~) app.setAllInclude(false);
        end

        % Close request function: UIFigure
        function CloseRequestFcn(app, event)
            delete(app.UIFigure);
        end

        % Button pushed function: SearchRunButton
        function SearchRunButtonPushed(app, event)
            if ~app.hasSearchQuery()
                uialert(app.UIFigure, 'Enter a search query or a seed DOI / OpenAlex work ID before running.', 'Query required');
                return;
            end
            if ~app.confirmSeedLikeQuery()
                return;
            end
            app.setBusy(true);
            busyCleanup = onCleanup(@() app.restoreIdleAfterBusyError());
            app.StatusLabel.Text = 'Search is running...';
            drawnow;
            try
                searchOptions = app.getSearchOptions();
                cancelled = false;
                if searchOptions.seedId == ""
                    preview = app.getSearchCountPreview(searchOptions);
                    if preview.ok && isfinite(preview.total)
                        searchOptions.previewTotal = double(preview.total);
                        if preview.total > searchOptions.maxRecords
                            answer = app.getLimitAnswer(searchOptions.maxRecords, preview.total);
                            switch answer
                                case "all"
                                    searchOptions.maxRecords = double(preview.total);
                                case "cancel"
                                    cancelled = true;
                            end
                        end
                    end
                end
                if cancelled
                    app.StatusLabel.Text = 'Search cancelled before fetching works.';
                elseif isempty(app.SearchRunnerForTesting)
                    result = AnyResearchApp.runSearchPipeline(searchOptions);
                    app.onSearchComplete(result, [], searchOptions);
                else
                    result = app.SearchRunnerForTesting(searchOptions);
                    app.onSearchComplete(result, [], searchOptions);
                end
            catch err
                app.onSearchComplete([], err);
            end
            app.setBusy(false);
            if ~isempty(busyCleanup); clear busyCleanup; end
        end

        % Button pushed function: GenerateCandidatesButton
        function GenerateCandidatesButtonPushed(app, event)
            app.setBusy(true);
            busyCleanup = onCleanup(@() app.restoreIdleAfterBusyError());
            app.StatusLabel.Text = 'Generating institution candidates...';
            drawnow;
            try
                result = AnyResearchApp.prepareInstitutions(app.getBatchPrepareOptions());
                app.onPrepareInstitutionsComplete(result, []);
            catch err
                app.onPrepareInstitutionsComplete([], err);
            end
            app.setBusy(false);
            if ~isempty(busyCleanup); clear busyCleanup; end
        end

        % Button pushed function: ReviewCandidatesButton
        function ReviewCandidatesButtonPushed(app, event)
            if ~isfile(app.BatchCandidatePath)
                uialert(app.UIFigure, 'Generate institution candidates before reviewing.', 'Candidates required');
                return;
            end
            app.saveCandidateReview();
            app.StatusLabel.Text = 'Review saved. Promote the reviewed candidates to use them in a batch run.';
            app.showBatchStep(3);
        end

        % Button pushed function: PromoteCandidatesButton
        function PromoteCandidatesButtonPushed(app, event)
            if ~isfile(app.BatchCandidatePath)
                uialert(app.UIFigure, 'Generate institution candidates before promoting.', 'Candidates required');
                return;
            end
            app.saveCandidateReview();
            if ~app.confirmPromotion()
                return;
            end
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
            app.setBusy(true);
            busyCleanup = onCleanup(@() app.restoreIdleAfterBusyError());
            app.StatusLabel.Text = 'Batch is running...';
            drawnow;
            try
                result = AnyResearchApp.runBatchPipeline(app.getBatchRunOptions());
                app.onBatchRunComplete(result, []);
            catch err
                app.onBatchRunComplete([], err);
            end
            app.setBusy(false);
            if ~isempty(busyCleanup); clear busyCleanup; end
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
