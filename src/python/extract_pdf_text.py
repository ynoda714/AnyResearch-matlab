"""
PDFテキスト抽出ヘルパー（MATLABからpyenv経由で呼び出し可能）

使い方（MATLAB例）:
pyenv('Version','<venvのpython.exeパス>');
py.importlib.import_module('extract_pdf_text');
text = py.extract_pdf_text.extract_text('C:/path/to/file.pdf');
"""
import os

import re

def clean_pdf_text(text):
    """
    PDF本文からノイズ行・定型情報を除去し、改行・空白を正規化する
    """
    if not text:
        return ""
    # 行単位でノイズ除去
    lines = text.splitlines()
    cleaned = []
    noise_patterns = [
        r"^\s*doi[:：]", r"^\s*https?://", r"^\s*copyright", r"all rights reserved",
        r"biorxiv preprint", r"medrxiv preprint", r"issn", r"^\s*received[:：]", r"^\s*accepted[:：]", r"^\s*published online",
        r"^\s*correspondence[:：]", r"^\s*e-?mail[:：]", r"^\s*keywords?[:：]", r"^\s*abstract[:：]?\s*$", r"^\s*introduction[:：]?\s*$",
        r"^\s*references?[:：]?\s*$", r"^\s*table of contents", r"^\s*supplementary", r"^\s*figure ",
        r"^\s*page \d+", r"^\s*\d{4}[-/]\d{1,2}[-/]\d{1,2}", r"^\s*\d+\s*$",
        r"^\s*open access", r"^\s*license", r"^\s*preprint", r"^\s*journal", r"^\s*author", r"^\s*affiliation"
    ]
    noise_re = re.compile("|".join(noise_patterns), re.IGNORECASE)
    # 技術用語（例: matlab/MATLAB/Matlab）など短い単語も残すため、
    # ただの短い行除去は行わず、ノイズパターンのみ除去する
    for line in lines:
        l = line.strip()
        if not l:
            continue
        if noise_re.search(l):
            continue
        cleaned.append(l)
    # 連続スペース・改行の正規化
    text2 = " ".join(cleaned)
    text2 = re.sub(r"[ \t]+", " ", text2)
    text2 = re.sub(r"\s{3,}", " ", text2)
    text2 = text2.strip()
    return text2

def extract_text(path):
    path = str(path)
    if not os.path.isfile(path):
        raise FileNotFoundError(f'PDF not found: {path}')

    # Try pdfminer.six first
    try:
        from pdfminer.high_level import extract_text as pm_extract_text
        text = pm_extract_text(path)
        if text and text.strip():
            return clean_pdf_text(text)
    except Exception:
        pass

    # Fallback: pdfplumber
    try:
        import pdfplumber
        pages = []
        with pdfplumber.open(path) as pdf:
            for p in pdf.pages:
                t = p.extract_text()
                if t:
                    pages.append(t)
        result = "\n".join(pages)
        if result.strip():
            return clean_pdf_text(result)
    except Exception:
        pass

    # Fallback: PyPDF2
    try:
        from PyPDF2 import PdfReader
        reader = PdfReader(path)
        texts = []
        for p in reader.pages:
            try:
                t = p.extract_text()
            except Exception:
                t = ''
            if t:
                texts.append(t)
        result = "\n".join(texts)
        if result.strip():
            return clean_pdf_text(result)
    except Exception:
        pass

    # Fallback: pypdfium2
    try:
        import pypdfium2 as pdfium
        doc = pdfium.PdfDocument(path)
        texts = []
        for i in range(len(doc)):
            page = doc[i]
            textpage = page.get_textpage()
            t = textpage.get_text_range()
            if t:
                texts.append(t)
            textpage.close()
            page.close()
        result = "\n".join(texts)
        if result.strip():
            return clean_pdf_text(result)
    except Exception:
        pass

    raise RuntimeError('PDF text extraction failed with all available backends')
