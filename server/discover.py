"""Discover proxy: one search endpoint for every source DSCVR offers, with CORS.

    arxiv             preprints (sciences, computing, maths, economics)
    semantic_scholar  papers across fields (falls back to OpenAlex)
    openalex          every discipline, journals included
    europepmc         medicine, nursing, pharmacy, public health (PubMed +
                      PMC + clinical guidelines), free, no key
    uk_caselaw        UK court judgments from The National Archives' Find
                      Case Law, under the Open Justice Licence. One request
                      per user search only: bulk or computational use needs
                      their transactional licence.

African legal information institutes (NigeriaLII, GhaLII, Kenya Law, SAFLII)
don't allow automated search or AI use, so the app links out to their own
search pages instead of calling them from here.
"""
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


# ── Europe PMC (PubMed, PMC, guidelines) ─────────────────────────────

def search_europepmc(query: str, limit: int = 20, sort: str = "relevance", guidelines: bool = False) -> list[dict[str, Any]]:
    """Biomedical and health literature. sort="date" gives recent
    articles (last 12 months). guidelines=True keeps only clinical
    practice guidelines."""
    q = query.strip()
    if sort == "date" and ":" not in q:  # plain words: match the title or abstract, not any field
        q = f"TITLE_ABS:({q})"
    if guidelines:
        q = f"({q}) AND (PUB_TYPE:\"practice guideline\" OR PUB_TYPE:\"guideline\")"
    if sort == "date":
        # "Latest" = the most relevant peer-reviewed articles from the last
        # 12 months. A strict newest-first sort surfaces odd, barely related
        # items with future issue dates, so relevance ranks within the window.
        import datetime as _dt
        today = _dt.date.today()
        start = today - _dt.timedelta(days=365)
        q = f"({q}) AND FIRST_PDATE:[{start.isoformat()} TO {today.isoformat()}] AND HAS_ABSTRACT:y AND SRC:MED"
    params = {"query": q, "format": "json", "pageSize": str(limit), "resultType": "core"}
    if _CONTACT:
        params["email"] = _CONTACT
    resp = requests.get("https://www.ebi.ac.uk/europepmc/webservices/rest/search", params=params,
                        timeout=_TIMEOUT, headers={"User-Agent": "DSCVR/1.0 (research library)"})
    resp.raise_for_status()
    papers: list[dict[str, Any]] = []
    for r in (resp.json().get("resultList") or {}).get("result", []):
        pdf = None
        for u in ((r.get("fullTextUrlList") or {}).get("fullTextUrl") or []):
            if u.get("documentStyle") == "pdf" and u.get("availabilityCode") in ("OA", "F"):
                pdf = u.get("url")
                break
        src, rid = r.get("source") or "MED", r.get("id") or ""
        journal = ((r.get("journalInfo") or {}).get("journal") or {}).get("title") or r.get("bookOrReportDetails", {}).get("publisher")
        types = [t for t in ((r.get("pubTypeList") or {}).get("pubType") or []) if isinstance(t, str)]
        kind = next((t for t in types if "guideline" in t.lower()), None) or \
            next((t for t in types if t.lower() in ("review", "systematic review", "meta-analysis", "randomized controlled trial", "case reports")), None)
        try:
            year = int(r.get("pubYear")) if r.get("pubYear") else None
        except ValueError:
            year = None
        papers.append({
            "id": f"{src}:{rid}",
            "title": _clean((r.get("title") or "").rstrip(".")),
            "source": "europepmc",
            "authors": [a.strip() for a in (r.get("authorString") or "").rstrip(".").split(",") if a.strip()][:12],
            "year": year,
            "summary": _clean(re.sub(r"<[^>]+>", " ", r.get("abstractText") or "")),
            "url": f"https://europepmc.org/article/{src}/{rid}",
            "pdfUrl": pdf,
            "venue": journal,
            "citations": r.get("citedByCount"),
            "doi": r.get("doi"),
            "pmid": r.get("pmid"),
            "kind": kind,
            "openAccess": r.get("isOpenAccess") == "Y",
            "subjects": [],
        })
    return papers


# ── UK case law (The National Archives, Find Case Law) ───────────────

UK_COURTS = {"uksc": "UK Supreme Court", "ukpc": "Privy Council", "ewca": "Court of Appeal", "ewhc": "High Court"}


def search_uk_caselaw(query: str, limit: int = 20, court: str = "") -> list[dict[str, Any]]:
    """Judgments of the UK courts, newest first. Returns them in the same
    shape as papers, with the neutral citation as the venue."""
    import xml.etree.ElementTree as ET
    params = {"query": query, "per_page": str(min(limit, 50)), "order": "-date"}
    if court:
        params["court"] = court
    resp = requests.get("https://caselaw.nationalarchives.gov.uk/atom.xml", params=params,
                        timeout=_TIMEOUT, headers={"User-Agent": "DSCVR/1.0 (research library)"})
    resp.raise_for_status()
    ns = {"a": "http://www.w3.org/2005/Atom", "tna": "https://caselaw.nationalarchives.gov.uk"}
    root = ET.fromstring(resp.content)
    cases: list[dict[str, Any]] = []
    for e in root.findall("a:entry", ns):
        url = pdf = None
        for link in e.findall("a:link", ns):
            if link.get("type") == "application/pdf":
                pdf = link.get("href")
            elif link.get("rel") == "alternate" and not link.get("type"):
                url = link.get("href")
        citation = next((i.text for i in e.findall("tna:identifier", ns) if i.get("type") == "ukncn" and i.text), None)
        published = (e.findtext("a:published", "", ns) or "")[:10]
        court_name = (e.findtext("a:author/a:name", "", ns) or "").strip()
        title = _clean(e.findtext("a:title", "", ns) or "")
        cases.append({
            "id": (url or "").split("caselaw.nationalarchives.gov.uk/")[-1] or e.findtext("a:id", "", ns),
            "title": title,
            "source": "uk_caselaw",
            "authors": [court_name] if court_name else [],
            "year": int(published[:4]) if published[:4].isdigit() else None,
            "summary": " · ".join(x for x in (court_name, citation, published and f"Judgment handed down {published}") if x),
            "url": url,
            "pdfUrl": pdf,
            "venue": citation,
            "kind": "judgment",
            "court": court_name,
            "citation": citation,
            "date": published or None,
            "subjects": [],
        })
    return cases


# Free legal information institutes we link to but never fetch from.
LAW_LIBRARIES = [
    {"id": "nigerialii", "name": "NigeriaLII", "country": "Nigeria", "search": "https://nigerialii.org/search/?q={q}"},
    {"id": "ghalii", "name": "GhaLII", "country": "Ghana", "search": "https://ghalii.org/search/?q={q}"},
    {"id": "kenyalaw", "name": "Kenya Law", "country": "Kenya", "search": "https://new.kenyalaw.org/search/?q={q}"},
    {"id": "saflii", "name": "SAFLII", "country": "South Africa", "search": "https://www.saflii.org/cgi-bin/sinosrch-adw.cgi?query={q}"},
    {"id": "ulii", "name": "ULII", "country": "Uganda", "search": "https://ulii.org/search/?q={q}"},
    {"id": "commonlii", "name": "CommonLII", "country": "Commonwealth", "search": "https://www.commonlii.org/cgi-bin/sinosrch.cgi?query={q}"},
]
