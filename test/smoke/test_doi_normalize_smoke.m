function test_doi_normalize_smoke()
%TEST_DOI_NORMALIZE_SMOKE  M13 DOI normalization smoke test
%
%   addpath("src/adapters"); addpath("src/util"); addpath("test/smoke");
%   test_doi_normalize_smoke();
%
% Target: doi_normalized column in openalex_to_normalized_works.m
% What to verify:
%   1. Uppercase DOI -> lowercase
%   2. DOI with leading/trailing spaces -> trimmed
%   3. Uppercase + spaces -> lowercase + trim
%   4. Empty string -> ""
%   5. NaN/missing -> ""
%   6. Already normalized -> unchanged

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', '..', 'src', 'adapters'));
addpath(fullfile(thisDir, '..', '..', 'src', 'util'));

% -- Create sample table -------------------------------------------------
% Fixed title/abstract values to verify doi_normalized behavior
titles    = repmat("Test Title", 6, 1);
abstracts = repmat("Test abstract.", 6, 1);
dois = [ ...
    "10.1000/XYZ.001"; ...         % Case1: uppercase
    "  10.1000/abc.002  "; ...     % Case2: leading/trailing spaces
    "  10.1000/ABC.003  "; ...     % Case3: uppercase + spaces
    ""; ...                        % Case4: empty string
    string(missing); ...           % Case5: missing (explicit string type)
    "10.1000/xyz.006"; ...         % Case6: already normalized
];

T = table(titles, abstracts, dois, 'VariableNames', ["title", "abstract", "doi"]);

result = openalex_to_normalized_works(T, StrictValidation=false);

assert(ismember("doi_normalized", string(result.Properties.VariableNames)), ...
    "doi_normalized 列が存在しない");

dn = string(result.doi_normalized);

%% Case 1: Uppercase -> lowercase
assert(dn(1) == "10.1000/xyz.001", "Case1: 大文字のlowercaseが失敗: " + dn(1));
fprintf("[PASS] Case1: 大文字 → lowercase\n");

%% Case 2: Leading/trailing spaces -> trim
assert(dn(2) == "10.1000/abc.002", "Case2: trim が失敗: " + dn(2));
fprintf("[PASS] Case2: 前後スペース → trim\n");

%% Case 3: Uppercase + spaces -> lowercase + trim
assert(dn(3) == "10.1000/abc.003", "Case3: lowercase + trim が失敗: " + dn(3));
fprintf("[PASS] Case3: 大文字 + スペース → lowercase + trim\n");

%% Case 4: Empty string -> ""
assert(dn(4) == "", "Case4: 空文字が変化: " + dn(4));
fprintf("[PASS] Case4: 空文字 → 空文字\n");

%% Case 5: missing -> ""
assert(dn(5) == "", "Case5: missing が空文字にならなかった: " + dn(5));
fprintf("[PASS] Case5: missing → """"\n");

%% Case 6: Already normalized -> unchanged
assert(dn(6) == "10.1000/xyz.006", "Case6: 正規化済みが変化した: " + dn(6));
fprintf("[PASS] Case6: 正規化済み → 変化なし\n");

%% Verify that the original doi column is preserved
assert(ismember("doi", string(result.Properties.VariableNames)), "doi 列が保持されていない");
fprintf("[PASS] doi 列が保持されている\n");

fprintf("\n[ALL PASS] test_doi_normalize_smoke 完了\n");
end
