function text = clean_text(text)
%CLEAN_TEXT Normalize whitespace for example text processing.

text = string(text);
text(ismissing(text)) = "";

for i = 1:numel(text)
    s = char(text(i));
    s = regexprep(s, '\s+', ' ');
    s = strtrim(s);
    text(i) = string(s);
end
end
