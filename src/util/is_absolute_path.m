function tf = is_absolute_path(p)
%IS_ABSOLUTE_PATH  Returns true if the given path is absolute (works on Windows and Unix).
%
%   Usage:
%     tf = is_absolute_path("C:\foo\bar")  % => true
%     tf = is_absolute_path("result/runs") % => false

p = char(strtrim(string(p)));
if isempty(p)
    tf = false;
    return;
end
% Windows: C:\ or \\server  /  Unix: /
tf = (length(p) >= 2 && p(2) == ':') || p(1) == '/' || p(1) == '\';
end
