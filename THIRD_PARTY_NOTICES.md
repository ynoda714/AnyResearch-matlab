# Third-Party Notices — AnyResearch

This document lists third-party data sources, APIs, and software libraries used by AnyResearch,
along with their respective licenses and attribution requirements.

---

## Data Sources

### OpenAlex

- **Provider**: OurResearch
- **Website**: https://openalex.org/
- **License**: [CC0 1.0 Universal (Public Domain Dedication)](https://creativecommons.org/publicdomain/zero/1.0/)
- **Usage**: AnyResearch queries the OpenAlex REST API to retrieve scholarly metadata (titles, abstracts, authors, citations, etc.).
- **Attribution note**: OpenAlex data is released under CC0 and requires no attribution. However, please note that metadata originates from various academic publishers and open repositories.
- **API documentation**: https://docs.openalex.org/

---

## Python Libraries (Layer 3 — PDF processing only)

The following libraries are used exclusively in the optional PDF extraction engine (`src/python/`).
They are **not required** for Layer 0 (core) operation.

### pdfminer.six

- **License**: MIT License
- **Repository**: https://github.com/pdfminer/pdfminer.six
- **Usage**: Primary Python PDF text extraction engine (Layer 3 fallback).

### pdfplumber

- **License**: MIT License
- **Repository**: https://github.com/jsvine/pdfplumber
- **Usage**: Supplementary PDF parsing utility (Layer 3).

### PyPDF2

- **License**: BSD 3-Clause License
- **Repository**: https://github.com/py-pdf/pypdf
- **Usage**: PDF metadata and structure inspection (Layer 3).

### pypdfium2

- **License**: Apache License 2.0 (binding); PDFium is licensed under BSD 3-Clause
- **Repository**: https://github.com/pypdfium2-team/pypdfium2
- **Usage**: High-fidelity PDF rendering fallback (Layer 3).

---

## MATLAB Toolboxes (Optional)

### Text Analytics Toolbox

- **Vendor**: The MathWorks, Inc.
- **License**: Commercial — subject to your MATLAB license agreement
- **Usage**: Primary PDF text extraction engine (`extractFileText`), Layer 3 only.
- **Documentation**: https://www.mathworks.com/products/text-analytics.html

---

## Notes

- AnyResearch itself is released under the [MIT License](LICENSE).
- No third-party algorithms or copyrighted code are embedded in the core AnyResearch source (`src/`).
- If you redistribute AnyResearch with the Python dependencies bundled, ensure compliance with the
  individual library licenses listed above.
