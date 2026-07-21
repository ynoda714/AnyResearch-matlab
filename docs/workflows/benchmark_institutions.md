# Benchmark Institutions Workflow

&nbsp; [日本語](../jp/workflows/benchmark_institutions.md)

> Updated: 2026-07-17

## Purpose

This document describes the current multi-institution benchmarking workflow around `main_run_batch.m`, including CSV generation, manual review, validation, and execution.

## Relevant functions

- `src/openalex/prepare_institutions_csv.m`
- `src/openalex/load_institutions_list.m`
- `src/openalex/merge_institutions_review_table.m`
- `src/pipeline/run_batch_from_institutions_list.m`

## Accepted `institutions.csv` formats

A ready-to-copy sample with fictional placeholder institutions lives at
[`data/sample/institutions_sample.csv`](../../data/sample/institutions_sample.csv).
Replace the placeholders with your own targets and save it as `data/list/institutions.csv`.

### 1. Legacy 2-column format

Supported for backward compatibility.

```csv
Account,openalex_institution_id
Example Research University,I1234567890
Example Medical University,I100000001
Example Medical University,I100000002
```

### 2. Reviewed v2 format

Recommended going forward because it preserves manual review decisions as data.

```csv
account,openalex_institution_id,display_name,country_code,works_count,include,role,note,status
Example Medical University,I100000001,Example Medical University,JP,12345,1,main,,found
Example Medical University,I100000002,Example Medical University Hospital,JP,6789,1,hospital,,found
Example Medical University,I9999999999,Old Candidate,JP,50,0,other,excluded after review,found
```

Column meanings:
- `account`: target name. Multiple rows with the same `account` are grouped into one target
- `openalex_institution_id`: OpenAlex institution ID, `I` + digits
- `display_name`: OpenAlex display name for manual review
- `country_code`: country code for disambiguation
- `works_count`: OpenAlex paper count for manual review
- `include`: accepts `1/0`, `true/false`, `yes/no`. Only `1` rows are executed
- `role`: memo for why multiple IDs are included, such as `main`, `hospital`, `branch`, `other`
- `note`: free-form human note, not used during execution
- `status`: `found` / `not_found` / `api_error` audit status from candidate generation

## Candidate CSV generation

### Fresh generation

```matlab
prepare_institutions_csv(["Example Research University", "Example Technical University", "Example Metropolitan University"], ...
    countryFilter="JP", maxCandidates=3)
```

- The default output is `data/list/institutions_candidate.csv`
- The output already uses the reviewed v2 schema directly
- Only the top-ranked candidate per account gets an initial `include=1` proposal
- Candidates whose `display_name` contains `Hospital` or `病院` get a proposed `role="hospital"`
- `not_found` / `api_error` cases remain as blank-ID audit rows

### Refresh while preserving prior review

```matlab
prepare_institutions_csv(["Example Research University", "Example Technical University"], ...
    countryFilter="JP", ...
    mergeWith="data/list/institutions.csv")
```

With `mergeWith`:
- matching `account` × `openalex_institution_id` rows preserve `include` / `role` / `note`
- API-derived fields are refreshed from the latest OpenAlex result
- new IDs under an existing account are appended with `include=0` and note `new candidate since <date>`
- IDs that disappear from the API result are kept and annotated with `not returned by API on <date>`

## Review step

Open the candidate CSV and review at least:

- set `include=1` for candidates to keep, `0` for candidates to skip
- record why multiple IDs are retained in `role` if helpful
- record rationale or pending questions in `note`

No column renaming is required. The file can be used directly as `institutions.csv`.

## Input validation

Before execution, `load_institutions_list.m` validates:

- required columns: `Account/account`, `openalex_institution_id`
- ID format: `^I\d+$`
- `include` values: `1/0`, `true/false`, `yes/no`, numeric strings
- duplicate IDs across accounts: warning
- duplicate IDs inside the same account: deduplicated automatically
- accounts with zero `include=1` rows: warning and skip

To validate a reviewed CSV before running the batch:

```matlab
load_institutions_list("data/list/institutions.csv")
```

## Current execution behavior

- `run_batch_from_institutions_list` calls `load_institutions_list` internally
- all `include=1` rows with the same `account` are grouped into one target
- the target's IDs are joined as `I1|I2|...` and passed to `run_pipeline`
- `resolveInstitutionIds=false` is forced so that reviewed IDs in the CSV are not re-resolved at run time
- `batch_summary.csv.openalex_institution_id` stores joined IDs such as `I100000001|I100000002`
- `result/batch/<timestamp>/runs/` now maps to one run per target, not one run per CSV row

## Tests

### Network-free

```matlab
addpath("test");
run_smoke_tests("offline")
```

- `test_load_institutions_list_smoke()`
- merge-preservation logic is covered by the offline cases in `test_prepare_institutions_csv_smoke()`

### Network-dependent

- `test_prepare_institutions_csv_smoke()`
  - reviewed v2 output columns
  - `include` proposal
  - `role="hospital"` proposal
  - `countryFilter` / `maxCandidates`
  - `mergeWith` roundtrip
- `test_run_batch_smoke()`
  - batch entry-point input validation
  - loading via `load_institutions_list`
  - `resolveInstitutionIds=false`
  - `|`-joined IDs for multi-ID targets
  - propagation into `run_meta.json`
