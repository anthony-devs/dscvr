"""Discover proxy: arXiv + Semantic Scholar search that adds CORS headers."""
from __future__ import annotations

import logging
import os
import re
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


ARXIV_ID = re.compile(
    r"(?:arxiv\.org/(?:abs|pdf|html)/|arxiv:\s*)?"
    r"(?P<id>\d{4}\.\d{4,5}(?:v\d+)?|[a-z-]+(?:\.[A-Z]{2})?/\d{7}(?:v\d+)?)",
    re.IGNORECASE,
)


def parse_arxiv_id(text: str) -> str | None:
    """Extracts an arXiv id from an id, abs/pdf URL or 'arXiv:' reference."""
    m = ARXIV_ID.search(text.strip())
    return m.group("id") if m else None


def arxiv_by_id(arxiv_id: str) -> dict[str, Any] | None:
    papers = search_arxiv("", limit=1, id_list=arxiv_id)
    return papers[0] if papers else None


def search_arxiv(query: str, sort: str = "relevance", limit: int = 20, id_list: str = "") -> list[dict[str, Any]]:
    """Search arXiv and return a list of normalised paper dicts."""
    params = {
        "search_query": query,
        "id_list": id_list,
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
        "fields": S2_FIELDS,
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

    return [_s2_paper(p) for p in data.get("data", [])]


S2_FIELDS = "title,authors,year,abstract,url,openAccessPdf,venue,citationCount,externalIds"


def _s2_paper(p: dict[str, Any]) -> dict[str, Any]:
    authors = [a.get("name", "") for a in (p.get("authors") or []) if a.get("name")]
    oap = p.get("openAccessPdf") or {}
    ext = p.get("externalIds") or {}
    return {
        "id": p.get("paperId", ""),
        "title": _clean(p.get("title") or ""),
        "source": "semantic_scholar",
        "authors": authors,
        "year": p.get("year"),
        "summary": _clean(p.get("abstract") or ""),
        "url": p.get("url"),
        "pdfUrl": (oap.get("url") or None) if oap else (f"https://arxiv.org/pdf/{ext['ArXiv']}" if ext.get("ArXiv") else None),
        "venue": p.get("venue") or None,
        "citations": p.get("citationCount"),
        "subjects": [],
    }


def s2_key_for(source: str | None, external_id: str | None) -> str | None:
    """Builds a Semantic Scholar paper reference for a saved item."""
    if source == "semantic_scholar" and external_id:
        return external_id
    if source == "arxiv" and external_id:
        return "arXiv:" + re.sub(r"v\d+$", "", external_id)
    return None


def related_papers(ref: str | None, title: str | None, limit: int = 8) -> list[dict[str, Any]]:
    """Papers related to a reference (S2 recommendations), or a title search
    when the item has no known id. Falls back to OpenAlex on throttling."""
    headers = {"x-api-key": _S2_API_KEY} if _S2_API_KEY else {}
    if ref:
        try:
            resp = requests.get(
                f"https://api.semanticscholar.org/recommendations/v1/papers/forpaper/{ref}",
                params={"fields": S2_FIELDS, "limit": str(limit)}, timeout=_TIMEOUT, headers=headers)
            recs = resp.json().get("recommendedPapers", []) if resp.status_code == 200 else []
            if recs:
                return [_s2_paper(p) for p in recs]
            logger.info("S2 recommendations returned %s", resp.status_code)
        except requests.RequestException as e:
            logger.info("S2 recommendations failed: %s", e)
    if title:
        same = _clean(title).lower()
        return [p for p in search_semantic_scholar(title, limit + 1) if _clean(p["title"]).lower() != same][:limit]
    return []


def search_openalex(query: str, limit: int = 20, sort: str = "relevance") -> list[dict[str, Any]]:
    """Search OpenAlex: free, no key, every discipline. Also the fallback when
    Semantic Scholar is throttled. sort="date" gives the newest papers (last
    two years, with an abstract), for subjects arXiv doesn't cover."""
    params = {"search": query, "per_page": str(limit)}
    if sort == "date":
        import datetime as _dt
        today = _dt.date.today()
        params["sort"] = "publication_date:desc"
        params["filter"] = (f"from_publication_date:{today.replace(year=today.year - 2).isoformat()},"
                            f"to_publication_date:{today.isoformat()},has_abstract:true,type:article")
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
