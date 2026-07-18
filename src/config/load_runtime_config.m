function cfg = load_runtime_config(settingsJsonPath, opts)
% LOAD_RUNTIME_CONFIG  Loads runtime configuration from a settings file (JSON) and environment variables.
%
% Priority: environment variables > config/settings.json > default values
%
% Arguments:
%   settingsJsonPath  (string) — Path to settings.json. Auto-detected if omitted.
%   opts.envPrefix    (string) — Environment variable prefix (default: "ANYRESEARCH_")
arguments
    settingsJsonPath (1,1) string = ""
    opts.envPrefix (1,1) string = "ANYRESEARCH_"
end

cfg = local_default_config();

% Load JSON settings file (auto-detect config/settings.json if path is not specified)
resolvedPath = settingsJsonPath;
if resolvedPath == ""
    candidates = ["config/settings.json", "../../config/settings.json", "../../../config/settings.json"];
    for ci = 1:numel(candidates)
        if isfile(candidates(ci))
            resolvedPath = candidates(ci);
            break;
        end
    end
end

if resolvedPath ~= "" && isfile(resolvedPath)
    cfg = local_merge(cfg, local_parse_json(resolvedPath));
end

cfg = local_apply_env(cfg, opts.envPrefix);
end

function cfg = local_default_config()
cfg = struct();
cfg.openalex = struct( ...
    'api_key',   "", ...
    'per_page',  100, ...
    'max_pages', 10, ...
    'filter',    "is_oa:true,has_abstract:true,language:en", ...
    'mailto',    "");
cfg.search = struct( ...
    'query',              "", ...
    'from_date',          "", ...
    'to_date',            "", ...
    'language',           "en", ...
    'require_open_access', true);
cfg.output = struct( ...
    'root_dir',      "result/runs", ...
    'excel_enabled', true, ...
    'csv_enabled',   true, ...
    'jsonl_enabled', true);
cfg.pdf = struct( ...
    'enable_download',          false, ...
    'max_rows',                 20, ...
    'timeout_sec',              60, ...
    'enable_text_extraction',   true, ...
    'enable_keyword_evidence',  true);
cfg.batch = struct( ...
    'root_dir',         "result/batch", ...
    'institutions_csv', "data/list/institutions.csv");
% Backward compatibility: legacy fields (scoring-related)
cfg.runtime = struct('eval_mode', "prod", 'text_only_mode', true);
cfg.input   = struct('openalex_csv', "");
cfg.scoring = struct('strict_validation', true, 'model_version', "v2-mvp", ...
    'model_mat_id', "", 'category_table_version', "", 'allow_mock_fallback', true);
end

function cfg = local_merge(baseCfg, overrideCfg)
cfg = baseCfg;
sections = string(fieldnames(overrideCfg));
for i = 1:numel(sections)
    sec = sections(i);
    if ~isfield(cfg, sec)
        cfg.(sec) = overrideCfg.(sec);
        continue;
    end
    keys = string(fieldnames(overrideCfg.(sec)));
    for k = 1:numel(keys)
        key = keys(k);
        cfg.(sec).(key) = overrideCfg.(sec).(key);
    end
end
end

function cfg = local_parse_json(path)
% Load a JSON file and convert it to a section struct.
% Works with MATLAB R2016b and later (requires jsondecode).
% Keys starting with "_" (comment keys) are ignored.
raw = jsondecode(fileread(path));
cfg = struct();
sectionNames = string(fieldnames(raw));
for i = 1:numel(sectionNames)
    sec = sectionNames(i);
    if startsWith(sec, "_")
        continue;  % Ignore meta-keys such as _comment, _priority
    end
    v = raw.(sec);
    if isstruct(v)
        subKeys = string(fieldnames(v));
        subStruct = struct();
        for k = 1:numel(subKeys)
            sk = subKeys(k);
            if startsWith(sk, "_")
                continue;
            end
            subStruct.(sk) = v.(sk);
        end
        cfg.(sec) = subStruct;
    else
        cfg.(sec) = v;
    end
end
end

function cfg = local_apply_env(cfg, prefix)
sectionNames = string(fieldnames(cfg));
for i = 1:numel(sectionNames)
    sec = sectionNames(i);
    keyNames = string(fieldnames(cfg.(sec)));
    for k = 1:numel(keyNames)
        key = keyNames(k);
        envName = upper(prefix + sec + "_" + key);
        envName = regexprep(envName, "[^A-Z0-9_]", "_");
        v = getenv(envName);
        if strlength(string(v)) == 0
            continue;
        end
        cfg.(sec).(key) = local_cast_value(string(v));
    end
end
end

function val = local_cast_value(raw)
text = strtrim(string(raw));
text = strip(text, 'both', '"');
text = strip(text, 'both', '''');

if any(strcmpi(text, ["true","false"]))
    val = strcmpi(text, "true");
    return;
end

num = str2double(text);
if ~isnan(num)
    val = num;
    return;
end

val = text;
end
