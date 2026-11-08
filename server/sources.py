"""One search across every free scholarly source DSCVR uses.

search_all() asks all sources at once (in parallel, each with a short
timeout), merges duplicates by DOI or title, keeps every source that had the
item in `sources`, and ranks the merged list. A slow or failing source is
skipped, never fatal.

    arxiv             preprints in physics, maths, computing, biology, economics
    semantic_scholar  200M+ papers with citation counts
    openalex          every discipline, journals and books
    europepmc         PubMed, PMC, preprints and clinical guidelines
    crossref          the DOI registry: almost every journal article
    doaj              open access journals (everything here is free to read)
    zenodo            open research outputs from CERN's repository
    plos              PLOS journals (all open access)
    core              open access full texts from repositories (needs CORE_API_KEY)

find_pdf() uses Unpaywall to find a legal, free PDF for a DOI.
"""
from __future__ import annotations

import concurrent.futures as cf
import logging
import math
import os
import re
from typing import Any, Callable

import requests

import discover

log = logging.getLogger("sources")
_UA = {"User-Agent": "DSCVR/1.1 (research library; mailto:%s)" % (os.getenv("CONTACT_EMAIL") or "hello@dscvr.app")}
_T = 7  # seconds per source
_WAIT = 8  # the whole search never waits longer than this; late sources are dropped

LABELS = {
    "arxiv": "arXiv", "semantic_scholar": "Semantic Scholar", "openalex": "OpenAlex", "europepmc": "Europe PMC",
    "crossref": "Crossref", "doaj": "DOAJ", "zenodo": "Zenodo", "plos": "PLOS", "core": "CORE", "uk_caselaw": "Find Case Law",
}


def _clean(t: str | None) -> str:
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", t or "")).strip()


def _year(v: Any) -> int | None:
    m = re.search(r"(19|20)\d{2}", str(v or ""))
    return int(m.group(0)) if m else None


def _doi(v: str | None) -> str | None:
    if not v:
        return None
    m = re.search(r"10\.\d{4,9}/[^\s\"<>]+", v, re.I)
    return m.group(0).rstrip(".").lower() if m else None


# ── Extra sources ───────────────────────────────────────────────────

def crossref(q: str, n: int) -> list[dict[str, Any]]:
    r = requests.get("https://api.crossref.org/works", timeout=_T, headers=_UA, params={
        "query.bibliographic": q, "rows": n, "filter": "type:journal-article",
        "select": "DOI,title,author,issued,container-title,abstract,is-referenced-by-count,URL,link",
    })
    r.raise_for_status()
    out = []
    for w in r.json().get("message", {}).get("items", []):
        title = _clean((w.get("title") or [""])[0])
        if not title:
            continue
        pdf = next((l.get("URL") for l in w.get("link") or [] if l.get("content-type") == "application/pdf"
                    and l.get("intended-application") != "text-mining"), None)
        out.append({
            "id": w.get("DOI"), "title": title, "source": "crossref",
            "authors": [f"{a.get('given', '')} {a.get('family', '')}".strip() for a in (w.get("author") or [])[:12] if a.get("family")],
            "year": ((w.get("issued") or {}).get("date-parts") or [[None]])[0][0],
            "summary": _clean(w.get("abstract")).removeprefix("Abstract ").strip(),
            "url": w.get("URL"), "pdfUrl": pdf, "venue": (w.get("container-title") or [None])[0],
            "citations": w.get("is-referenced-by-count"), "doi": (w.get("DOI") or "").lower() or None, "subjects": [],
        })
    return out


def doaj(q: str, n: int) -> list[dict[str, Any]]:
    r = requests.get(f"https://doaj.org/api/search/articles/{requests.utils.quote(q)}", timeout=_T, headers=_UA,
                     params={"pageSize": n})
    r.raise_for_status()
    out = []
    for hit in r.json().get("results", []):
        b = hit.get("bibjson") or {}
        doi = next((i.get("id") for i in b.get("identifier") or [] if i.get("type") == "doi"), None)
        links = b.get("link") or []
        pdf = next((l.get("url") for l in links if (l.get("content_type") or "").upper() == "PDF"), None)
        url = next((l.get("url") for l in links if l.get("type") == "fulltext"), None) or (f"https://doi.org/{doi}" if doi else None)
        out.append({
            "id": hit.get("id"), "title": _clean(b.get("title")), "source": "doaj",
            "authors": [a.get("name", "") for a in (b.get("author") or [])[:12] if a.get("name")],
            "year": _year(b.get("year")), "summary": _clean(b.get("abstract")), "url": url, "pdfUrl": pdf,
            "venue": (b.get("journal") or {}).get("title"), "doi": (doi or "").lower() or None,
            "openAccess": True, "subjects": [s.get("term") for s in (b.get("subject") or [])[:3] if s.get("term")],
        })
    return [p for p in out if p["title"]]


def zenodo(q: str, n: int) -> list[dict[str, Any]]:
    r = requests.get("https://zenodo.org/api/records", timeout=_T, headers=_UA,
                     params={"q": q, "size": n, "type": "publication", "sort": "bestmatch"})
    r.raise_for_status()
    out = []
    for h in (r.json().get("hits") or {}).get("hits", []):
        m = h.get("metadata") or {}
        pdf = next(((f.get("links") or {}).get("self") for f in h.get("files") or [] if str(f.get("key", "")).lower().endswith(".pdf")), None)
        out.append({
            "id": str(h.get("id")), "title": _clean(m.get("title")), "source": "zenodo",
            "authors": [c.get("name", "") for c in (m.get("creators") or [])[:12] if c.get("name")],
            "year": _year(m.get("publication_date")), "summary": _clean(m.get("description"))[:2000],
            "url": (h.get("links") or {}).get("self_html") or h.get("doi_url"), "pdfUrl": pdf,
            "venue": (m.get("journal") or {}).get("title"), "doi": (h.get("doi") or "").lower() or None,
            "openAccess": (m.get("access_right") == "open"), "subjects": [],
        })
    return [p for p in out if p["title"]]


def plos(q: str, n: int) -> list[dict[str, Any]]:
    r = requests.get("https://api.plos.org/search", timeout=_T, headers=_UA, params={
        "q": f'title:"{q}" OR abstract:({q})', "rows": n, "wt": "json", "fq": "doc_type:full",
        "fl": "id,title_display,author_display,publication_date,journal,abstract,counter_total_all",
    })
    r.raise_for_status()
    out = []
    for d in (r.json().get("response") or {}).get("docs", []):
        doi = d.get("id")
        out.append({
            "id": doi, "title": _clean(d.get("title_display")), "source": "plos",
            "authors": (d.get("author_display") or [])[:12], "year": _year(d.get("publication_date")),
            "summary": _clean(" ".join(d.get("abstract") or [])).removeprefix("Abstract:").strip(),
            "url": f"https://doi.org/{doi}", "venue": d.get("journal"), "doi": (doi or "").lower() or None,
            "pdfUrl": f"https://journals.plos.org/plosone/article/file?id={doi}&type=printable" if doi else None,
            "openAccess": True, "subjects": [],
        })
    return [p for p in out if p["title"]]


def core(q: str, n: int) -> list[dict[str, Any]]:
    key = os.getenv("CORE_API_KEY", "")
    if not key:
        return []
    r = requests.get("https://api.core.ac.uk/v3/search/works", timeout=_T,
                     headers={**_UA, "Authorization": f"Bearer {key}"}, params={"q": q, "limit": n})
    r.raise_for_status()
    out = []
    for w in r.json().get("results", []):
        out.append({
            "id": str(w.get("id")), "title": _clean(w.get("title")), "source": "core",
            "authors": [a.get("name", "") for a in (w.get("authors") or [])[:12] if a.get("name")],
            "year": w.get("yearPublished"), "summary": _clean(w.get("abstract"))[:2000],
            "url": (w.get("links") or [{}])[0].get("url") if w.get("links") else None,
            "pdfUrl": w.get("downloadUrl") or None, "venue": (w.get("journals") or [{}])[0].get("title") if w.get("journals") else None,
            "doi": (w.get("doi") or "").lower() or None, "openAccess": True, "subjects": [],
        })
    return [p for p in out if p["title"]]


def _s2(q: str, n: int) -> list[dict[str, Any]]:
    # Directly, without the OpenAlex fallback: OpenAlex is already in the mix.
    headers = {"x-api-key": discover._S2_API_KEY} if discover._S2_API_KEY else {}
    r = requests.get("https://api.semanticscholar.org/graph/v1/paper/search", timeout=_T, headers=headers,
                     params={"query": q, "limit": n, "fields": discover.S2_FIELDS})
    r.raise_for_status()
    out = []
    for p in r.json().get("data", []):
        x = discover._s2_paper(p)
        x["doi"] = ((p.get("externalIds") or {}).get("DOI") or "").lower() or None
        out.append(x)
    return out


def _arxiv(q: str, n: int) -> list[dict[str, Any]]:
    out = discover.search_arxiv(f"all:{q}", "relevance", n)
    for p in out:
        p["openAccess"] = True
    return out


def _openalex(q: str, n: int) -> list[dict[str, Any]]:
    out = discover.search_openalex(q, n)
    for p in out:
        p["doi"] = _doi(p.get("url"))
    return out


SOURCES: dict[str, Callable[[str, int], list[dict[str, Any]]]] = {
    "openalex": _openalex,
    "semantic_scholar": _s2,
    "arxiv": _arxiv,
    "europepmc": lambda q, n: discover.search_europepmc(q, n),
    "crossref": crossref,
    "doaj": doaj,
    "plos": plos,
    "zenodo": zenodo,
    "core": core,
}

# How much a top result from each source counts when ranking the merged list.
WEIGHT = {"openalex": 1.0, "semantic_scholar": 1.0, "europepmc": 0.95, "arxiv": 0.9, "crossref": 0.8,
          "doaj": 0.85, "plos": 0.85, "core": 0.8, "zenodo": 0.6}


def _key(p: dict[str, Any]) -> str:
    doi = _doi(p.get("doi")) or _doi(p.get("url"))
    if doi:
        return "doi:" + doi
    return "t:" + re.sub(r"[^a-z0-9]+", "", (p.get("title") or "").lower())[:120]


def _merge(a: dict[str, Any], b: dict[str, Any]) -> dict[str, Any]:
    """Fills gaps in a with b; keeps a's source as the primary label."""
    for k in ("summary", "pdfUrl", "venue", "year", "doi", "url", "kind"):
        if not a.get(k) and b.get(k):
            a[k] = b[k]
    if len(b.get("summary") or "") > len(a.get("summary") or "") * 1.5:
        a["summary"] = b["summary"]
    if (b.get("citations") or 0) > (a.get("citations") or 0):
        a["citations"] = b["citations"]
    if len(b.get("authors") or []) > len(a.get("authors") or []):
        a["authors"] = b["authors"]
    a["openAccess"] = bool(a.get("openAccess") or b.get("openAccess") or a.get("pdfUrl"))
    a["sources"] = sorted(set(a.get("sources", [a["source"]])) | {b["source"]}, key=list(SOURCES).index)
    return a


def rank(results: dict[str, list[dict[str, Any]]], q: str, sort: str = "relevance") -> list[dict[str, Any]]:
    words = [w for w in re.findall(r"[a-z0-9]+", q.lower()) if len(w) > 2]
    merged: dict[str, dict[str, Any]] = {}
    score: dict[str, float] = {}
    for src, papers in results.items():
        n = max(len(papers), 1)
        for i, p in enumerate(papers):
            if not p.get("title"):
                continue
            k = _key(p)
            s = WEIGHT.get(src, 0.7) * (1 - i / (n + 2))
            if k in merged:
                merged[k] = _merge(merged[k], p)
                score[k] += 0.35 * s  # found by several sources: more likely what was meant
            else:
                p = dict(p)
                p["sources"] = [src]
                p["openAccess"] = bool(p.get("openAccess") or p.get("pdfUrl"))
                merged[k] = p
                score[k] = s
    for k, p in merged.items():
        title = (p.get("title") or "").lower()
        if words:
            score[k] += 0.6 * sum(w in title for w in words) / len(words)
        score[k] += 0.12 if p.get("summary") else -0.1
        score[k] += 0.08 if p.get("pdfUrl") else 0
        score[k] += 0.05 * math.log10(1 + (p.get("citations") or 0))
    items = list(merged.items())
    if sort == "date":
        items.sort(key=lambda kv: ((kv[1].get("year") or 0), score[kv[0]]), reverse=True)
    else:
        items.sort(key=lambda kv: score[kv[0]], reverse=True)
    return [p for _, p in items]


def _cached(source: str, q: str, n: int) -> list[dict[str, Any]]:
    return discover.cached(("src", source, q, n), lambda: SOURCES[source](q, n))


def search_all(q: str, limit: int = 30, sort: str = "relevance", only: list[str] | None = None,
               open_access: bool = False) -> dict[str, Any]:
    """Every source at once. Returns {papers, sources: {name: count or "error"}}."""
    names = [s for s in SOURCES if not only or s in only]
    per = max(6, min(15, limit // 2))
    results: dict[str, list[dict[str, Any]]] = {}
    status: dict[str, Any] = {}
    pool = cf.ThreadPoolExecutor(max_workers=len(names))
    futures = {pool.submit(_cached, s, q, per): s for s in names}
    done, pending = cf.wait(futures, timeout=_WAIT)
    pool.shutdown(wait=False, cancel_futures=True)  # don't hold the answer for a slow source
    for f in pending:
        status[futures[f]] = "timeout"
    for f in done:
        s = futures[f]
        try:
            results[s] = f.result() or []
            status[s] = len(results[s])
        except Exception as e:  # noqa: BLE001
            log.info("source %s failed: %s", s, e)
            status[s] = "busy" if "429" in str(e) else "error"
    if os.getenv("CORE_API_KEY", "") == "":
        status.pop("core", None)
    papers = rank(results, q, sort)
    if open_access:
        papers = [p for p in papers if p.get("pdfUrl") or p.get("openAccess")]
    return {"papers": papers[:limit], "sources": status}


# ── Free PDFs ────────────────────────────────────────────────────────

def find_pdf(doi: str) -> dict[str, Any] | None:
    """A legal open-access copy of a DOI from Unpaywall, or None."""
    doi = _doi(doi)
    if not doi:
        return None
    email = os.getenv("CONTACT_EMAIL") or "hello@dscvr.app"
    r = requests.get(f"https://api.unpaywall.org/v2/{doi}", params={"email": email}, timeout=_T, headers=_UA)
    if r.status_code == 404:
        return None
    r.raise_for_status()
    d = r.json()
    locs = [d.get("best_oa_location")] + list(d.get("oa_locations") or [])
    for loc in locs:
        if loc and loc.get("url_for_pdf"):
            return {"pdfUrl": loc["url_for_pdf"], "host": loc.get("host_type"), "license": loc.get("license"),
                    "version": loc.get("version")}
    return None
