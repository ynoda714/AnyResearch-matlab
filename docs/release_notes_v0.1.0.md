# Release Notes v0.1.0

- Release Date: 2026-03-30
- Branch: `v0.1.0`
- Previous: — (initial release)

> Japanese release notes: [../release_notes_v0.1.0.md](jp/release_notes_v0.1.0.md)

---

## Overview

v0.1.0 is the first public release of AnyResearch.
It delivers a complete Layer 0 pipeline — collecting academic papers via the OpenAlex API, transforming them into structured data, and exporting to Excel — along with separated front-end entry points, a unified pipeline orchestrator, a test suite, and Phase 6A UX enhancements.

This version is **fully self-contained at Layer 0** (the minimum configuration driven by `query=` alone) and requires only MATLAB and a free OpenAlex API Key — no additional licenses needed.

---

## What's New

### 1) Pipeline Integration & Front-end Separation (Phase 3–5)

- Introduced `src/pipeline/run_pipeline.m` as the single orchestration entry point
- `main_run_pipeline.m` (single search) and `main_run_batch.m` (multi-institution batch) are fully independent
  - Each file contains only parameter settings and a single `run_pipeline(...)` call
  - Completely self-contained — no shared variables between the two front-end files
- `src/pipeline/run_batch_from_institutions_list.m`: batch logic integrated into `run_pipeline` loop
- `src/pipeline/create_run_context.m`: run directory creation extracted into a function

### 2) Excel Output — 4-Sheet Structure (Phase 2)

- `src/export/export_excel_workbook.m`: entry point (JSONL → xlsx)
- Generates Overview / Detail / Summary / Config sheets
- Two-tier output: COM mode for rich formatting, `writecell` fallback for server/non-GUI environments
- `src/export/excel_apply_header_style.m`: reusable header style helper

### 3) Phase 6A: UX & API Enhancements

| # | Feature | Description |
|---|---|---|
| L0-1 | Sort order parameter `sortBy` | Supports `"cited_by_count:desc"` / `"publication_date:desc"` / `"relevance_score"` |
| L0-2 | Document type filter `filterType` | e.g. `"article"`, `"review"`, `"article,review"`. Multiple values via comma-separated list |
| L0-3 | Search syntax comments | AND (space) / OR (`\|`) / phrase (quotes) documented in the front-end `.m` files |
| R-1 | API retry | `fetch_openalex_works.m` retries up to 3 times on 429/503 with exponential backoff |
| D-1 | Use-case guide | quickstart expanded with persona-specific sections for literature review, institution comparison, and technology trend analysis |

### 4) API Authentication (Phase 1)

- Supports OpenAlex `api_key` authentication (query parameter method, required from 2026)
- Managed via `config/settings.json` or environment variable `ANYRESEARCH_OPENALEX_API_KEY`
- `src/config/load_runtime_config.m`: loads configuration with priority env var > JSON > default

### 5) Test Suite (Phase 3–6A)

20 smoke tests in `test/smoke/`, all passing.

**New tests (Phase 6A):**
- `test_phase6a_params_smoke.m` (7 cases): verifies presence of `sortBy` / `filterType` / retry function

**Quality improvements to existing tests:**

| File | Improvement |
|---|---|
| `test_extract_pdf_text_python.m` | Rewrote empty test into 3 cases (existence check, type check, sample execution) |
| `test_phase5_score_matrix_smoke.m` | Restructured 3 bare `assert` calls into 4 cases with `isfield` guards, messages, tmpdir, and `onCleanup` |
| `test_run_batch_smoke.m` | Added final `assert(passCount >= 5)` to prevent silent T1–T5 failures |
| `test_phase6a_params_smoke.m` | Added cases 6/7: E2E verification that `filterType` and `sortBy` are correctly written to the config JSON via `run_pipeline` |

---

## Key File Structure

```
main_run_pipeline.m        Single-search front end
main_run_batch.m           Batch-search front end
src/
  pipeline/
    run_pipeline.m         Pipeline orchestrator
    run_batch_from_institutions_list.m
    create_run_context.m
    fetch_and_normalize_works.m
  openalex/
    fetch_openalex_works.m  (sortBy / retry support)
  export/
    export_excel_workbook.m
    excel_write_{overview,detail,summary,config}.m
  config/
    load_runtime_config.m
  util/
    log_{info,warn,error,progress}.m
test/smoke/                20 smoke tests
config/settings.example.json
docs/quickstart.md
```

---

## Known Limitations

- **Excel COM write**: In `-batch` mode (non-GUI environments where `actxserver` is unavailable), the pipeline automatically switches to the `writecell` fallback
- **Layer 3 (PDF)**: When `enablePdfDownload=true`, a Python venv must be set up beforehand (see `src/python/requirements.txt`)

---

## Quick Start

```matlab
% 1. Set your API Key (first time only)
% Add your key to config/settings.json under openalex.api_key

% 2. Run a single search
main_run_pipeline   % Edit query / fromDate / toDate, then run
```

---

## Running Tests

```matlab
addpath(genpath('src')); addpath('test/smoke');
test_config_precedence_smoke();
test_pdf_validation_smoke();
test_excel_export_smoke();
test_pipeline_e2e_smoke();     % requires network
test_phase6a_params_smoke();
```

---

## Breaking Changes

None — this is the initial release.

---

## Migration Notes

- Migrating from a previous private prototype (v2 series): set `openalex.api_key` in `config/settings.json`
- For batch execution, always use `main_run_batch.m` (`main_run_pipeline.m` does not support batch mode)
