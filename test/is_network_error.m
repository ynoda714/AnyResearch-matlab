function tf = is_network_error(ex)
%IS_NETWORK_ERROR Return true when an exception indicates a transient network failure.
%
%   This includes MATLAB web service errors and OpenAlex rate-limit or
%   availability responses whose identifiers or messages vary by locale.

arguments
    ex (1,1) MException
end

identifier = string(ex.identifier);
message = lower(string(ex.message));

tf = contains(identifier, "webservices") || ...
     contains(message, "429") || ...
     contains(message, "503") || ...
     contains(message, "too many requests") || ...
     contains(message, "service unavailable") || ...
     contains(message, "timeout");
end
