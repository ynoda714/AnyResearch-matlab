function test_openalex_to_normalized_works_smoke()
% Case 1: Input containing first_author_name/first_author_institutions
source = table( ...
    ["W1"; "W2"], ...
    ["Graph Neural Networks"; "Open Access Policy"], ...
    ["We propose a new architecture."; "This paper reviews OA mandates."], ...
    ["10.1000/abc"; "10.1000/xyz"], ...
    [2025; 2024], ...
    ["Alice Smith"; "Bob Jones"], ...
    ["Toyota Tech Institute"; "Osaka University"], ...
    'VariableNames', ["openalex_id", "title", "abstract", "doi", "publication_year", "first_author_name", "first_author_institutions"] ...
    );

result = openalex_to_normalized_works(source);

assert(height(result) == 2);
assert(width(result)  == 33, 'Case1: must have exactly 33 columns');
assert(all(ismember(["record_id", "title", "abstract", "openalex_id", "doi", "doi_normalized", ...
    "publication_year", "publication_date", "cited_by_count", "fwci", "citation_percentile", ...
    "counts_by_year", "is_retracted", "best_oa_pdf_url", "license", "referenced_works_count", "source_dataset", ...
    "first_author_name", "first_author_institutions", ...
    "last_author_name",  "last_author_institutions", ...
    "mentions_dataset", "mentions_code", "mentions_library", "mentions_metrics", "repro_signal_score", ...
    "matlab_mentioned",  "is_oa", "type", "source_name", ...
    "open_access_url",   "topics", "language"], ...
    string(result.Properties.VariableNames))));
assert(all(strlength(result.record_id) > 0));
assert(all(strlength(result.title) > 0));
assert(all(strlength(result.abstract) > 0));
assert(result.first_author_name(1) == "Alice Smith");
assert(result.first_author_institutions(2) == "Osaka University");
% doi_normalized: lowercase + trim of input doi
assert(result.doi_normalized(1) == "10.1000/abc", 'Case1: doi_normalized row1');
assert(result.doi_normalized(2) == "10.1000/xyz", 'Case1: doi_normalized row2');
% source_dataset: default "openalex" when input column absent
assert(all(result.source_dataset == "openalex"), 'Case1: source_dataset default value');
% last_author_* default to "" when absent from input
assert(ismember("last_author_name",         string(result.Properties.VariableNames)), 'Case1: last_author_name column');
assert(ismember("last_author_institutions",  string(result.Properties.VariableNames)), 'Case1: last_author_institutions column');
assert(result.last_author_name(1)        == "", 'Case1: last_author_name defaults to empty');
assert(result.last_author_institutions(1) == "", 'Case1: last_author_institutions defaults to empty');
% matlab_mentioned: false for abstracts with no MATLAB keyword
assert(ismember("matlab_mentioned", string(result.Properties.VariableNames)), 'Case1: matlab_mentioned column');
assert(result.matlab_mentioned(1) == false, 'Case1: matlab_mentioned row1 (no MATLAB keyword)');
assert(result.matlab_mentioned(2) == false, 'Case1: matlab_mentioned row2 (no MATLAB keyword)');
assert(result.repro_signal_score(1) == 0, 'Case1: repro_signal_score row1');
assert(result.repro_signal_score(2) == 0, 'Case1: repro_signal_score row2');

% Case 2: Input without first_author_* columns is padded with empty strings
source2 = table( ...
    ["W3"], ...
    ["Topology Optimization"], ...
    ["We apply TO methods."], ...
    'VariableNames', ["openalex_id", "title", "abstract"] ...
    );
result2 = openalex_to_normalized_works(source2);
assert(ismember("first_author_name", string(result2.Properties.VariableNames)));
assert(ismember("first_author_institutions", string(result2.Properties.VariableNames)));
assert(result2.first_author_name(1) == "");
assert(result2.first_author_institutions(1) == "");

% Case 3: OpenAlex passthrough columns present with explicit values -> verify pass-through
source3 = table( ...
    ["W4"; "W5"], ...
    ["Topology Optimization"; "Quantum Circuit"], ...
    ["Abstract text A."; "Abstract text B."], ...
    ["10.1000/p"; "10.2000/q"], ...
    [2024; 2023], ...
    ["2024-05-01"; "2023-08-15"], ... % publication_date
    [50.0; 10.0], ...      % cited_by_count
    [2.5; 0.7], ...        % fwci
    [0.95; 0.12], ...      % citation_percentile
    ["[{""year"":2024,""cited_by_count"":12}]"; "[{""year"":2023,""cited_by_count"":2}]"], ... % counts_by_year
    [0.0; 1.0], ...        % is_retracted
    ["https://pdf1"; ""], ... % best_oa_pdf_url
    ["cc-by"; "cc-by-nc"], ... % license
    [42.0; 5.0], ...       % referenced_works_count
    [1.0; 0.0], ...        % is_oa (double)
    ["article"; "review"], ...  % type
    ["Nature"; "Science"], ...  % source_name
    ["https://oa1"; ""], ...    % open_access_url
    ["cs.AI; ML"; "physics"], ...  % topics
    ["en"; "ja"], ...      % language
    'VariableNames', ["openalex_id","title","abstract","doi","publication_year","publication_date", ...
        "cited_by_count","fwci","citation_percentile","counts_by_year","is_retracted","best_oa_pdf_url","license","referenced_works_count", ...
        "is_oa","type","source_name","open_access_url","topics","language"] ...
    );
result3 = openalex_to_normalized_works(source3);
assert(height(result3) == 2, 'Case3: row count');
assert(result3.publication_date(1) == "2024-05-01", 'Case3: publication_date row1 pass-through');
assert(result3.fwci(1) == 2.5, 'Case3: fwci row1 pass-through');
assert(result3.citation_percentile(2) == 0.12, 'Case3: citation_percentile row2 pass-through');
assert(result3.counts_by_year(1) == "[{""year"":2024,""cited_by_count"":12}]", 'Case3: counts_by_year row1 pass-through');
assert(result3.is_retracted(2) == 1.0, 'Case3: is_retracted row2 pass-through');
assert(result3.best_oa_pdf_url(1) == "https://pdf1", 'Case3: best_oa_pdf_url row1 pass-through');
assert(result3.license(2) == "cc-by-nc", 'Case3: license row2 pass-through');
assert(result3.referenced_works_count(1) == 42.0, 'Case3: referenced_works_count row1 pass-through');
assert(ismember("is_oa",          result3.Properties.VariableNames), 'Case3: is_oa column present');
assert(ismember("type",           result3.Properties.VariableNames), 'Case3: type column present');
assert(ismember("source_name",    result3.Properties.VariableNames), 'Case3: source_name column present');
assert(ismember("open_access_url",result3.Properties.VariableNames), 'Case3: open_access_url column present');
assert(ismember("topics",         result3.Properties.VariableNames), 'Case3: topics column present');
assert(ismember("language",       result3.Properties.VariableNames), 'Case3: language column present');
assert(result3.is_oa(1)           == 1.0,         'Case3: is_oa row1 pass-through');
assert(result3.is_oa(2)           == 0.0,         'Case3: is_oa row2 pass-through');
assert(result3.type(1)            == "article",   'Case3: type row1 pass-through');
assert(result3.type(2)            == "review",    'Case3: type row2 pass-through');
assert(result3.source_name(1)     == "Nature",    'Case3: source_name row1 pass-through');
assert(result3.source_name(2)     == "Science",   'Case3: source_name row2 pass-through');
assert(result3.open_access_url(1) == "https://oa1", 'Case3: open_access_url row1 pass-through');
assert(result3.open_access_url(2) == "",          'Case3: open_access_url row2 empty');
assert(result3.topics(1)          == "cs.AI; ML", 'Case3: topics row1 pass-through');
assert(result3.topics(2)          == "physics",   'Case3: topics row2 pass-through');
assert(result3.language(1)        == "en",        'Case3: language row1 pass-through');
assert(result3.language(2)        == "ja",        'Case3: language row2 pass-through');
assert(result3.repro_signal_score(1) == 0, 'Case3: repro_signal_score row1 default');

% Case 4: New columns absent -> defaults (NaN for numeric, "" for string columns)
source4 = table( ...
    ["W6"], ...
    ["Missing Extra Cols"], ...
    ["Abstract text C."], ...
    'VariableNames', ["openalex_id","title","abstract"] ...
    );
result4 = openalex_to_normalized_works(source4);
assert(isnan(result4.fwci(1)),                  'Case4: fwci must default to NaN when absent');
assert(isnan(result4.citation_percentile(1)),   'Case4: citation_percentile must default to NaN when absent');
assert(result4.counts_by_year(1) == "",         'Case4: counts_by_year must default to "" when absent');
assert(isnan(result4.is_retracted(1)),          'Case4: is_retracted must default to NaN when absent');
assert(result4.best_oa_pdf_url(1) == "",        'Case4: best_oa_pdf_url must default to "" when absent');
assert(result4.license(1) == "",                'Case4: license must default to "" when absent');
assert(isnan(result4.referenced_works_count(1)),'Case4: referenced_works_count must default to NaN when absent');
assert(ismember("is_oa",           result4.Properties.VariableNames), 'Case4: is_oa column present');
assert(ismember("type",            result4.Properties.VariableNames), 'Case4: type column present');
assert(ismember("source_name",     result4.Properties.VariableNames), 'Case4: source_name column present');
assert(ismember("open_access_url", result4.Properties.VariableNames), 'Case4: open_access_url column present');
assert(ismember("topics",          result4.Properties.VariableNames), 'Case4: topics column present');
assert(ismember("language",        result4.Properties.VariableNames), 'Case4: language column present');
assert(isnan(result4.is_oa(1)),           'Case4: is_oa must default to NaN when absent');
assert(result4.type(1)            == "",  'Case4: type must default to "" when absent');
assert(result4.source_name(1)     == "",  'Case4: source_name must default to "" when absent');
assert(result4.open_access_url(1) == "",  'Case4: open_access_url must default to "" when absent');
assert(result4.topics(1)          == "",  'Case4: topics must default to "" when absent');
assert(result4.language(1)        == "",  'Case4: language must default to "" when absent');
assert(result4.repro_signal_score(1) == 0, 'Case4: repro_signal_score default');

% Case 5: is_oa type must be double (not logical) for CSV round-trip consistency
source5 = table( ...
    ["W7"], ...
    ["Type Check"], ...
    ["Abstract type check."], ...
    [1.0], ...   % is_oa as double
    'VariableNames', ["openalex_id","title","abstract","is_oa"] ...
    );
result5 = openalex_to_normalized_works(source5);
assert(isa(result5.is_oa, 'double'), 'Case5: is_oa output type must be double');

fprintf("Smoke test passed: openalex_to_normalized_works\n");
end
