function cfg = load_repro_signals_config(configPath, opts)
%LOAD_REPRO_SIGNALS_CONFIG Load repro signal dictionaries from config and env.
%
% Priority: environment variables > config/repro_signals.json > defaults

arguments
    configPath (1,1) string = ""
    opts.envPrefix (1,1) string = "ANYRESEARCH_REPRO_SIGNALS_"
end

cfg = local_default_config();

resolvedPath = configPath;
if resolvedPath == ""
    candidates = ["config/repro_signals.json", "../../config/repro_signals.json", "../../../config/repro_signals.json"];
    for ci = 1:numel(candidates)
        if isfile(candidates(ci))
            resolvedPath = candidates(ci);
            break;
        end
    end
end

if resolvedPath ~= "" && isfile(resolvedPath)
    raw = jsondecode(fileread(resolvedPath));
    cfg = local_merge_config(cfg, raw);
end

cfg = local_apply_env(cfg, opts.envPrefix);
cfg = local_normalize_config(cfg);
end

function cfg = local_default_config()
cfg = struct();
cfg.mentions_dataset = ["ESOL", "BBBP", "MoleculeNet", "FreeSolv", "Lipophilicity", "Tox21", "ClinTox", "QM9"];
cfg.mentions_code = ["github.com", "code available", "open source", "publicly available"];
cfg.mentions_library = ["RDKit", "scikit-learn", "PyTorch", "DeepChem", "TensorFlow", "MATLAB"];
cfg.mentions_metrics = ["RMSE", "ROC-AUC", "MAE", "cross-validation"];
cfg.matlab_terms = ["MATLAB"];
end

function cfg = local_merge_config(baseCfg, rawCfg)
cfg = baseCfg;
fields = string(fieldnames(baseCfg));
for i = 1:numel(fields)
    key = fields(i);
    if isfield(rawCfg, key)
        cfg.(key) = rawCfg.(key);
    end
end
end

function cfg = local_apply_env(cfg, prefix)
fields = string(fieldnames(cfg));
for i = 1:numel(fields)
    fieldName = fields(i);
    envName = upper(prefix + fieldName);
    envName = regexprep(envName, "[^A-Z0-9_]", "_");
    raw = getenv(envName);
    if strlength(string(raw)) == 0
        continue;
    end
    cfg.(fieldName) = strtrim(split(string(raw), ","));
end
end

function cfg = local_normalize_config(cfg)
fields = string(fieldnames(cfg));
for i = 1:numel(fields)
    key = fields(i);
    vals = string(cfg.(key));
    vals(ismissing(vals)) = "";
    vals = strtrim(vals);
    vals = vals(strlength(vals) > 0);
    cfg.(key) = vals(:);
end
end
