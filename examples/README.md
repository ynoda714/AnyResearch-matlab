# Examples

This directory contains standalone sample scripts that read AnyResearch outputs after a normal run.

These scripts are not part of the core product pipeline and are not required for Layer 0 usage.
They remain optional best-effort examples.

## Before You Run Anything Here

1. Generate a normal AnyResearch run with `main_run_pipeline.m`
2. Confirm that `result/runs/<timestamp>/search_results.jsonl` exists
3. Read [../docs/examples.md](../docs/examples.md) for requirements, boundaries, and output details

## Current Topic-Map Entry Point

- `topic_map_pipeline.m`

This pipeline reads `search_results.jsonl`, embeds documents with BERT-Base, reduces them with UMAP, clusters on the 5-D coordinates, and writes:

- `topic_map.png`
- `topic_map_points.csv`
- `topic_map_clusters.csv`
- `topic_map_run_meta.json`

Outputs are written under `result/examples/topicmap/`.
`top_terms` in the cluster summary use built-in English and academic stopword filtering plus light plural normalization.
