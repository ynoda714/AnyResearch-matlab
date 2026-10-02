function tf = match_search_expression(expr, bodyText)
%MATCH_SEARCH_EXPRESSION  True when BODYTEXT satisfies a parsed Query expression.
%
%   TF = MATCH_SEARCH_EXPRESSION(EXPR, BODYTEXT)
%
%   EXPR comes from PARSE_SEARCH_EXPRESSION. Matching is case-insensitive and
%   whitespace-insensitive (line breaks inside a phrase are ignored). AND means
%   "somewhere in the same body", not "on the same line". An empty expression
%   never matches.
arguments
    expr (1,1) struct
    bodyText (1,1) string
end

body = regexprep(bodyText, '\s+', ' ');
tf = local_eval(expr.tree, body);
end

function tf = local_eval(node, body)
switch node.type
    case "empty"
        tf = false;
    case "term"
        tf = contains(body, node.value, 'IgnoreCase', true);
    case "group"
        tf = local_eval(node.child, body);
    case "and"
        tf = true;
        for k = 1:numel(node.children)
            tf = tf && local_eval(node.children{k}, body);
            if ~tf, return; end
        end
    case "or"
        tf = false;
        for k = 1:numel(node.children)
            tf = tf || local_eval(node.children{k}, body);
            if tf, return; end
        end
end
end
