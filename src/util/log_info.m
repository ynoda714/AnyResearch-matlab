function log_info(msg, varargin)
%LOG_INFO  Prints an info-level log message: [HH:MM:SS][INFO] msg
    if ~isempty(varargin)
        msg = sprintf(msg, varargin{:});
    end
    ts = datestr(now, 'HH:MM:SS');
    fprintf("[%s][INFO] %s\n", ts, msg);
end
