function ctx = create_run_context(runRootDir)
arguments
    runRootDir (1,1) string = "result/runs"
end

runId = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
runDir = string(fullfile(runRootDir, runId));

ctx = struct();
ctx.run_id = runId;
ctx.run_dir = runDir;
ctx.raw_dir = string(fullfile(runDir, 'raw'));
ctx.intermediate_dir = string(fullfile(runDir, 'intermediate'));
ctx.phase5_dir = string(fullfile(runDir, 'phase5'));
ctx.logs_dir = string(fullfile(runDir, 'logs'));
ctx.pdf_cache_dir = string(fullfile(runDir, 'pdf_cache'));
ctx.pdf_auto_dir = string(fullfile(ctx.pdf_cache_dir, 'auto'));
ctx.pdf_manual_dir = string(fullfile(ctx.pdf_cache_dir, 'manual'));

ctx.openalex_raw_csv = string(fullfile(ctx.raw_dir, 'openalex_raw.csv'));
ctx.openalex_raw_jsonl = string(fullfile(ctx.raw_dir, 'openalex_raw.jsonl'));
ctx.arxiv_raw_xml = string(fullfile(ctx.raw_dir, 'arxiv_response.xml'));
ctx.normalized_works_csv = string(fullfile(ctx.intermediate_dir, char("scoring" + "_input.csv")));
ctx.normalized_works_jsonl = string(fullfile(ctx.intermediate_dir, char("scoring" + "_input.jsonl")));
ctx.normalized_works_supplemented_csv = string(fullfile(ctx.intermediate_dir, char("scoring" + "_input_supplemented.csv")));
ctx.final_integrated_csv = string(fullfile(ctx.intermediate_dir, 'final_integrated_with_summary.csv'));
ctx.phase5_csv = string(fullfile(ctx.phase5_dir, 'phase5_v2_score_matrix.csv'));
ctx.phase5_summary_csv = string(fullfile(ctx.phase5_dir, 'phase5_v2_score_matrix_summary.csv'));
ctx.phase5_violations_csv = string(fullfile(ctx.phase5_dir, 'phase5_v2_score_matrix_violations.csv'));
ctx.run_meta_json = string(fullfile(ctx.logs_dir, 'run_meta.json'));
ctx.search_results_mat = string(fullfile(ctx.run_dir, 'search_results.mat'));

% P2-6: Unified artifacts (search_results.*) — placed directly under run_dir
ctx.search_results_xlsx  = string(fullfile(ctx.run_dir, 'search_results.xlsx'));
ctx.search_results_jsonl = string(fullfile(ctx.run_dir, 'search_results.jsonl'));
ctx.search_results_csv   = string(fullfile(ctx.run_dir, 'search_results.csv'));

local_mkdir(ctx.raw_dir);
local_mkdir(ctx.intermediate_dir);
local_mkdir(ctx.phase5_dir);
local_mkdir(ctx.logs_dir);
local_mkdir(ctx.pdf_auto_dir);
local_mkdir(ctx.pdf_manual_dir);
end

function local_mkdir(path)
if ~isfolder(path)
    mkdir(path);
end
end
