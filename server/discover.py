"""Discover proxy: arXiv + Semantic Scholar search that adds CORS headers."""
from __future__ import annotations

import os
from typing import Any

import feedparser
import requests

_S2_API_KEY = os.getenv("S2_API_KEY", "")
_TIMEOUT = 15  # seconds


def search_arxiv(query: str, sort: str = "relevance", limit: int = 20) -> list[dict[str, Any]]:
    """Search arXiv and return a list of normalised paper dicts."""
    params = {
        "search_query": query,
        "start": "0",
        "max_results": str(limit),
        "sortBy": "submittedDate" if sort == "date" else "relevance",
        "sortOrder": "descending",
    }
    resp = requests.get(
        "https://export.arxiv.org/api/query",
        params=params,
        timeout=_TIMEOUT,
        headers={"User-Agent": "DSCVR/1.0 (research library)"},
    )
    resp.raise_for_status()

    feed = feedparser.parse(resp.text)
    papers: list[dict[str, Any]] = []
    for entry in feed.entries:
        arxiv_id = getattr(entry, "id", "")
        pdf_url = None
        for link in getattr(entry, "links", []):
            if link.get("title") == "pdf":
                pdf_url = link.get("href", "").replace("http://", "https://")
        published = getattr(entry, "published", "")
        year = int(published[:4]) if len(published) >= 4 else None
        authors = [a.get("name", "") for a in getattr(entry, "authors", [])]
        categories = [t.get("term", "") for t in getattr(entry, "tags", [])]

        papers.append({
            "id": arxiv_id.split("/abs/")[-1] if "/abs/" in arxiv_id else arxiv_id,
            "title": _clean(getattr(entry, "title", "")),
            "source": "arxiv",
            "authors": authors,
            "year": year,
            "summary": _clean(getattr(entry, "summary", "")),
            "url": arxiv_id.replace("http://", "https://"),
            "pdfUrl": pdf_url,
            "subjects": categories,
        })
    return papers


def search_semantic_scholar(query: str, limit: int = 20) -> list[dict[str, Any]]:
    """Search Semantic Scholar and return normalised paper dicts."""
    params = {
        "query": query,
        "limit": str(limit),
        "fields": "title,authors,year,abstract,url,openAccessPdf,venue,citationCount,externalIds",
    }
    headers = {}
    if _S2_API_KEY:
        headers["x-api-key"] = _S2_API_KEY
    resp = requests.get(
        "https://api.semanticscholar.org/graph/v1/paper/search",
        params=params,
        timeout=_TIMEOUT,
        headers=headers,
    )
    resp.raise_for_status()
    data = resp.json()

    papers: list[dict[str, Any]] = []
    for p in data.get("data", []):
        authors = [a.get("name", "") for a in (p.get("authors") or []) if a.get("name")]
        oap = p.get("openAccessPdf") or {}
        papers.append({
            "id": p.get("paperId", ""),
            "title": _clean(p.get("title", "")),
            "source": "semantic_scholar",
            "authors": authors,
            "year": p.get("year"),
            "summary": _clean(p.get("abstract", "")),
            "url": p.get("url"),
            "pdfUrl": oap.get("url") if oap else None,
            "venue": p.get("venue") or None,
            "citations": p.get("citationCount"),
            "subjects": [],
        })
    return papers


def _clean(text: str) -> str:
    """Collapse whitespace and strip."""
    import re
    return re.sub(r"\s+", " ", text).strip()
