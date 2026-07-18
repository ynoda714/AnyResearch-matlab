function test_jsonl_roundtrip_smoke()
%TEST_JSONL_ROUNDTRIP_SMOKE  M13 JSONL roundtrip integrity smoke test
%
%   addpath("src/util"); addpath("test/smoke");
%   test_jsonl_roundtrip_smoke();
%
% Target: write_jsonl.m / read_jsonl.m
% Test coverage:
%   1. Basic string + numeric table roundtrip integrity
%   2. missing string -> written and read back as ""
%   3. NaN (numeric) roundtrip (JSON null <-> NaN)
%   4. write/read of empty table
%   5. Row/column count preserved for multi-row, multi-column table
%   6. File is written as UTF-8 (without BOM)
%   7. read_jsonl throws an error for a non-existent file
%   8. commas / newlines / quotes survive JSONL roundtrip

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', '..', 'src', 'util'));

tmpDir = fullfile(tempdir, 'smoke_m13_jsonl');
if isfolder(tmpDir); rmdir(tmpDir, 's'); end
mkdir(tmpDir);
cleanup = onCleanup(@() rmdir(tmpDir, 's'));

%% Case 1: Basic string + numeric table roundtrip integrity
ids     = ["W001"; "W002"; "W003"];
titles  = ["MATLAB Analysis"; "Deep Learning"; "Open Access"];
scores  = [0.9; 0.7; 0.5];
T1 = table(ids, titles, scores, 'VariableNames', ["id", "title", "score"]);

f1 = fullfile(tmpDir, 'case1.jsonl');
write_jsonl(T1, f1);
assert(isfile(f1), "Case1: ファイルが生成されなかった");

R1 = read_jsonl(f1);
assert(height(R1) == 3, "Case1: 行数が一致しない");
assert(width(R1) == 3, "Case1: 列数が一致しない");
assert(all(string(R1.id) == ids), "Case1: id 列が一致しない");
assert(all(string(R1.title) == titles), "Case1: title 列が一致しない");
assert(all(abs(R1.score - scores) < 1e-10), "Case1: score 列が一致しない");
fprintf("[PASS] Case1: 基本的な string + numeric テーブル往復\n");

%% Case 2: missing string -> roundtrip as ""
ids2    = ["W001"; "W002"];
titles2 = ["Valid Title"; missing];
T2 = table(ids2, titles2, 'VariableNames', ["id", "title"]);

f2 = fullfile(tmpDir, 'case2.jsonl');
write_jsonl(T2, f2);
R2 = read_jsonl(f2);

assert(height(R2) == 2, "Case2: 行数が一致しない");
assert(string(R2.title(2)) == "", "Case2: missing が """" にならなかった");
fprintf("[PASS] Case2: missing string → """"\n");

%% Case 3: NaN (numeric) roundtrip (JSON null <-> NaN)
ids3   = ["W001"; "W002"; "W003"];
years3 = [2024; NaN; 2022];
T3 = table(ids3, years3, 'VariableNames', ["id", "year"]);

f3 = fullfile(tmpDir, 'case3.jsonl');
write_jsonl(T3, f3);
R3 = read_jsonl(f3);

assert(height(R3) == 3, "Case3: 行数が一致しない");
assert(R3.year(1) == 2024, "Case3: year(1) が 2024 でない");
assert(isnan(R3.year(2)), "Case3: NaN が NaN として読み込まれなかった");
assert(R3.year(3) == 2022, "Case3: year(3) が 2022 でない");
fprintf("[PASS] Case3: NaN の往復（JSON null ↔ NaN）\n");

%% Case 4: empty table write/read is special (0 rows)
T4 = table('Size', [0 2], 'VariableTypes', ["string", "double"], 'VariableNames', ["id", "val"]);
f4 = fullfile(tmpDir, 'case4.jsonl');
write_jsonl(T4, f4);
% reading a 0-row file with read_jsonl returns an empty table
R4 = read_jsonl(f4);
assert(height(R4) == 0, "Case4: 空テーブルの read が 0 行でない");
fprintf("[PASS] Case4: 空テーブル（0行）の往復\n");

%% Case 5: multi-row, multi-column: file line count = table row count
n5 = 20;
ids5    = arrayfun(@(i) sprintf("W%04d", i), 1:n5, 'UniformOutput', false);
ids5    = string(ids5)';
scores5 = rand(n5, 1);
T5 = table(ids5, scores5, 'VariableNames', ["id", "score"]);

f5 = fullfile(tmpDir, 'case5.jsonl');
write_jsonl(T5, f5);
R5 = read_jsonl(f5);

assert(height(R5) == n5, "Case5: 行数不一致");
% Verify file line count
lines5 = strsplit(strtrim(fileread(f5)), newline);
lines5 = lines5(~cellfun(@isempty, lines5));
assert(numel(lines5) == n5, "Case5: ファイル行数が正しくない");
fprintf("[PASS] Case5: 複数行テーブルの行数保持（%d行）\n", n5);

%% Case 6: File is written as UTF-8 (without BOM)
f6 = fullfile(tmpDir, 'case6.jsonl');
T6 = table(["日本語テスト"], [1.0], 'VariableNames', ["text", "val"]);
write_jsonl(T6, f6);

fid6 = fopen(f6, 'rb');
bytes6 = fread(fid6, 3, '*uint8');
fclose(fid6);
bom = uint8([239; 187; 191]);
assert(~isequal(bytes6, bom), "Case6: BOM が付いている（UTF-8 BOM なしが期待値）");

R6 = read_jsonl(f6);
assert(string(R6.text(1)) == "日本語テスト", "Case6: 日本語の往復に失敗: " + R6.text(1));
fprintf("[PASS] Case6: UTF-8 BOM なし / 日本語往復\n");

%% Case 7: read_jsonl throws an error for a non-existent file
f7 = fullfile(tmpDir, 'nonexistent_xyz.jsonl');
try
    read_jsonl(f7);
    error("Case7: エラーが投げられなかった（期待: read_jsonl:NotFound）");
catch ex
    assert(strcmp(ex.identifier, "read_jsonl:NotFound"), ...
        "Case7: エラー ID が想定外: " + ex.identifier);
end
fprintf("[PASS] Case7: 存在しないファイルで read_jsonl:NotFound エラー\n");

%% Case 8: commas / newlines / quotes survive JSONL roundtrip
specialText = "comma, quote ""here"", line1" + newline + "line2";
T8 = table(["W9001"], [specialText], 'VariableNames', ["id", "title"]);
f8 = fullfile(tmpDir, 'case8.jsonl');
write_jsonl(T8, f8);
R8 = read_jsonl(f8);
assert(height(R8) == 1, "Case8: 行数が一致しない");
assert(R8.title(1) == specialText, "Case8: 特殊文字テキストの往復に失敗");
fprintf("[PASS] Case8: カンマ / 改行 / 引用符の往復\n");

fprintf("\n[ALL PASS] test_jsonl_roundtrip_smoke 完了\n");
end
