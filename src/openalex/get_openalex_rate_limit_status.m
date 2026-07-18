function info = get_openalex_rate_limit_status(apiKey, timeoutSec)
%GET_OPENALEX_RATE_LIMIT_STATUS  Fetches current OpenAlex rate-limit status.
%
%   info = get_openalex_rate_limit_status()
%   info = get_openalex_rate_limit_status(apiKey)
%   info = get_openalex_rate_limit_status(apiKey, timeoutSec)
%
%   Returns a struct with:
%     .ok
%     .can_query
%     .api_key_present
%     .credits_remaining
%     .credits_used
%     .credits_limit
%     .daily_remaining_usd
%     .daily_used_usd
%     .daily_budget_usd
%     .resets_in_seconds
%     .resets_at
%     .message
%     .error_message

arguments
    apiKey (1,1) string = ""
    timeoutSec (1,1) double {mustBePositive(timeoutSec)} = 10
end

info = struct();
info.ok = false;
info.can_query = false;
info.api_key_present = false;
info.credits_remaining = NaN;
info.credits_used = NaN;
info.credits_limit = NaN;
info.daily_remaining_usd = NaN;
info.daily_used_usd = NaN;
info.daily_budget_usd = NaN;
info.resets_in_seconds = NaN;
info.resets_at = "";
info.message = "";
info.error_message = "";

apiKey = strtrim(string(apiKey));
if apiKey == ""
    apiKey = local_load_api_key_from_settings();
end
if apiKey == ""
    info.error_message = "OpenAlex API key is not configured.";
    return;
end

info.api_key_present = true;

url = "https://api.openalex.org/rate-limit?api_key=" + string(urlencode(char(apiKey)));

try
    resp = webread(char(url), weboptions("Timeout", timeoutSec));
catch ex
    info.error_message = string(ex.message);
    return;
end

info.ok = true;
if isfield(resp, "rate_limit")
    rl = resp.rate_limit;
    info.credits_remaining = local_get_numeric_field(rl, "credits_remaining");
    info.credits_used = local_get_numeric_field(rl, "credits_used");
    info.credits_limit = local_get_numeric_field(rl, "credits_limit");
    info.daily_remaining_usd = local_get_numeric_field(rl, "daily_remaining_usd");
    info.daily_used_usd = local_get_numeric_field(rl, "daily_used_usd");
    info.daily_budget_usd = local_get_numeric_field(rl, "daily_budget_usd");
    info.resets_in_seconds = local_get_numeric_field(rl, "resets_in_seconds");
    if isfield(rl, "resets_at") && ~isempty(rl.resets_at)
        info.resets_at = string(rl.resets_at);
    end
end

hasCredits = isnan(info.credits_remaining) || info.credits_remaining > 0;
hasBudget = isnan(info.daily_remaining_usd) || info.daily_remaining_usd > 0;
info.can_query = hasCredits && hasBudget;

if info.can_query
    info.message = "Rate limit budget available.";
else
    info.message = "Rate limit budget is exhausted.";
end
end

function apiKey = local_load_api_key_from_settings()
apiKey = strtrim(string(getenv("ANYRESEARCH_OPENALEX_API_KEY")));
if apiKey ~= ""
    return;
end

thisDir = fileparts(mfilename("fullpath"));
projectRoot = fileparts(fileparts(thisDir));
settingsPath = fullfile(projectRoot, "config", "settings.json");
if ~isfile(settingsPath)
    apiKey = "";
    return;
end

try
    raw = jsondecode(fileread(settingsPath));
    if isfield(raw, "openalex") && isfield(raw.openalex, "api_key")
        apiKey = strtrim(string(raw.openalex.api_key));
    else
        apiKey = "";
    end
catch
    apiKey = "";
end
end

function val = local_get_numeric_field(s, fieldName)
val = NaN;
if ~isstruct(s) || ~isfield(s, fieldName) || isempty(s.(fieldName))
    return;
end
raw = s.(fieldName);
if isnumeric(raw) || islogical(raw)
    val = double(raw);
    return;
end
parsed = str2double(string(raw));
if ~isnan(parsed)
    val = parsed;
end
end
