# Reference

This document summarizes the main user-facing functions, helper functions, and smoke tests that are actively referenced by the current workflows.

It is not intended to replace inline MATLAB docstrings.  
Its purpose is to make recent architecture changes discoverable from markdown documentation.

## Core Entry Points

### `main_run_pipeline.m`
- Single-search front end
- Holds user-editable parameters only
- Calls `run_pipeline(...)`

### `main_run_batch.m`
- Multi-institution batch front end
- Supports reviewed institution CSV execution
- Can prepare candidate CSVs via `prepareList=true`

### `src/pipeline/run_pipeline.m`
- Main pipeline orchestrator
- Handles:
  - OpenAlex fetch
  - optional arXiv merge
  - optional PDF processing
  - final table integration
  - JSONL / CSV / XLSX / MAT output
  - optional candidate-ledger append/update outputs
- Supports:
  - `citedByMin`, `citedByMax`
  - `seedId`, `snowballMode`
  - `useArxiv`
  - `saveRawResponses`
  - `appendToCandidates`

## Candidate Ledger Functions

### `src/util/append_to_candidates.m`
- Appends one run's final result set into `result/candidates/candidates.jsonl`
- Deduplicates by `doi_normalized`, or by `openalex_id` when DOI is missing
- Preserves human-maintained `status` and `note`
- Updates `last_seen_run_id` when an existing row is observed again

### `src/util/update_candidates_ledger.m`
- Updates `status` and/or `note` for selected ledger rows
- Accepts normalized DOI, DOI URL, `doi:...`, or OpenAlex ID selectors
- Validates allowed statuses:
  - `new`
  - `reviewed`
  - `rejected`
  - `registered_RPxx`

### `src/util/normalize_candidate_doi.m`
- Normalizes DOI-like strings for ledger matching
- Strips `https://doi.org/` or `doi:` prefixes and lowercases the DOI body

## OpenAlex Functions

### `src/openalex/fetch_openalex_works.m`
- Fetches OpenAlex works with filtering, sorting, pagination, and raw-response capture
- Returns a typed MATLAB table plus metadata
- Includes 429/503 retry behavior

### `src/openalex/get_openalex_rate_limit_status.m`
- Queries OpenAlex `/rate-limit`
- Used by network smoke tests and retry decisions
- Reports whether enough budget remains to continue safely

### `src/openalex/build_openalex_filter.m`
- Builds server-side OpenAlex filter strings
- Includes support for:
  - language
  - open access
  - abstract requirement
  - retraction exclusion
  - institution IDs
  - `cited_by_count` min/max

### `src/openalex/fetch_citing_works.m`
- Resolves a seed DOI or OpenAlex Work ID
- Fetches works that cite the seed work

### `src/openalex/fetch_referenced_works.m`
- Resolves a seed DOI or OpenAlex Work ID
- Fetches one-hop referenced works from the seed work

### `src/openalex/prepare_institutions_csv.m`
- Generates reviewed-v2 institution candidate CSVs
- Supports merge-preserving refresh with `mergeWith`

### `src/openalex/load_institutions_list.m`
- Validates and groups institution CSV input
- Returns one row per target account, not one row per CSV line

## Adapter Functions

### `src/adapters/openalex_to_normalized_works.m`
- Converts OpenAlex raw rows into normalized AnyResearch works table
- Adds:
  - normalized DOI
  - dataset/library/code/metric signals
  - `repro_signal_score`

### `src/adapters/arxiv_to_normalized_works.m`
- Converts arXiv rows into the same normalized schema used for OpenAlex

### `src/adapters/detect_repro_signals.m`
- Dictionary-matches title + abstract
- Produces:
  - `mentions_dataset`
  - `mentions_code`
  - `mentions_library`
  - `mentions_metrics`
  - `repro_signal_score`
  - `matlab_mentioned`

## Analytics Functions

### `src/analytics/citation_velocity.m`
- Computes per-paper citation velocity
- Prefers `counts_by_year` measured values
- Falls back to age-based approximation when needed

### `src/analytics/topic_growth_rate.m`
- Aggregates paper counts by year
- Computes year-over-year growth

### `src/analytics/institution_dominance.m`
- Aggregates first-author institution share and citation share

### `src/analytics/compute_analytics.m`
- Unified analytics entry point for table / JSONL / CSV inputs

## Export Functions

### `src/export/excel_write_overview.m`
- Overview sheet builder
- Includes `fwci`, `citation_percentile`, and `repro_signal_score`

### `src/export/excel_write_detail.m`
- Detail sheet builder
- Includes repro-signal breakdown columns

### `src/export/export_excel_workbook.m`
- Top-level Excel export entry point

### `src/export/export_candidates_xlsx.m`
- Exports the candidate ledger to `candidates.xlsx`
- Reorders columns for practical filtering (`status`, `note`, `repro_signal_score`, `fwci`, etc.)
- Supports COM write with fallback mode

### `src/export/export_candidates_md.m`
- Exports `status="reviewed"` rows to EasyMolKit-ready Markdown
- Generates DOI links and initial Tier values from `repro_signal_score`

## Runtime Artifact Model

Current architecture is table-first internally:

1. API responses are normalized into typed MATLAB tables
2. The final in-memory result is returned as `run_pipeline(...).T`
3. `search_results.jsonl` is the machine-readable canonical artifact
4. `search_results.csv` and `search_results.xlsx` are derived views
5. `search_results.mat` preserves the MATLAB table directly

That means the project is no longer CSV-first internally, even though CSV remains part of the output set.

## Smoke Tests

### `test_phase6a_params_smoke.m`
- Search parameter handling
- retry implementation checks
- OR-search regression
- `citedByMin` / `citedByMax`

### `test_repro_signals_smoke.m`
- Default repro-signal dictionary
- Custom JSON override
- Adapter propagation

### `test_analytics_smoke.m`
- `citation_velocity`
- `topic_growth_rate`
- `institution_dominance`
- `compute_analytics`

### `test_snowball_smoke.m`
- `fetch_citing_works`
- `fetch_referenced_works`
- `run_pipeline` seed mode end-to-end

### `test_load_institutions_list_smoke.m`
- Legacy and reviewed-v2 institution CSV parsing
- invalid ID detection
- duplicate handling

### `test_run_batch_smoke.m`
- Batch input loading
- multi-ID grouping
- joined-ID propagation
- dry-run behavior

### `test_candidates_ledger_smoke.m`
- Candidate-ledger append deduplication
- Preservation of `status` / `note`
- Markdown / XLSX candidate export
- DOI / OpenAlex ID normalization
- `update_candidates_ledger` status validation

## Related Docs

- [Quick Start](quickstart.md)
- [Benchmark Institutions Workflow](workflows/benchmark_institutions.md)
- [Repro Discovery Workflow](workflows/repro_discovery.md)
- [Changelog](../CHANGELOG.md)
