# Changelog

All notable changes to this project are documented in this file.

This changelog is the high-level release-oriented record.  
Detailed implementation notes, bug histories, and phase-by-phase development logs remain in the private development repository.

The format is loosely based on Keep a Changelog.

## [Unreleased]

## [1.5.0] - 2026-07-18

### Added
- Cross-run candidate ledger: collect, deduplicate, and track papers across runs
  - `src/util/append_to_candidates.m` — merges a run (or table) into the ledger,
    deduplicating on `doi_normalized`, falling back to `openalex_id`
  - `src/util/update_candidates_ledger.m` — updates `status` / `note` for selected rows
  - `src/export/export_candidates_xlsx.m` — spreadsheet view of the ledger
  - `src/export/export_candidates_md.m` — Markdown table of `status="reviewed"` rows
  - `test/smoke/test_candidates_ledger_smoke.m`
- `appendToCandidates` option in `main_run_pipeline.m` and `main_run_batch.m`
- `ledgerPath` option in `main_run_batch.m`, so a batch can accumulate into a
  dedicated ledger file instead of the default one
- DOI and OpenAlex ID normalization so that DOI URLs, `doi:` prefixes, plain DOIs,
  and short/URL forms of OpenAlex IDs all resolve to the same ledger row

### Changed
- The ledger append engine is schema-agnostic: any column already present on a
  matched row is preserved across re-appends, and only overwritten when the
  incoming row supplies a non-empty value. Adding your own review columns to the
  ledger is therefore safe — a later run will not erase them.
- Documentation layout: English is now the source of truth and lives at the
  default path (`README.md`, `docs/quickstart.md`, `docs/reference.md`,
  `docs/workflows/`), with Japanese mirroring the same tree under `docs/jp/`.
  This replaces the previous `docs/en/` directory and `.ja.md` suffix scheme.
- `docs/workflows/repro_discovery.md` now describes the candidate-ledger workflow

### Removed
- Legacy pipeline code, helper scripts, and ad-hoc development files that were
  never part of the intended public surface

### Docs
- Standardized changelog tracking in `CHANGELOG.md`
- Added Japanese support page at `docs/jp/CHANGELOG.md`
- Added function/test reference docs in `docs/reference.md` and `docs/jp/reference.md`
- Audited and corrected key markdown links across README, quickstart, and workflow docs

## [1.4.0] - 2026-07-17

### Added
- Server-side `citedByMin` / `citedByMax` filtering for OpenAlex queries
- `fwci` and `citation_percentile` surfaced in Overview output
- Reproducibility signal detection:
  - `mentions_dataset`
  - `mentions_code`
  - `mentions_library`
  - `mentions_metrics`
  - `repro_signal_score`
- Configurable repro signal dictionaries via `config/repro_signals.example.json`
- One-hop snowball retrieval from a seed DOI or OpenAlex Work ID:
  - `fetch_citing_works.m`
  - `fetch_referenced_works.m`
  - `seedId` / `snowballMode` support in `run_pipeline`
- OpenAlex rate-limit inspection helper:
  - `src/openalex/get_openalex_rate_limit_status.m`

### Changed
- `citation_velocity.m` now prefers measured `counts_by_year` values over age-based approximation
- Network smoke tests now degrade to `SKIP` / `WARN` more consistently under OpenAlex `429` / `503`
- EasyMolKit reproduction-discovery workflow updated to use `fwci` and `repro_signal_score`

### Fixed
- Retry behavior for OpenAlex requests now uses better 429-aware waiting logic
- Pipeline OpenAlex requests now propagate the API key more consistently through generated settings

## [1.3.0] - 2026-07-07

### Added
- Table-first pipeline return value via `run_pipeline(...).T`
- `search_results.mat`
- `load_run.m`
- `load_latest_run.m`
- Raw OpenAlex page capture under `runDir/raw/`

### Changed
- Refactored the data path from CSV relay to in-memory MATLAB tables
- JSONL became the canonical machine-readable master artifact
- CSV and XLSX became derived views rather than the internal source of truth

## [1.2.1] - 2026-07-17

### Fixed
- Correct OR query semantics for OpenAlex search
- Default exclusion of retracted papers
- Prevented reviewed institution IDs from being re-resolved at batch runtime
- Repaired Excel COM write path and added regression coverage

## [1.2.0] - 2026-06-21

### Added
- EasyMolKit integration workflow docs
- Cheminformatics discovery examples in quickstart and README
- Cross-repository workflow guidance for RP candidate discovery

## [1.1.1] - 2026-04-03

### Fixed
- `maxRowsForValidation` default corrected to unlimited
- PDF downstream steps now skip correctly when PDF download is disabled
- Zero-result queries now produce empty outputs gracefully
- Escaped OR query handling corrected for OpenAlex requests

## [1.1.0] - 2026-04

### Added
- arXiv supplemental fetch and DOI-based deduplication
- `source_dataset` support in merged outputs
- `test_arxiv_smoke.m`

## [1.0.0] - 2026-04

### Added
- Analytics layer:
  - citation velocity
  - topic growth rate
  - institution dominance
- Summary and batch comparison output expansion
- Public-repository preparation docs and cleanup

## [0.1.0] - 2026-03

### Added
- Front-end split into `main_run_pipeline.m` and `main_run_batch.m`
- Central orchestration via `src/pipeline/run_pipeline.m`
- Excel export module split by sheet responsibility
- Smoke test suite consolidation
- Logging helpers and unified `run_meta.json`
