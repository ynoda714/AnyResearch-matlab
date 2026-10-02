function test_mask_api_key_smoke()
%TEST_MASK_API_KEY_SMOKE  mask_api_key removes api_key values from URLs / error text.
%
%   addpath("src/util"); addpath("test/smoke"); test_mask_api_key_smoke();

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', '..', 'src', 'util'));

secret = "SECRETKEY123";

% Case 1: key in the middle of a query string
out = mask_api_key("URL https://x/works?a=1&api_key=" + secret + "&b=2 failed");
assert(~contains(out, secret), 'Case1: key must be removed');
assert(contains(out, "api_key=***&b=2"), 'Case1: surrounding query must be preserved: %s', out);

% Case 2: key at the end of the URL followed by text
out = mask_api_key("https://x/works?api_key=" + secret + " returned 400");
assert(~contains(out, secret) && contains(out, "returned 400"), 'Case2: %s', out);

% Case 3: text without a key is unchanged
msg = "no key here, sort=relevance_score:desc";
assert(mask_api_key(msg) == msg, 'Case3: unrelated text must be unchanged');

% Case 4: empty string
assert(mask_api_key("") == "", 'Case4: empty string');

fprintf("[PASS] test_mask_api_key_smoke: 4 cases\n");
end
