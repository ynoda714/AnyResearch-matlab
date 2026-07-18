# Release Notes v1.0.0

- Release Date: 2026-04-03
- Branch: `master`
- Previous: v0.1.0 (2026-03-30)

> Japanese release notes: [../release_notes_v1.0.0.md](jp/release_notes_v1.0.0.md)

---

## Overview

v1.0.0 is the first stable major release of AnyResearch.
It strengthens the quality and reliability of the Layer 0 core, adds an Analytics layer (Layer 2) and arXiv integration, and ships a full set of bug fixes and documentation improvements.

---

## New Features

### Layer 2: Analytics (auto-integrated)

Analytics metrics are automatically appended to the Summary sheet and `batch_comparison.xlsx` — no additional configuration required.

| Metric | Description |
|---|---|
| `avg_citation_velocity` | Average annual citations per paper (proxy for attention) |
| `growth_rate_pct` | Annual publication count growth rate (%) |
| `institution_dominance` | Combined paper-share × citation-share score (batch mode) |

> **Note**: These are lightweight proxy metrics based on OpenAlex data. Final interpretation is always left to the user.

### arXiv Integration (`useArxiv=true`)

Retrieve preprints from arXiv in parallel with OpenAlex, capturing papers not yet indexed.

```matlab
useArxiv = true;   % Fetch preprints from arXiv in addition to OpenAlex (default: false)
```

- `source_dataset` column identifies OpenAlex vs. arXiv origin
- DOI-based deduplication against OpenAlex results
- When `filterType = "article"`, arXiv `"preprint"` entries are excluded

### Institution Filter Enhancement (Layer 0)

Specifying the OpenAlex institution ID in `firstAuthorInstitutionId` enables precise filtering at the API level.

```matlab
firstAuthorInstitution   = "The University of Tokyo";   % Name-only also works
firstAuthorInstitutionId = "I26973366";                  % ID is recommended for accuracy
```

Use `lookup_institution_id("institution name")` to look up the ID. If multiple ID candidates are returned for one institution name, check `works_count` to identify the primary entity.

### Extended Batch Comparison

`batch_comparison.xlsx` now includes Analytics metrics, enabling cross-institution comparison of citation velocity, growth rate, and dominance scores.

---

## Bug Fixes

| # | Symptom | Fix |
|---|---|---|
| ① | Only 10 results returned despite 286 hits | Changed `maxRowsForValidation` default from 10 → 0 (unlimited) |
| ② | `pdf_text_extraction: error` logged even when `enablePdfDownload=false` | Fixed PDF flag propagation logic (now records `skipped`) |
| ③ | OR query `"solar\|wind"` not working correctly | Fixed pipe character escaping in `fetch_openalex_works.m` |
| ④ | Error exit on zero-result query | Gracefully handle empty results; generates empty xlsx and JSONL |

---

## Other Improvements

- **MATLAB Online badge** added to README — click to run instantly
- **EN/JA README cross-links** added (`README.md` ↔ `README.ja.md`)
- **Expanded test suite**: 26 smoke tests covering arXiv integration, Analytics, new columns, and more
- **Documentation consistency**: Fixed Layer label typos and removed references to non-existent directories
- **Legacy code removal**: Removed old scoring pipeline (`src/scoring/`) and YAML config file

---

## Upgrade Guide (v0.1.0 → v1.0.0)

**No breaking changes.** Existing parameter settings in `main_run_pipeline.m` / `main_run_batch.m` continue to work as-is.

To use the new arXiv integration, add the following to Section 0 of `main_run_pipeline.m`:

```matlab
useArxiv = false;   % Set to true to also fetch arXiv preprints
```

---

## Requirements (unchanged)

| Item | Layer | Required |
|---|---|---|
| MATLAB R2025b or later | 0 | Required |
| OpenAlex API Key (free) | 0 | Required |
| institutions.csv | 1 | Optional |
| Text Analytics Toolbox | 3 | Optional |
| Python 3.11 + venv | 3 | Optional |
