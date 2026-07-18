function log_progress(i, n, label)
%LOG_PROGRESS  Displays a pip/tqdm-style progress bar.
%   log_progress(i, n, label) overwrites the current line with \r.
%   Outputs a newline when i == n. Bar width is fixed at 10 characters.
%
%   Example: [####------]  40% ( 4/11) institutions
    pct = floor(i / n * 100);
    filled = round(i / n * 10);
    bar = [repmat('#', 1, filled), repmat('-', 1, 10 - filled)];
    nWidth = strlength(string(n));
    iStr = sprintf('%*d', nWidth, i);
    if i < n
        fprintf('\r[%s] %3d%% (%s/%d) %s', bar, pct, iStr, n, label);
    else
        fprintf('\r[%s] %3d%% (%s/%d) %s\n', bar, pct, iStr, n, label);
    end
end
