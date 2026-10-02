function out = mask_api_key(text)
%MASK_API_KEY  Replaces api_key query values in a string with "***".
%   Use before showing or logging text that may contain a request URL
%   (e.g. webread error messages), so the OpenAlex API key never leaks.
arguments
    text (1,1) string
end
out = regexprep(text, '(api_key=)[^&\s"''<>]+', '$1***');
end
