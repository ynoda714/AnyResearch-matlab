function test_search_expression_smoke()
%TEST_SEARCH_EXPRESSION_SMOKE  Shared AND/OR grammar for Query (Phase Y, ADR-004).
%
%   Grammar: space = AND, "|" = OR, "..." = phrase, ( ) = grouping.
%   AND and OR may not be mixed without parentheses.
%
%   addpath("test/smoke"); test_search_expression_smoke();

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', '..', 'src', 'util'));
addpath(fullfile(thisDir, '..', '..', 'src', 'openalex'));

% -- 1. Normalization to the OpenAlex search syntax ------------------------
cases = [ ...
    "MATLAB Simulink",            "MATLAB Simulink"; ...
    "MATLAB | Simulink",          "MATLAB OR Simulink"; ...
    "MATLAB|Simulink",            "MATLAB OR Simulink"; ...
    "MATLAB OR Simulink",         "MATLAB OR Simulink"; ...
    "MATLAB AND Simulink",        "MATLAB AND Simulink"; ...
    """Simulink model"" | Stateflow", """Simulink model"" OR Stateflow"; ...
    "MATLAB (Simulink | Octave)", "MATLAB (Simulink OR Octave)"; ...
    "(MATLAB Simulink) | Octave", "(MATLAB Simulink) OR Octave"; ...
    "MATLAB \| Simulink",         "MATLAB OR Simulink"; ...   % legacy escaped pipe
    "  MATLAB    Simulink  ",     "MATLAB Simulink"; ...
    "a or b",                     "a or b"];                  % lowercase "or" is an ordinary word
for i = 1:size(cases, 1)
    e = parse_search_expression(cases(i, 1));
    assert(e.openalex == cases(i, 2), ...
        "normalize [%s]: expected [%s], got [%s]", cases(i, 1), cases(i, 2), e.openalex);
end

% -- 2. Empty input is allowed (seed-only searches) -------------------------
e = parse_search_expression("");
assert(e.openalex == "" && isempty(e.terms), "empty expression must stay empty");
e = parse_search_expression("   ");
assert(e.openalex == "" && isempty(e.terms), "blank expression must stay empty");

% -- 3. Terms ----------------------------------------------------------------
e = parse_search_expression("""Simulink model"" | Stateflow");
assert(isequal(e.terms, ["Simulink model"; "Stateflow"]), "terms: phrase kept whole");
e = parse_search_expression("MATLAB (Simulink | Octave)");
assert(isequal(e.terms, ["MATLAB"; "Simulink"; "Octave"]), "terms: grouping");

% -- 4. Rejections -----------------------------------------------------------
expectError(@() parse_search_expression("a b | c"),   "parse_search_expression:MixedOperators");
expectError(@() parse_search_expression("a | b c"),   "parse_search_expression:MixedOperators");
expectError(@() parse_search_expression("a (b | c"),  "parse_search_expression:UnbalancedParentheses");
expectError(@() parse_search_expression("a b) | c"),  "parse_search_expression:UnbalancedParentheses");
expectError(@() parse_search_expression("""a b"),     "parse_search_expression:UnterminatedPhrase");
expectError(@() parse_search_expression("a | | b"),   "parse_search_expression:EmptyOperand");
expectError(@() parse_search_expression("| a"),       "parse_search_expression:EmptyOperand");
expectError(@() parse_search_expression("a |"),       "parse_search_expression:EmptyOperand");

% -- 5. Matching (case-insensitive; AND = same body, not same line) ---------
body = "We model the plant in Simulink." + newline + "Later we port it to matlab for tuning.";
assert(match_search_expression(parse_search_expression("MATLAB Simulink"), body), "AND across lines");
assert(~match_search_expression(parse_search_expression("MATLAB Octave"), body), "AND needs every term");
assert(match_search_expression(parse_search_expression("Octave | Simulink"), body), "OR needs one term");
assert(~match_search_expression(parse_search_expression("Octave | Scilab"), body), "OR with no hit");
assert(match_search_expression(parse_search_expression("""the plant"""), body), "phrase hit");
assert(~match_search_expression(parse_search_expression("""plant the"""), body), "phrase is contiguous and ordered");
assert(match_search_expression(parse_search_expression("MATLAB (Octave | Simulink)"), body), "grouping");
assert(~match_search_expression(parse_search_expression("(MATLAB Simulink) Octave"), body), "nested AND");
assert(~match_search_expression(parse_search_expression(""), body), "empty expression never matches");

% -- 6. Search target (all / title_and_abstract) ----------------------------
p = build_openalex_search_params("MATLAB | Simulink", "all");
assert(p.search == "MATLAB OR Simulink" && p.filterPart == "", "searchField=all uses search=");
p = build_openalex_search_params("MATLAB | Simulink", "title_and_abstract");
assert(p.search == "" && p.filterPart == "title_and_abstract.search:MATLAB OR Simulink", ...
    "searchField=title_and_abstract uses a filter");
p = build_openalex_search_params("""a, b"" c", "title_and_abstract");
assert(~contains(p.filterPart, ","), "commas inside the value would split the filter");
p = build_openalex_search_params("", "title_and_abstract");
assert(p.search == "" && p.filterPart == "", "empty query adds nothing");
expectError(@() build_openalex_search_params("a", "fulltext"), "build_openalex_search_params:BadField");

% -- 7. Country --------------------------------------------------------------
ccases = [ ...
    "",            ""; ...
    "JP",          "JP"; ...
    " jp | us ",   "JP|US"; ...
    "JP,US",       "JP|US"; ...
    "JP; US",      "JP|US"; ...
    "JP+US",       "JP+US"; ...
    "jp + us + de","JP+US+DE"; ...
    "JP|JP",       "JP"];
for i = 1:size(ccases, 1)
    r = normalize_country_expression(ccases(i, 1));
    assert(r == ccases(i, 2), "country [%s]: expected [%s], got [%s]", ccases(i, 1), ccases(i, 2), r);
end
expectError(@() normalize_country_expression("JP US"),    "normalize_country_expression:BadSeparator");
expectError(@() normalize_country_expression("JP|US+DE"), "normalize_country_expression:MixedOperators");
expectError(@() normalize_country_expression("JPN"),      "normalize_country_expression:BadCode");
expectError(@() normalize_country_expression("J1"),       "normalize_country_expression:BadCode");
expectError(@() normalize_country_expression("JP||US"),   "normalize_country_expression:BadCode");
expectError(@() normalize_country_expression("JP|"),      "normalize_country_expression:BadCode");

fprintf("test_search_expression_smoke: PASS\n");
end

function expectError(fn, id)
try
    fn();
catch ME
    assert(strcmp(ME.identifier, id), "expected error %s, got %s (%s)", id, ME.identifier, ME.message);
    return;
end
error("expected error %s but the call succeeded", id);
end
