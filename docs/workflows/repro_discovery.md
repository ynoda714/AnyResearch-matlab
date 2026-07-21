# Workflow: Reproduction-Candidate Discovery for EasyMolKit

&nbsp; [日本語](../jp/workflows/repro_discovery.md)

> Use AnyResearch Layer 0 search to build, triage, and register reproduction candidates for EasyMolKit.
> The goal is fast candidate discovery, not topic clustering or network visualization.

---

## 0. Preconditions

- OpenAlex API Key is configured
- Use `main_run_pipeline.m` for single-search execution
- The EasyMolKit theme can be expressed as search keywords

Recommended baseline:

```matlab
query             = "Morgan fingerprint ECFP cheminformatics QSAR";
fromDate          = "2018-01-01";
toDate            = "2025-12-31";
sortBy            = "cited_by_count:desc";
filterType        = "article";
requireOpenAccess = true;
filterCountryCode = "";
enablePdfDownload = false;
useArxiv          = false;
appendToCandidates = false;
```

Optional noise reduction:

```matlab
citedByMin = 20;
citedByMax = 0;
```

---

## 1. Build a Candidate Pool with Keyword Search

Start from a normal `query=` search.

Examples:

| Theme | Example |
|---|---|
| ESOL | `"ESOL aqueous solubility prediction"` |
| BBBP | `"BBBP blood brain barrier permeability"` |
| Fingerprint QSAR | `"Morgan fingerprint ECFP cheminformatics QSAR"` |
| GNN | `"graph neural network molecular property prediction"` |
| Molecular language models | `"SMILES transformer cheminformatics"` |
| Explainability | `"SHAP feature importance molecular descriptor"` |

Outputs:

```text
result/runs/<YYYYMMDD_HHMMSS>/
  search_results.xlsx
  search_results.jsonl
  search_results.csv
  run_meta.json
```

---

## 1.5. One-Hop Snowball Search from a Known Paper

If you already have one good paper, use `seedId` to traverse its neighborhood.

### Find later papers that cite it

```matlab
query         = "";
seedId        = "10.1021/ci034243x";
snowballMode  = "citing";
sortBy        = "cited_by_count:desc";
citedByMin    = 5;
requireOpenAccess = true;
```

### Follow its references

```matlab
query         = "";
seedId        = "10.1021/ci034243x";
snowballMode  = "referenced";
sortBy        = "cited_by_count:desc";
citedByMin    = 5;
requireOpenAccess = false;
```

Use cases:

- Find follow-up work around a known benchmark paper
- Recover older classics through highly cited references
- Fill gaps that keyword search alone misses

---

## 2. Triage in Excel

From Phase K onward, do not rely on eye-balling only.
Sort primarily by `fwci` and `repro_signal_score`.

### Overview columns to watch

| Column | Meaning |
|---|---|
| `cited_by_count` | Absolute impact |
| `fwci` | Field- and age-normalized strength |
| `citation_percentile` | Relative rank within field/year |
| `repro_signal_score` | First-pass reproducibility proxy |
| `is_oa` | Minimum PDF accessibility requirement |

### Detail columns to watch

| Column | Meaning |
|---|---|
| `mentions_dataset` | Mentions of known datasets such as ESOL / BBBP / MoleculeNet |
| `mentions_code` | GitHub / code-available style mentions |
| `mentions_library` | RDKit / scikit-learn / PyTorch / DeepChem / MATLAB |
| `mentions_metrics` | RMSE / ROC-AUC / MAE / cross-validation |
| `repro_signal_score` | Sum of the four categories above |

### Recommended sort order

1. `repro_signal_score` descending
2. `fwci` descending
3. `cited_by_count` descending
4. `publication_year` descending

---

## 3. Tier Heuristic for EasyMolKit

| Tier | Rule of thumb |
|---|---|
| A | `repro_signal_score >= 3` and high `fwci`; known dataset or code mention |
| B | `repro_signal_score >= 2`; attractive method but requires extra implementation research |
| C | `repro_signal_score <= 1`; interesting but reproduction cost is unclear |

Notes:

- A highly cited paper with `repro_signal_score=0` may still be expensive to reproduce
- A newer paper with high `fwci` may be worth prioritizing even when total citations are still modest

---

## 4. Register to the Candidate Ledger

From Phase L onward, candidates are managed across runs in a ledger instead of by one-off manual transcription.

### 4.1 Auto-append after search

Enable in `main_run_pipeline.m`:

```matlab
appendToCandidates = true;
```

This updates:

```text
result/candidates/candidates.jsonl
result/candidates/candidates.xlsx
result/candidates/repro_candidates.md
```

- `candidates.jsonl` is the canonical ledger
- Deduplication uses `doi_normalized`, or `openalex_id` when DOI is missing
- Existing `status` / `note` values are preserved; only `last_seen_run_id` advances on re-observation

### 4.2 Update human review state

Minimum ledger updates:

- `status = reviewed` for rows to pass to EasyMolKit
- `status = rejected` for rows to skip for now
- `note` for Tier rationale or follow-up notes

After EasyMolKit registration, use `registered_RPxx`.

Code path:

```matlab
update_candidates_ledger( ...
    ledgerPath="result/candidates/candidates.jsonl", ...
    doiNormalized="10.1000/example", ...
    status="reviewed", ...
    note="Tier A candidate");
```

### 4.3 Generate EasyMolKit-ready Markdown

`export_candidates_md` exports only `status="reviewed"` rows in the same column layout used by EasyMolKit `docs/repro_candidates.md`.

| Column | Meaning |
|---|---|
| `RP number` | Assigned on the EasyMolKit side |
| `Paper` | Candidate paper title |
| `DOI` | Source link |
| `Tier` | Initial estimate derived from `repro_signal_score` |
| `Status` | `reviewed` / `registered_RPxx` etc. |
| `Notes` | Ledger `note` |

After pasting to EasyMolKit, finalize the Tier and RP number there.

---

## 5. Verification Notes as of July 17, 2026

Confirmed in AnyResearch on July 17, 2026:

- `citedByMin` / `citedByMax` are reflected in the OpenAlex filter
- `fwci` / `citation_percentile` / `repro_signal_score` are present in Excel output
- `test_repro_signals_smoke`, `test_analytics_smoke`, and `test_snowball_smoke` pass
- `appendToCandidates=true` updates the candidate ledger and exports candidate Markdown

---

## Related

- `main_run_pipeline.m`
- `src/pipeline/run_pipeline.m`
- `src/util/append_to_candidates.m`
- `src/util/update_candidates_ledger.m`
- `src/export/export_candidates_md.m`
- `docs/quickstart.md`
