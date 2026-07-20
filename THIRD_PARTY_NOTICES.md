# Third-Party Notices - AnyResearch

This document lists third-party data sources, APIs, software libraries, and optional add-ons used by AnyResearch or its standalone examples.

## Data Sources

### OpenAlex

- Provider: OurResearch
- Website: https://openalex.org/
- License: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/)
- Usage: AnyResearch queries the OpenAlex REST API to retrieve scholarly metadata.
- Attribution note: OpenAlex data is released under CC0 and does not require attribution, though upstream publisher and repository metadata may have their own provenance.
- API documentation: https://docs.openalex.org/

## Python Libraries (Layer 3 only)

The following libraries are used only in the optional PDF extraction engine under `src/python/`.

### pdfminer.six

- License: MIT License
- Repository: https://github.com/pdfminer/pdfminer.six
- Usage: PDF text extraction fallback engine

### pdfplumber

- License: MIT License
- Repository: https://github.com/jsvine/pdfplumber
- Usage: Supplementary PDF parsing utility

### PyPDF2 / pypdf

- License: BSD 3-Clause License
- Repository: https://github.com/py-pdf/pypdf
- Usage: PDF metadata and structure inspection

### pypdfium2

- License: Apache License 2.0 for the binding; PDFium is under BSD 3-Clause
- Repository: https://github.com/pypdfium2-team/pypdfium2
- Usage: High-fidelity PDF rendering fallback

## MATLAB Toolboxes

### Text Analytics Toolbox

- Vendor: The MathWorks, Inc.
- License: Commercial, subject to your MATLAB license agreement
- Usage: Primary PDF text extraction engine via `extractFileText`; also used by topic-map TF-IDF and embedding examples
- Documentation: https://www.mathworks.com/products/text-analytics.html

### Statistics and Machine Learning Toolbox

- Vendor: The MathWorks, Inc.
- License: Commercial, subject to your MATLAB license agreement
- Usage: Topic-map example chapters use PCA, `kmeans`, and `tsne`
- Documentation: https://www.mathworks.com/products/statistics.html

### Deep Learning Toolbox

- Vendor: The MathWorks, Inc.
- License: Commercial, subject to your MATLAB license agreement
- Usage: Topic-map embedding chapters require it when MiniLM-based document embeddings are used
- Documentation: https://www.mathworks.com/products/deep-learning.html

## Example Add-Ons (`examples/` only)

The following components are not required for the core AnyResearch product. They are used only by the standalone topic-map examples.

### UMAP add-on for MATLAB

- Source: MATLAB Central File Exchange
- Page: https://www.mathworks.com/matlabcentral/fileexchange/71902-uniform-manifold-approximation-and-projection-umap
- Usage: Optional 2-D layout method used by `topic_map_ch05.m` through `run_umap(...)`
- License note: The File Exchange page exposes a "View License" entry. File Exchange license terms depend on how the submission is published, so verify the add-on page before redistribution.
- Attribution note: Preserve the File Exchange citation and author attribution when bundling or redistributing this add-on.

### HDBSCAN add-on for MATLAB

- Source: MATLAB Central File Exchange (GitHub-linked submission)
- File Exchange page: https://www.mathworks.com/matlabcentral/fileexchange/64864-jorsorokin-hdbscan
- Upstream repository: https://github.com/Jorsorokin/HDBSCAN
- Usage: Optional density-based clustering used by `topic_map_ch04.m` and `topic_map_ch05.m`
- License note: The File Exchange page directs users to the GitHub-linked license context. The upstream README states that the code may be used and distributed while keeping a reference to the original code base and author. I infer from the available source pages that redistribution should preserve upstream attribution and repository context.
- Attribution note: Keep an explicit reference to Jordan Sorokin and the upstream repository when sharing or packaging this add-on.

### MATLAB built-in `umap`

- Source: MathWorks documentation
- Page: https://www.mathworks.com/help/stats/umap.html
- Usage: Built-in alternative available in newer MATLAB releases; `examples/+topicmap/env_check.m` recognizes it as a UMAP-capable environment signal
- License: Commercial, subject to your MATLAB license agreement

## Notes

- AnyResearch itself is released under the [MIT License](LICENSE).
- No third-party algorithms or copyrighted code are embedded in the core `src/` product code.
- The standalone `examples/` area may depend on separately installed MATLAB add-ons that are not shipped in this repository.
- If you redistribute AnyResearch with bundled Python dependencies or external MATLAB add-ons, ensure compliance with their respective licenses and attribution requirements.
