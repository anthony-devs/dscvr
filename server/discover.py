"""Discover proxy: arXiv + Semantic Scholar search that adds CORS headers."""
from __future__ import annotations

import logging
import os
import threading
import time
from typing import Any, Callable

import feedparser
import requests

_S2_API_KEY = os.getenv("S2_API_KEY", "")
_TIMEOUT = 15  # seconds
_CONTACT = os.getenv("CONTACT_EMAIL", "")  # OpenAlex "polite pool" gets faster, steadier service

logger = logging.getLogger(__name__)

# ── Small TTL cache: identical queries within 10 minutes hit memory ──
_CACHE_TTL = 600
_CACHE_MAX = 500
_cache: dict[tuple, tuple[float, list[dict[str, Any]]]] = {}
_cache_lock = threading.Lock()


def cached(key: tuple, fetch: Callable[[], list[dict[str, Any]]]) -> list[dict[str, Any]]:
    now = time.time()
    with _cache_lock:
        hit = _cache.get(key)
        if hit and now - hit[0] < _CACHE_TTL:
            return hit[1]
    papers = fetch()
    if papers:  # never cache empty/failed results
        with _cache_lock:
            if len(_cache) >= _CACHE_MAX:
                _cache.pop(next(iter(_cache)))
            _cache[key] = (now, papers)
    return papers


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
    resp = None
    for attempt in range(2):
        try:
            resp = requests.get(
                "https://api.semanticscholar.org/graph/v1/paper/search",
                params=params,
                timeout=_TIMEOUT,
                headers=headers,
            )
        except requests.RequestException as e:
            logger.warning("Semantic Scholar request failed: %s", e)
            resp = None
        if resp is not None and resp.status_code == 200:
            break
        if attempt == 0:
            time.sleep(1.2)
    if resp is None or resp.status_code != 200:
        # S2 throttles shared cloud IPs hard without an API key (429).
        # Fall back to OpenAlex so search still works; results are labelled.
        logger.warning(
            "Semantic Scholar unavailable (%s), falling back to OpenAlex",
            resp.status_code if resp is not None else "network",
        )
        return search_openalex(query, limit)
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


def search_openalex(query: str, limit: int = 20) -> list[dict[str, Any]]:
    """Search OpenAlex (free, no key). Used when Semantic Scholar is throttled."""
    params = {"search": query, "per_page": str(limit)}
    if _CONTACT:
        params["mailto"] = _CONTACT
    resp = requests.get(
        "https://api.openalex.org/works",
        params=params,
        timeout=_TIMEOUT,
        headers={"User-Agent": "DSCVR/1.0 (research library)"},
    )
    resp.raise_for_status()
    papers: list[dict[str, Any]] = []
    for w in resp.json().get("results", []):
        loc = w.get("best_oa_location") or w.get("primary_location") or {}
        venue = ((w.get("primary_location") or {}).get("source") or {}).get("display_name")
        papers.append({
            "id": (w.get("id") or "").rsplit("/", 1)[-1],
            "title": _clean(w.get("title") or w.get("display_name") or ""),
            "source": "openalex",
            "authors": [
                (a.get("author") or {}).get("display_name", "")
                for a in (w.get("authorships") or [])[:12]
                if (a.get("author") or {}).get("display_name")
            ],
            "year": w.get("publication_year"),
            "summary": _abstract(w.get("abstract_inverted_index")),
            "url": w.get("doi") or loc.get("landing_page_url") or w.get("id"),
            "pdfUrl": loc.get("pdf_url"),
            "venue": venue,
            "citations": w.get("cited_by_count"),
            "subjects": [],
        })
    return papers


def _abstract(inverted: dict[str, list[int]] | None) -> str:
    """OpenAlex stores abstracts as {word: [positions]}; rebuild the text."""
    if not inverted:
        return ""
    words: dict[int, str] = {}
    for word, positions in inverted.items():
        for pos in positions:
            words[pos] = word
    return _clean(" ".join(words[i] for i in sorted(words)))


def _clean(text: str) -> str:
    """Collapse whitespace and strip."""
    import re
    return re.sub(r"\s+", " ", text).strip()
