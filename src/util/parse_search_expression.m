function expr = parse_search_expression(text)
%PARSE_SEARCH_EXPRESSION  Parse the shared Query grammar (ADR-004).
%
%   EXPR = PARSE_SEARCH_EXPRESSION(TEXT)
%
%   Grammar: space = AND, "|" = OR, "..." = phrase, ( ) = grouping.
%   Uppercase AND / OR are accepted as synonyms; lowercase words are ordinary terms.
%   AND and OR may not be mixed at the same level without parentheses.
%
%   EXPR fields:
%     openalex  OpenAlex search string ("|" rewritten to " OR ")
%     terms     column string array of all words and phrases, in order
%     tree      parsed expression (used by MATCH_SEARCH_EXPRESSION)
%
%   An empty or blank TEXT returns an empty expression (seed-only searches).
%   Invalid input throws an error with identifier parse_search_expression:<Reason>.
arguments
    text (1,1) string
end

text = replace(text, "\|", "|");   % legacy escaped pipe
tokens = local_tokenize(char(text));

if isempty(tokens)
    expr = struct('openalex', "", 'terms', strings(0, 1), 'tree', struct('type', "empty"));
    return;
end

[tree, pos] = local_parse_group(tokens, 1, 0);
if pos <= numel(tokens)
    error("parse_search_expression:UnbalancedParentheses", "Unbalanced parentheses in the query.");
end

expr = struct('openalex', local_render(tree), 'terms', local_collect_terms(tree), 'tree', tree);
end

function tokens = local_tokenize(s)
tokens = struct('type', {}, 'text', {});
n = numel(s);
i = 1;
while i <= n
    c = s(i);
    if isspace(c)
        i = i + 1;
    elseif c == '('
        tokens(end+1) = struct('type', "LPAREN", 'text', "("); %#ok<AGROW>
        i = i + 1;
    elseif c == ')'
        tokens(end+1) = struct('type', "RPAREN", 'text', ")"); %#ok<AGROW>
        i = i + 1;
    elseif c == '|'
        tokens(end+1) = struct('type', "OR", 'text', "|"); %#ok<AGROW>
        i = i + 1;
    elseif c == '"'
        close = find(s(i+1:end) == '"', 1);
        if isempty(close)
            error("parse_search_expression:UnterminatedPhrase", "A quoted phrase is missing its closing quote.");
        end
        phrase = strtrim(regexprep(s(i+1:i+close-1), '\s+', ' '));
        if isempty(phrase)
            error("parse_search_expression:EmptyOperand", "A quoted phrase is empty.");
        end
        tokens(end+1) = struct('type', "PHRASE", 'text', string(phrase)); %#ok<AGROW>
        i = i + close + 1;
    else
        j = i;
        while j <= n && ~isspace(s(j)) && ~any(s(j) == '()|"')
            j = j + 1;
        end
        word = string(s(i:j-1));
        if word == "AND"
            tokens(end+1) = struct('type', "AND", 'text', word); %#ok<AGROW>
        elseif word == "OR"
            tokens(end+1) = struct('type', "OR", 'text', word); %#ok<AGROW>
        else
            tokens(end+1) = struct('type', "WORD", 'text', word); %#ok<AGROW>
        end
        i = j;
    end
end
end

function [node, pos] = local_parse_group(tokens, pos, depth)
items = {};
ops = strings(0, 1);
expectOperand = true;
n = numel(tokens);
while pos <= n
    t = tokens(pos);
    if t.type == "RPAREN"
        if depth == 0
            error("parse_search_expression:UnbalancedParentheses", "Unbalanced parentheses in the query.");
        end
        break;
    elseif t.type == "AND" || t.type == "OR"
        if expectOperand
            error("parse_search_expression:EmptyOperand", "An operator is missing an operand.");
        end
        ops(end+1, 1) = t.type; %#ok<AGROW>
        expectOperand = true;
        pos = pos + 1;
    else
        if ~expectOperand
            ops(end+1, 1) = "IMPLICIT"; %#ok<AGROW>
        end
        if t.type == "LPAREN"
            [sub, pos] = local_parse_group(tokens, pos + 1, depth + 1);
            if pos > n || tokens(pos).type ~= "RPAREN"
                error("parse_search_expression:UnbalancedParentheses", "Unbalanced parentheses in the query.");
            end
            pos = pos + 1;
            item = struct('type', "group", 'child', sub);
        else
            item = struct('type', "term", 'value', t.text, 'isPhrase', t.type == "PHRASE");
            pos = pos + 1;
        end
        items{end+1} = item; %#ok<AGROW>
        expectOperand = false;
    end
end

if isempty(items) || expectOperand
    error("parse_search_expression:EmptyOperand", "An operator or parenthesis is missing an operand.");
end
hasOr = any(ops == "OR");
hasAnd = any(ops ~= "OR");
if hasOr && hasAnd
    error("parse_search_expression:MixedOperators", ...
        "Use parentheses to combine AND and OR, e.g. ""a (b | c)"".");
end
if isscalar(items)
    node = items{1};
elseif hasOr
    node = struct('type', "or", 'children', {items}, 'explicit', true);
else
    node = struct('type', "and", 'children', {items}, 'explicit', any(ops == "AND"));
end
end

function s = local_render(node)
switch node.type
    case "term"
        if node.isPhrase
            s = """" + node.value + """";
        else
            s = node.value;
        end
    case "group"
        s = "(" + local_render(node.child) + ")";
    case "and"
        sep = " ";
        if node.explicit
            sep = " AND ";
        end
        s = join(string(cellfun(@local_render, node.children, 'UniformOutput', false)), sep);
    case "or"
        s = join(string(cellfun(@local_render, node.children, 'UniformOutput', false)), " OR ");
end
end

function terms = local_collect_terms(node)
switch node.type
    case "term"
        terms = node.value;
    case "group"
        terms = local_collect_terms(node.child);
    otherwise
        terms = strings(0, 1);
        for k = 1:numel(node.children)
            terms = [terms; local_collect_terms(node.children{k})]; %#ok<AGROW>
        end
end
terms = terms(:);
end
