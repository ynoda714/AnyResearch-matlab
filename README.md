# AnyResearch

[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=ynoda714/AnyResearch-matlab) &nbsp; [日本語](docs/jp/README.md)

AnyResearch is a MATLAB pipeline for keyword-based literature collection, research-trend review, and multi-institution benchmarking.  
It uses [OpenAlex](https://openalex.org/) and [arXiv](https://arxiv.org/) to fetch scholarly metadata and exports review-ready results to Excel.

> **Design philosophy**: Convert publicly available scholarly metadata into structured, decision-ready material.  
> The user performs the final interpretation; AnyResearch focuses on delivering clean inputs for literature review and institutional comparison.

## Typical Use Cases

| Scenario | Question | What to use |
|---|---|---|
| **Research theme selection** | Which topics are growing fastest? | Layer 0: keyword search + Summary |
| **Literature review** | Collect review articles in a target field | Layer 0: `filterType="review"` |
| **Competitive survey** | What are rival institutions publishing? | Layer 1: institution batch |
| **University IR / planning** | Compare your institution against benchmark universities | Layer 1 + Layer 2 |
| **Grant proposal support** | Add quantitative trend evidence | Layer 2: analytics |
| **EasyMolKit integration** | Find reproducible cheminformatics papers systematically | Layer 0: cheminformatics queries |

## Four-Layer Architecture

AnyResearch is designed as four incremental layers. **Layer 0 alone covers the primary use case.**

| Layer | Additional requirements | What you get |
|---|---|---|
| **Layer 0 (Core)** | MATLAB + OpenAlex API Key | Keyword search, Excel workbook (4 sheets), JSONL / CSV output |
| **Layer 1 (Batch)** | `institutions.csv` | Multi-institution processing and `batch_comparison.xlsx` |
| **Layer 2 (Analytics)** | none | Citation velocity, topic growth rate, and institution dominance integrated into outputs |
| **Layer 3 (PDF)** | Text Analytics Toolbox or Python | OA PDF download, text extraction, keyword evidence |

## Quick Start

### 1. Set an OpenAlex API Key

1. Create a free account at [openalex.org](https://openalex.org/)
2. Copy your API Key from [openalex.org/settings/api](https://openalex.org/settings/api)
3. Create `config/settings.json` based on `config/settings.example.json`

```json
{
  "openalex": {
    "api_key": "YOUR_API_KEY_HERE"
  }
}
```

### 2. Run a single keyword search

Edit Section 0 of `main_run_pipeline.m`:

```matlab
query      = "renewable energy forecasting";
fromDate   = "2023-01-01";
toDate     = "2025-12-31";
sortBy     = "cited_by_count:desc";
filterType = "";
```

Search syntax:
- AND: separate with spaces
- OR: use `|`
- Phrase: wrap in quotes

Run Section 0 and then Section 1 with **Run Section** (`Ctrl+Enter`).  
Outputs are saved under `result/runs/<YYYYMMDD_HHMMSS>/`.

### 3. Check outputs

```
result/runs/<YYYYMMDD_HHMMSS>/
  search_results.xlsx
  search_results.jsonl
  search_results.csv
  run_meta.json
```

## Excel Output

| Sheet | Contents |
|---|---|
| **Overview** | Title, DOI, publication year, citation count, OA flag, journal, abstract |
| **Detail** | Authors, affiliations, PDF status, topics, and other detailed fields |
| **Summary** | Yearly paper counts, average citations, citation velocity, growth rate |
| **Config** | Search conditions and run metadata |

## Optional Features

### Layer 1: Benchmark-Institution Batch Mode

Process multiple universities or organizations in one run and generate cross-institution comparisons.

**Step 1: Generate an institution candidate CSV**

```matlab
prepare_institutions_csv(["Nagoya University", "Kyoto University", "Osaka University"], ...
    countryFilter="JP", maxCandidates=3)
% -> Outputs reviewed-v2 candidates to data/list/institutions_candidate.csv
% -> Review include / role / note and use it as institutions.csv

lookup_institution_id("Nagoya University")
```

`institutions_candidate.csv` already uses the reviewed batch schema. No manual column renaming is required.  
After reviewing `include`, save or reuse it as `data/list/institutions.csv`.

**Step 2: Run the batch**

```matlab
main_run_batch
```

In `main_run_batch.m`:
- set `prepareList=true` to refresh the candidate CSV via Section 0.5
- set `dryRun=true` to preview filters and hit counts only
- run normally to write outputs under `result/batch/<YYYYMMDD_HHMMSS>/`

See also: [Benchmark Institutions Workflow](docs/workflows/benchmark_institutions.md)

### Layer 2: Analytics

Analytics are integrated automatically into Summary and `batch_comparison.xlsx`.

| Metric | Meaning |
|---|---|
| `avg_citation_velocity` | Average annual citation rate per paper |
| `growth_rate_pct` | Year-over-year paper-count growth |
| `institution_dominance` | Composite score based on paper share and citation share |

### Candidate Ledger (Phase L)

Candidate discovery can now be managed across runs instead of by one-off spreadsheet copies.

- `appendToCandidates=true` appends the final result table into `result/candidates/candidates.jsonl`
- `candidates.xlsx` provides a review view sorted for triage
- `repro_candidates.md` exports only `status="reviewed"` rows for EasyMolKit registration
- `update_candidates_ledger(...)` lets you mark rows as `reviewed`, `rejected`, or `registered_RPxx`

### arXiv Integration

Fetch preprints from arXiv in parallel with OpenAlex:

```matlab
useArxiv = true;
```

- Recorded as `source_dataset = "arxiv"`
- DOI duplicates are removed automatically
- arXiv preprints are excluded when `filterType="article"`

### Layer 3: PDF Extension

| Feature | Parameter | Description |
|---|---|---|
| PDF download and extraction | `enablePdfDownload` | Download OA PDFs and extract text |
| Keyword evidence | `enableKeywordEvidence` | Extract keyword hit snippets from PDF text |

PDF extraction uses a two-stage engine:
- Engine 1: `extractFileText()` (Text Analytics Toolbox)
- Engine 2: Python pdfminer fallback

## Directory Structure

```
main_run_pipeline.m
main_run_batch.m
src/
  openalex/
  adapters/
  export/
  pipeline/
  config/
  util/
  analytics/
  pdf/
  python/
config/
data/list/
result/
test/smoke/
docs/
```

## Related Documents

| File | Contents |
|---|---|
| [docs/quickstart.md](docs/quickstart.md) | Detailed setup, execution guide, and FAQ |
| [docs/workflows/benchmark_institutions.md](docs/workflows/benchmark_institutions.md) | Candidate generation, manual review, and batch execution |
| [docs/workflows/repro_discovery.md](docs/workflows/repro_discovery.md) | Reproduction-candidate discovery and candidate-ledger workflow |
| [docs/reference.md](docs/reference.md) | Function and smoke-test reference |
| [CHANGELOG.md](CHANGELOG.md) | High-level release history |

Detailed internal project rules and phase-by-phase planning remain in the private development repository.

## License

MIT License. See [LICENSE](../../LICENSE) for details.
