function signalTable = detect_repro_signals(titleText, abstractText, options)
%DETECT_REPRO_SIGNALS Detect reproducibility-oriented signals from title+abstract.

arguments
    titleText
    abstractText
    options.ConfigPath (1,1) string = ""
end

titleVec = string(titleText);
abstractVec = string(abstractText);
titleVec(ismissing(titleVec)) = "";
abstractVec(ismissing(abstractVec)) = "";

n = numel(titleVec);
if numel(abstractVec) ~= n
    error("detect_repro_signals:InvalidLength", ...
        "titleText and abstractText must have the same number of rows.");
end

cfg = load_repro_signals_config(options.ConfigPath);

mentionsDataset = false(n, 1);
mentionsCode = false(n, 1);
mentionsLibrary = false(n, 1);
mentionsMetrics = false(n, 1);
matlabMentioned = false(n, 1);

for i = 1:n
    combined = strtrim(titleVec(i) + " " + abstractVec(i));
    mentionsDataset(i) = local_match_terms(combined, cfg.mentions_dataset);
    mentionsCode(i) = local_match_terms(combined, cfg.mentions_code);
    mentionsLibrary(i) = local_match_terms(combined, cfg.mentions_library);
    mentionsMetrics(i) = local_match_terms(combined, cfg.mentions_metrics);
    matlabMentioned(i) = local_match_terms(combined, cfg.matlab_terms);
end

reproSignalScore = double(mentionsDataset) + double(mentionsCode) + ...
    double(mentionsLibrary) + double(mentionsMetrics);

signalTable = table( ...
    mentionsDataset, mentionsCode, mentionsLibrary, mentionsMetrics, ...
    reproSignalScore, matlabMentioned, ...
    'VariableNames', { ...
        'mentions_dataset', 'mentions_code', 'mentions_library', 'mentions_metrics', ...
        'repro_signal_score', 'matlab_mentioned'});
end

function tf = local_match_terms(textValue, terms)
tf = false;
txt = char(string(textValue));
if isempty(txt)
    return;
end

for i = 1:numel(terms)
    term = char(string(terms(i)));
    if isempty(term)
        continue;
    end
    if local_is_simple_word(term)
        pattern = ['(?<![a-zA-Z0-9_])', regexptranslate('escape', term), '(?![a-zA-Z0-9_])'];
        if ~isempty(regexpi(txt, pattern, 'once'))
            tf = true;
            return;
        end
    else
        if contains(lower(string(txt)), lower(string(term)))
            tf = true;
            return;
        end
    end
end
end

function tf = local_is_simple_word(term)
tf = ~isempty(regexp(term, '^[A-Za-z0-9_]+$', 'once'));
end
