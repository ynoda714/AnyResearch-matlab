function log_warn(msg, varargin)
%LOG_WARN  Prints a warning-level log message: [HH:MM:SS][WARN] msg
    if ~isempty(varargin)
        msg = sprintf(msg, varargin{:});
    end
    ts = datestr(now, 'HH:MM:SS');
    fprintf("[%s][WARN] %s\n", ts, msg);
end
