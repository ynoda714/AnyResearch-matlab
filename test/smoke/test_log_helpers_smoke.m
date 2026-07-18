function test_log_helpers_smoke()
%TEST_LOG_HELPERS_SMOKE  src/util/ log helper smoke test
%
%   addpath("src/util"); addpath("test/smoke");
%   test_log_helpers_smoke();

addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src', 'util'));

%% 1) log_info — must contain timestamp + [INFO]
out = evalc('log_info("hello %s", "world")');
assert(contains(out, "[INFO]"), "log_info: [INFO] が含まれていない");
assert(contains(out, "hello world"), "log_info: メッセージが含まれていない");
assert(~isempty(regexp(out, '^\[\d{2}:\d{2}:\d{2}\]', 'once')), "log_info: タイムスタンプ形式不正");

%% 2) log_warn — must contain [WARN]
out = evalc('log_warn("test warning %d", 42)');
assert(contains(out, "[WARN]"), "log_warn: [WARN] が含まれていない");
assert(contains(out, "test warning 42"), "log_warn: メッセージが含まれていない");

%% 3) log_error — must contain [ERROR]
out = evalc('log_error("fail: %s", "timeout")');
assert(contains(out, "[ERROR]"), "log_error: [ERROR] が含まれていない");
assert(contains(out, "fail: timeout"), "log_error: メッセージが含まれていない");

%% 4) log_info with no varargin
out = evalc('log_info("no args")');
assert(contains(out, "no args"), "log_info: varargin なしで動作しない");

%% 5) log_progress — mid-progress (no newline, \r overwrite)
out = evalc('log_progress(3, 10, "items")');
assert(contains(out, "[###-------]"), "log_progress: バー表示が不正 (3/10)");
assert(contains(out, "30%"), "log_progress: パーセンテージ不正");
assert(contains(out, "items"), "log_progress: ラベルが含まれていない");
% Mid-progress has no newline (starts with \r)
assert(~endsWith(strtrim(out), newline), "log_progress: 中間で改行が出力されている");

%% 6) log_progress — newline present on completion
out = evalc('log_progress(10, 10, "done")');
assert(contains(out, "[##########]"), "log_progress: 完了バー不正");
assert(contains(out, "100%"), "log_progress: 100% 不正");
assert(endsWith(out, newline), "log_progress: 完了時に改行がない");

%% 7) log_progress — width alignment (i=1, n=100)
out = evalc('log_progress(1, 100, "rows")');
assert(contains(out, "(  1/100)"), "log_progress: 幅揃え不正 (1/100)");

%% 8) log_progress — minimal case (1/1)
out = evalc('log_progress(1, 1, "single")');
assert(contains(out, "100%"), "log_progress: 1/1 で100%にならない");
assert(endsWith(out, newline), "log_progress: 1/1 で改行がない");

fprintf("test_log_helpers_smoke: ALL PASSED\n");
end
