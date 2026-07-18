function spec = excel_write_config(T, cfg)
%EXCEL_WRITE_CONFIG  Build the data specification (spec) for the Config sheet
%
%   spec = excel_write_config(T, cfg)
%
%   T   — MATLAB table (used only to get the row count)
%   cfg — Runtime configuration struct
%
%   Return value spec:
%     .sheetName  (string)       — 'Config'
%     .headers    (cell 1×2)     — {'key', 'value'}
%     .data       (cell nRows×2) — Key-value rows
%     .hyperlinks (struct array) — Empty
%
%   Fields retrieved from cfg:
%     query / from_date / to_date / filter / run_id / run_dir /
%     rows_fetched / total_hits / created_at
%
%   Fields not present are output as '(not set)'.

arguments
    T   table
    cfg struct = struct()
end

headers    = {'key', 'value'};
hyperlinks = struct('row', {}, 'col', {}, 'url', {}, 'display', {});

rows = { ...
    'query',       local_cfg_str(cfg, 'query'); ...
    'from_date',   local_cfg_str(cfg, 'from_date'); ...
    'to_date',     local_cfg_str(cfg, 'to_date'); ...
    'filter',      local_cfg_str(cfg, 'filter'); ...
    'rows_fetched',local_cfg_num(cfg, 'rows_fetched', height(T)); ...
    'total_hits',  local_cfg_num(cfg, 'total_hits', ''); ...
    'run_id',      local_cfg_str(cfg, 'run_id'); ...
    'run_dir',     local_cfg_str(cfg, 'run_dir'); ...
    'created_at',  local_cfg_str(cfg, 'created_at'); ...
};

spec = struct();
spec.sheetName  = 'Config';
spec.headers    = headers;
spec.data       = rows;
spec.hyperlinks = hyperlinks;
spec.nCols      = 2;
end

% ─── Local helpers ───────────────────────────────────────────────────

function v = local_cfg_str(cfg, field)
% Retrieve a string field from the cfg struct (returns '(not set)' if absent)
if isfield(cfg, field)
    raw = cfg.(field);
    if isstring(raw) || ischar(raw)
        v = char(strtrim(string(raw)));
        if isempty(v)
            v = '(not set)';
        end
    else
        v = char(string(raw));
    end
else
    v = '(not set)';
end
end

function v = local_cfg_num(cfg, field, fallback)
% Retrieve a numeric field from the cfg struct (returns fallback if absent)
if isfield(cfg, field)
    raw = cfg.(field);
    if isnumeric(raw) && isscalar(raw) && ~isnan(raw)
        v = double(raw);
        return;
    end
    v = char(string(raw));
else
    if isnumeric(fallback) && isscalar(fallback) && ~isnan(fallback)
        v = double(fallback);
    elseif isempty(fallback)
        v = '(not set)';
    else
        v = char(string(fallback));
    end
end
end
