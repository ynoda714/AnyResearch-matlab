# Quick Start Guide — AnyResearch

&nbsp; [日本語](jp/quickstart.md)

> Updated: 2026-07-17

---

## Prerequisites

Layer 0 (Core) alone covers the primary use case. Add Layer 1, 2 or 3 only when needed.

| Item | Layer | Required/Optional | Notes |
|---|---|---|---|
| MATLAB R2025b or later | 0 | Required | |
| OpenAlex API Key | 0 | Required | Free — get it at [openalex.org/settings/api](https://openalex.org/settings/api) |
| institutions.csv | 1 | Optional | CSV with institution IDs for batch runs |
| Text Analytics Toolbox | 3 | Optional | Used for PDF text extraction |
| Python 3.11 + venv | 3 | Optional | PDF fallback engine only |

---

## Setup

### 1. Configure your API Key

```
Copy config/settings.example.json → config/settings.json
```

```json
{
  "openalex": {
    "api_key": "YOUR_OPENALEX_API_KEY"
  }
}
```

Or use an environment variable:
```
ANYRESEARCH_OPENALEX_API_KEY=YOUR_KEY
```

### 2. Python environment (Layer 3: PDF processing only)

```powershell
python -m venv venv
venv\Scripts\activate
pip install -r src/python/requirements.txt
```

---

## Basic Usage: Keyword Search (Layer 0 only)

### Step 1. Edit Section 0 of `main_run_pipeline.m`

```matlab
query    = "renewable energy forecasting";   % search keywords
fromDate = "2023-01-01";                     % start date
toDate   = "2025-12-31";                     % end date
sortBy   = "cited_by_count:desc";             % sort order
filterType = "";                              % document type filter

% Layer 3 options (default: false — Layer 0/1/2 do not require PDF)
enablePdfDownload   = false;    % Layer 3: PDF download
```

**Search syntax:**
| Operation | Syntax | Example |
|---|---|---|
| AND | Separate with spaces | `"renewable energy forecasting"` |
| OR | Use `|` | `"solar|wind energy"` |
| Phrase | Wrap in quotes | `'"deep learning"'` |

**`sortBy` options:**
| Value | Description |
|---|---|
| `"cited_by_count:desc"` | Most cited first (prioritizes impactful papers) |
| `"publication_date:desc"` | Most recent first (for tracking latest trends) |
| `"relevance_score"` | Relevance order (OpenAlex default) |

**`filterType` options:**
| Value | Target |
|---|---|
| `""` | All types (default) |
| `"article"` | Original research articles only |
| `"review"` | Review articles only (ideal for literature reviews) |
| `"article,review"` | Articles + reviews |

Retracted papers are excluded by default (`is_retracted:false`).

### Step 2. Run the Sections

Run both Sections in order using **Run Section** (Ctrl+Enter).

| Section | What it does | When to run |
|---|---|---|
| **0** | Set parameters | Required (enter query, date range, options) |
| **1** | Execute pipeline | Required (API fetch → transform → Excel output) |

Section 1 calls `run_pipeline(...)`, which automatically handles all Layer 0–2 processing.

### Step 3. Check outputs

```
result/runs/<YYYYMMDD_HHMMSS>/
  ├─ search_results.xlsx    ← Main output (4-sheet Excel workbook)
  ├─ search_results.jsonl   ← All data (machine-readable master)
  ├─ search_results.csv     ← CSV-compatible output
  └─ run_meta.json          ← Metadata
```

---

## Advanced: Multi-Institution Batch

Prepare an institution list in `data/list/institutions.csv` for batch processing.
See also: [Benchmark Institutions Workflow](workflows/benchmark_institutions.md)

### `institutions.csv` schema

The batch loader accepts both of the following formats.

1. Legacy 2-column format

```csv
Account,openalex_institution_id
Nagoya University,I1234567890
Fujita Health University,I145673806
Fujita Health University,I4210124875
```

2. Reviewed v2 format (recommended)

```csv
account,openalex_institution_id,display_name,include,role,note
Fujita Health University,I145673806,Fujita Health University,1,main,
Fujita Health University,I4210124875,Fujita Health University Hospital,1,hospital,
Fujita Health University,I9999999999,Old Candidate,0,other,excluded after review
```

Rules:
- Multiple rows with the same `account` are treated as one target institution
- Only rows with `include=1` are executed
- Rows with `include=0` can remain in the CSV as an audit trail
- For multi-ID targets, `openalex_institution_id` is recorded as `I1|I2|...` in batch outputs

### Step 1. Edit Section 0 of `main_run_batch.m`

```matlab
query             = "renewable energy forecasting";
fromDate          = "2023-01-01";
toDate            = "2025-12-31";
institutionsCsv   = "data/list/institutions.csv";
```

Before execution, `run_batch_from_institutions_list` calls `load_institutions_list.m` and validates:

- required columns (`Account/account`, `openalex_institution_id`)
- OpenAlex institution ID format (`I` + digits)
- warning and skip when an account has zero `include=1` rows
- warning when the same ID is assigned to multiple accounts

### Step 2. Run Section 0 (parameters) → Section 1 (execute)

### Step 3. Check outputs

```
result/batch/<YYYYMMDD_HHMMSS>/
  ├─ runs/<institution1>/search_results.xlsx
  ├─ runs/<institution2>/search_results.xlsx
  ├─ batch_summary.csv              ← Summary across all institutions (status, row counts)
  ├─ batch_search_results.xlsx      ← Merged Excel across all institutions (4 sheets)
  └─ batch_comparison.xlsx          ← Cross-institution comparison sheet
```

---

## Option: arXiv Integration (useArxiv=true)

You can also fetch preprints from arXiv in parallel with OpenAlex — useful for papers not yet indexed by OpenAlex. Simply add one line to Section 0 of `main_run_pipeline.m`:

```matlab
useArxiv = true;   % Fetch preprints from arXiv in addition to OpenAlex (default: false)
```

**How it works:**
- AnyResearch calls the arXiv API in parallel with OpenAlex and merges the results.
- Papers with matching DOIs are deduplicated (OpenAlex-indexed version takes precedence).
- arXiv-sourced papers are identified in the `source_dataset` column.

**Using the `source_dataset` filter:**

| source_dataset | Meaning |
|---|---|
| `"openalex"` | Indexed by OpenAlex (peer-reviewed journals, conference proceedings, etc.) |
| `"arxiv"` | Preprint from arXiv |

> **Note:** When `filterType = "article"` is set, arXiv `"preprint"` entries are excluded. Use `filterType = ""` to include preprints.

---

## Testing

Use the following to verify the batch input workflow:

```matlab
addpath("test");
run_smoke_tests("offline")
```

Relevant tests:
- `test_load_institutions_list_smoke()` validates `load_institutions_list.m` in isolation: legacy 2-column CSV, reviewed v2, `include`, duplicate IDs, invalid IDs
- `test_run_batch_smoke()` validates the batch entry point: loading via `load_institutions_list`, `resolveInstitutionIds=false`, and `|`-joined IDs for multi-ID targets

`test_load_institutions_list_smoke()` is network-free. `test_run_batch_smoke()` is partially network-free; only some later cases require OpenAlex API access.

## EasyMolKit Candidate Discovery

For cheminformatics reproduction-candidate discovery, use the following pattern:

```matlab
query             = "Morgan fingerprint ECFP cheminformatics QSAR";
fromDate          = "2018-01-01";
toDate            = "2025-12-31";
sortBy            = "cited_by_count:desc";
filterType        = "article";
requireOpenAccess = true;
citedByMin        = 20;
seedId            = "";
```

How to triage results:

- In `Overview`, sort by `repro_signal_score` descending, then `fwci` descending, then `cited_by_count` descending.
- Use `fwci` and `citation_percentile` to surface newer papers that are strong relative to their field/age, not only old classics.
- Use `repro_signal_score` as the first-pass reproducibility proxy.
- In `Detail`, check `mentions_dataset`, `mentions_code`, `mentions_library`, and `mentions_metrics` to see why the score is high.

One-hop snowball search from a known paper is also supported:

```matlab
query         = "";
seedId        = "10.1021/ci034243x";
snowballMode  = "citing";      % or "referenced"
sortBy        = "cited_by_count:desc";
citedByMin    = 5;
```

This generates the same `search_results.xlsx / .jsonl / .csv` artifact set as keyword search.

### Candidate Ledger (Phase L)

If you want to accumulate candidates across runs:

```matlab
appendToCandidates = true;
```

This updates:

```text
result/candidates/candidates.jsonl
result/candidates/candidates.xlsx
result/candidates/repro_candidates.md
```

To mark reviewed rows programmatically:

```matlab
update_candidates_ledger( ...
    ledgerPath="result/candidates/candidates.jsonl", ...
    doiNormalized="10.1000/example", ...
    status="reviewed", ...
    note="Tier A candidate");
```

## Reading the Excel Output

### Overview Sheet
A quick-scan view of all papers. Click any DOI to open the paper's landing page.

### Detail Sheet
Full information: authors, affiliations, PDF status, summaries, etc. Use filters and sorting for literature review work.

### Summary Sheet
Year-by-year paper count, average citation count, citation velocity (avg citations per paper per year), and growth rate (% year-over-year change). Useful for research trend analysis and grant proposal evidence.

### Config Sheet
Records search conditions and run metadata for reproducibility.

---

## Use-Case Guides

### (a) Literature Review (Faculty / Graduate Students)

For prior research surveys for theses or dissertations, and evidence collection for grant proposals.

1. To collect review articles: `filterType = "review"`
2. To prioritize highly cited papers: `sortBy = "cited_by_count:desc"`
3. Check titles and citation counts in the Overview sheet; follow DOI links
4. Check year-by-year trends in the Summary sheet

### (b) Institutional Benchmarking (IR / Library)

Compare your institution's research output against peer institutions.

1. Prepare an institution list in `data/list/institutions.csv`
2. Set `filterCountryCode = "JP"` in `main_run_batch.m`
3. Compare paper counts and citation counts using per-institution Excel files and `batch_summary.csv`

### (c) Technology Trend Analysis (Industry Engineers / IP Departments)

Survey technology trends and prior art using an existing MATLAB environment without paid tools.

1. Search with technology keywords (e.g. `query = "LiDAR autonomous driving"`)
2. Use `sortBy = "publication_date:desc"` to surface the latest work
3. Identify key players in the author/affiliation columns of the Detail sheet
4. Assess technology maturity from the year-by-year paper count trend in the Summary sheet

### (d) Cheminformatics Reproduction Paper Discovery (EasyMolKit Integration)

Find published cheminformatics papers that are strong candidates for reproducible experiments with EasyMolKit.

**Example queries by research target:**

| Research target | Example query |
|---|---|
| Aqueous solubility (ESOL) | `"ESOL aqueous solubility prediction"` |
| Blood-brain barrier (BBBP) | `"BBBP blood brain barrier permeability"` |
| Molecular fingerprints | `"Morgan fingerprint ECFP cheminformatics QSAR"` |
| Graph neural networks | `"graph neural network molecular property prediction"` |
| Molecular language models | `"SMILES transformer cheminformatics"` |
| Explainability | `"SHAP feature importance molecular descriptor"` |

**Recommended settings:**

```matlab
query      = "Morgan fingerprint ECFP cheminformatics QSAR";
fromDate   = "2018-01-01";
toDate     = "2025-12-31";
sortBy     = "cited_by_count:desc";   % prioritize high-impact, well-validated papers
filterType = "article";               % original research only
requireOpenAccess = true;             % PDF-accessible papers only
filterCountryCode = "";               % no country filter (cheminformatics is international)
```

**Reading results for reproducibility potential:**

| Column | What to look for |
|---|---|
| `is_oa` | `true` = PDF is accessible; prerequisite for reproduction |
| `cited_by_count` | Higher = more validated; correct values are easier to verify |
| `abstract` | Public datasets (ESOL, BBBP, MoleculeNet, FreeSolv) or GitHub links |
| `source_name` | Core venues: J. Chem. Inf. Model., J. Cheminform., ACS J. Chem. Theory Comput. |

For the full workflow — from AnyResearch search results to EasyMolKit RP registration — see [Repro Discovery Workflow](workflows/repro_discovery.md).

---

## FAQ

**Q. Is an OpenAI API Key required?**  
A. No. AnyResearch does not use OpenAI. Layer 2 provides built-in analytics (citation velocity, topic growth rate, institution dominance) without any external AI service.

**Q. Does it work without an API Key at all?**  
A. Since February 2026, OpenAlex requires an API Key. It is free to obtain.

**Q. How large is the free tier?**  
A. The free tier covers approximately $1/day of usage: ~10,000 List+Filter calls, ~1,000 Search calls, and ~100 PDF calls per day.

**Q. Is an institution filter required?**  
A. No. The tool works with just a `query=` keyword. Institution filtering is optional.

**Q. PDF processing is slow / I don't need it**  
A. Set `enablePdfDownload=false` to skip PDF processing entirely.

---

## Troubleshooting

### API Key Issues

**`run_pipeline:NoApiKey` error**  
`openalex.api_key` is not set in `config/settings.json`.
1. Copy `config/settings.example.json` to `config/settings.json`
2. Fill in `api_key` (get a free key at [openalex.org/settings/api](https://openalex.org/settings/api))
3. Or set the environment variable `ANYRESEARCH_OPENALEX_API_KEY=YOUR_KEY`

**Key is set but getting 401 / 403 errors**
- Check that the API Key was copied correctly (watch for leading/trailing spaces)
- Verify the API Key is active on your OpenAlex account page

---

### Zero Results

**`rows_fetched=0` — no output produced**  
Check the following in order:
1. Verify the spelling in `query` (e.g. `"machine leraning"` → `"machine learning"`)
2. Check that `fromDate` / `toDate` is not too narrow (try widening the range)
3. Try `requireOpenAccess=false` if you have OA-only filtering enabled
4. Try `requireAbstract=false` to include recent papers that lack an abstract
5. If `filterCountryCode` is set, try clearing it to `""` temporarily

---

### Network / Timeout

**`webread` error / timeout**
- A VPN or institutional firewall may be blocking external API calls
- Set `openalex.mailto` in `config/settings.json` to your contact email to join the polite pool and improve stability

---

### Excel Output Issues

**Save error when Excel is open**  
Close the target `search_results.xlsx` file before re-running.

**Non-Windows environment / no Excel installed**  
COM mode is unavailable, but the pipeline automatically switches to fallback mode (`writecell`-based). Japanese text is preserved; header styles and auto column widths are not applied in fallback mode.

---

## Related Documents

| File | Contents |
|---|---|
| [README.md](../README.md) | Feature overview, quick start, architecture |
| [docs/workflows/repro_discovery.md](workflows/repro_discovery.md) | Candidate-ledger workflow for EasyMolKit |
| [CHANGELOG.md](../CHANGELOG.md) | High-level release history |
| [docs/reference.md](reference.md) | Function and smoke-test reference |
| [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) | Data sources and library attribution |
| [CONTRIBUTING.md](../CONTRIBUTING.md) | Bug reports, feature requests, pull requests |
| [LICENSE](../../LICENSE) | MIT License |
