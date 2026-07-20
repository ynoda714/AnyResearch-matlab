# Examples

The `examples/` tree contains standalone post-pipeline samples built on top of a normal AnyResearch run.

It is not part of the Layer 0 product path, is not required for `main_run_pipeline.m`, and remains a best-effort example area.
The current example surface is a single topic-map pipeline that reads `search_results.jsonl` and produces a map plus a cluster summary table.

## Usage Boundary

- `examples/` does not participate in `main_run_pipeline.m`, `main_run_batch.m`, or `src/`
- The supported product output remains the standard AnyResearch artifact set under `result/runs/<timestamp>/`
- `examples/` may require extra MATLAB toolboxes or support packages that the core product does not require
- No external dataset download is required; the example reads `search_results.jsonl` produced by AnyResearch
- Large-run topic mapping is an example-side decision, not a change to the core product scope

## Input Artifact

The topic-map pipeline reads:

```text
result/runs/<YYYYMMDD_HHMMSS>/search_results.jsonl
```

It does not read `raw/openalex_page_*.json`.
If you do not pass an explicit path, `topicmap.setup()` resolves the latest available `search_results.jsonl`.

## Pipeline

The current Phase Q example is:

```text
search_results.jsonl
  -> title + abstract text preparation
  -> BERT-Base embedding (768-D)
  -> UMAP reduction to 5-D
  -> k-means clustering on the 5-D coordinates
  -> UMAP reduction to 2-D
  -> PNG topic map + CSV cluster summary
```

The pipeline entry point is:

```text
examples/topic_map_pipeline.m
```

The main parameters are grouped at the top of the script:

- `K`
- `nDim5`
- `batchSize`
- `maxChars`
- `seed`

## Requirements

Required for the Phase Q topic-map pipeline:

- Statistics and Machine Learning Toolbox
- Text Analytics Toolbox
- Deep Learning Toolbox
- Text Analytics Toolbox Model for BERT-Base Network support package
- MATLAB R2026a or later for built-in `umap()`

If the BERT-Base support package is missing, `topicmap.embed_documents()` fails with a direct install hint instead of silently falling back to another model.
Install the support package from Add-On Explorer by searching for `Text Analytics Toolbox Model for BERT-Base Network`.

Use `topicmap.env_check()` to inspect local readiness before running the pipeline.

## Generate A Sample JSONL

1. Open `main_run_pipeline.m`
2. Set a small keyword query in Section 0, for example:

```matlab
query      = "renewable energy forecasting";
fromDate   = "2024-01-01";
toDate     = "2025-12-31";
sortBy     = "cited_by_count:desc";
filterType = "";
```

3. Run Section 0 and Section 1
4. Confirm that the run folder contains `search_results.jsonl`
5. Run `examples/topic_map_pipeline.m`

## Outputs

The pipeline writes under:

```text
result/examples/topicmap/<runId>/
```

Outputs include:

- `topic_map.png`
- `topic_map_points.csv`
- `topic_map_clusters.csv`
- `topic_map_run_meta.json`

`topic_map_points.csv` stores both the 5-D clustering coordinates (`umap5_1`..`umap5_5`) and the 2-D plotting coordinates (`umap_x`, `umap_y`).

`topic_map_clusters.csv` contains:

- `cluster`
- `n_docs`
- `top_terms`
- `representative_titles`
- `silhouette_5d`
- `silhouette_2d`
- `lexical_coherence`
- `top_terms_overlap`
- `dominant_type`
- `type_purity`
- `duplicate_title_rate`

The cluster summary is intentionally non-LLM. It provides frequency-based terms and representative titles only.
`top_terms` are filtered with a built-in English and academic stopword list plus light plural normalization so labels stay readable on small or noisy corpora.
Clusters may reflect document type or publishing style as well as research area.
`silhouette_5d` is the primary quality metric because clustering is performed in the 5-D UMAP space.
`silhouette_2d` is only a plotting diagnostic and should not be treated as a direct cluster-quality score.
Silhouette values are for relative comparison within the same embedding, not absolute quality grading.

## Measured Defaults

Phase Q defaults are based on measurements recorded on July 20, 2026:

- `batchSize = 64`
- `maxChars = 1000`
- `K = 20`

These defaults target BERT-Base throughput on the measured RTX 3060 Laptop environment while keeping truncation below the BERT context limit for the observed corpus.

## Helper Functions

### `examples/+topicmap/setup.m`
- Builds standalone configuration for the example pipeline
- Resolves the latest `search_results.jsonl` by default

### `examples/+topicmap/env_check.m`
- Detects local readiness for the Phase Q pipeline
- Reports missing prerequisites

### `examples/+topicmap/read_search_results.m`
- Reads `search_results.jsonl`
- Normalizes a stable example schema

### `examples/+topicmap/extract_text.m`
- Builds model input text from `title` and `abstract`
- Supports a character cap for BERT input preparation

### `examples/+topicmap/embed_documents.m`
- Runs BERT-Base embedding and returns 768-D vectors
- Uses batch inference and optional GPU execution

### `examples/+topicmap/reduce_layout.m`
- Reduces matrices with `umap`, `pca`, or `tsne`
- Supports both 5-D and 2-D outputs

### `examples/+topicmap/summarize_clusters.m`
- Builds cluster-level `top_terms` and `representative_titles`

### `examples/+topicmap/plot_topic_map.m`
- Draws the 2-D topic map and saves a PNG

### `examples/+topicmap/write_utf8_csv.m`
- Writes UTF-8 BOM CSV files for Excel-safe cluster outputs

## Smoke Tests

- `test_topicmap_p0_smoke.m`
- `test_topicmap_p2_smoke.m`
- `test_topicmap_helpers_smoke.m`
- `test_topicmap_p3_smoke.m`

Run them with:

```matlab
addpath("test");
run_smoke_tests("offline");
```
