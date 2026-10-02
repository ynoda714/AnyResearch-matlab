function test_keyword_evidence_expression_smoke()
%TEST_KEYWORD_EVIDENCE_EXPRESSION_SMOKE  PDF keyword evidence uses the Query grammar (Phase Y, Y-3).
%
%   A row is "found" when the whole body satisfies the expression (AND = same body).
%   Snippets are the lines that contain any term of the expression.
%
%   addpath("test/smoke"); test_keyword_evidence_expression_smoke();

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', '..', 'src', 'util'));
addpath(fullfile(thisDir, '..', '..', 'src', 'pdf'));

tmp = tempname; mkdir(tmp);
cleanup = onCleanup(@() rmdir(tmp, 's')); %#ok<NASGU>

bodyBoth = "Intro line." + newline + "We use Simulink for the plant." + newline + "Filler." + newline + "Tuning is done in MATLAB.";
bodyOne  = "Only Octave is used here." + newline + "Nothing else.";
rows = { ...
    "W1", bodyBoth; ...
    "W2", bodyOne};
inJsonl = fullfile(tmp, 'pdf_text.jsonl');
fid = fopen(inJsonl, 'w');
for i = 1:size(rows, 1)
    s = struct('openalex_id', rows{i,1}, 'work_id', rows{i,1}, ...
        'extract_status', 'ok', 'body_text_excerpt', char(rows{i,2}));
    fprintf(fid, '%s\n', jsonencode(s));
end
fclose(fid);

% AND (space): W1 has both terms on different lines -> found; W2 has neither.
r = run_case(inJsonl, tmp, "MATLAB Simulink");
assert(isequal(r.status, ["found"; "not_found"]), "AND status: %s", strjoin(r.status, ","));
assert(contains(r.text(1), "Simulink") && contains(r.text(1), "MATLAB"), "AND snippets cover both terms");

% OR: W1 and W2 both hit through different terms.
r = run_case(inJsonl, tmp, "Octave | Simulink");
assert(isequal(r.status, ["found"; "found"]), "OR status: %s", strjoin(r.status, ","));

% Phrase is contiguous.
r = run_case(inJsonl, tmp, """for the plant""");
assert(isequal(r.status, ["found"; "not_found"]), "phrase status");
r = run_case(inJsonl, tmp, """plant for the""");
assert(isequal(r.status, ["not_found"; "not_found"]), "reversed phrase must not match");

% Grouping.
r = run_case(inJsonl, tmp, "MATLAB (Octave | Simulink)");
assert(isequal(r.status, ["found"; "not_found"]), "grouping status");

% Mixed AND/OR without parentheses is rejected before any work is done.
try
    run_case(inJsonl, tmp, "MATLAB Simulink | Octave");
    error("expected MixedOperators");
catch ME
    assert(strcmp(ME.identifier, "parse_search_expression:MixedOperators"), "got %s", ME.identifier);
end

% Existing behavior kept: empty query is an error.
try
    run_case(inJsonl, tmp, "  ");
    error("expected EmptyQuery");
catch ME
    assert(strcmp(ME.identifier, "extract_keyword_evidence:EmptyQuery"), "got %s", ME.identifier);
end

fprintf("test_keyword_evidence_expression_smoke: PASS\n");
end

function r = run_case(inJsonl, tmp, q)
outCsv = fullfile(tmp, 'evidence.csv');
extract_keyword_evidence(inJsonl, outCsv, q);
T = readtable(outCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve');
r.status = string(T.evidence_status);
r.text = string(T.evidence_text);
end
