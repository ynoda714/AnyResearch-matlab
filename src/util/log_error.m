function log_error(msg, varargin)
%LOG_ERROR  Prints an error-level log message: [HH:MM:SS][ERROR] msg
    if ~isempty(varargin)
        msg = sprintf(msg, varargin{:});
    end
    ts = datestr(now, 'HH:MM:SS');
    fprintf("[%s][ERROR] %s\n", ts, msg);
end
