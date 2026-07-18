function apiKey = load_openalex_api_key(settingsJsonPath, required)
%LOAD_OPENALEX_API_KEY  Loads OpenAlex API key from env or settings JSON.

arguments
    settingsJsonPath (1,1) string = ""
    required (1,1) logical = false
end

apiKey = "";
try
    cfg = load_runtime_config(settingsJsonPath);
    if isfield(cfg, "openalex") && isfield(cfg.openalex, "api_key")
        apiKey = strtrim(string(cfg.openalex.api_key));
    end
catch
    apiKey = "";
end

if required && apiKey == ""
    error("openalex:NoApiKey", ...
        "OpenAlex API key is not configured. Set config/settings.json openalex.api_key or ANYRESEARCH_OPENALEX_API_KEY.");
end
end
