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

History & archives (search_history) adds digitised books, documents and
newspapers that are free to read:

    internet_archive  millions of scanned public-domain books (no lending-only items)
    loc               Library of Congress digital collections with PDFs
    europeana         Europe's libraries and archives (EUROPEANA_API_KEY, or the public demo key)

find_pdf() uses Unpaywall to find a legal, free PDF for a DOI.
"""
from __future__ import annotations

import concurrent.futures as cf
import functools
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
    "internet_archive": "Internet Archive", "loc": "Library of Congress", "europeana": "Europeana",
}


def _clean(t: str | None) -> str:
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", t or "")).strip()


def _year(v: Any) -> int | None:
    m = re.search(r"(1[4-9]|20)\d{2}", str(v or ""))
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


# ── History & archives ─────────────────────────────────────────────

def _first(v: Any) -> str:
    if isinstance(v, list):
        v = v[0] if v else ""
    return str(v or "")


_STOP = {"the", "and", "for", "from", "with", "history", "histories", "historical", "of", "in", "on", "a", "an"}


def _words(q: str) -> list[str]:
    return [w for w in re.findall(r"[^\W_]+", q.lower()) if len(w) > 2 and w not in _STOP]


def _relevant(q: str, papers: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Archives match loosely (any word, anywhere in a scanned page), so keep items
    whose title, subjects or summary mention most of what was asked."""
    words = _words(q)
    if not words:
        return papers
    need = max(1, math.ceil(len(words) * 0.6))
    def hits(p: dict[str, Any]) -> int:
        text = " ".join([p.get("title") or "", " ".join(p.get("subjects") or []), (p.get("summary") or "")[:600]]).lower()
        return sum(w in text for w in words)
    return [p for p in papers if hits(p) >= need]


REGIONS: dict[str, tuple[str, list[str]]] = {
    # code: (word added to journal searches, words any of which an archive item must mention)
    "africa": ("Africa", ["Africa", "African", "Nigeria", "Ghana", "Kenya", "Ethiopia", "Egypt", "Congo", "Benin",
                          "Yoruba", "Igbo", "Hausa", "Zulu", "Sudan", "Senegal", "Mali", "Dahomey", "Abyssinia"]),
    "europe": ("Europe", ["Europe", "European", "England", "Britain", "France", "Germany", "Italy", "Spain", "Rome",
                          "Greece", "Russia", "Netherlands", "Portugal"]),
    "asia": ("Asia", ["Asia", "Asian", "China", "India", "Japan", "Korea", "Vietnam", "Siam", "Burma", "Indonesia"]),
    "middle_east": ("Middle East", ["Ottoman", "Arab", "Arabia", "Persia", "Palestine", "Syria", "Iraq", "Turkey",
                                    "Mesopotamia", "Levant"]),
    "americas": ("Americas", ["America", "American", "Mexico", "Brazil", "Caribbean", "Canada", "Peru", "Argentina",
                              "Jamaica", "Haiti"]),
    "oceania": ("Oceania", ["Australia", "Zealand", "Pacific", "Oceania", "Polynesia", "Fiji", "Hawaii"]),
}

# When the source itself was written: primary sources from a period.
WRITTEN: dict[str, tuple[int, int]] = {
    "pre1800": (1400, 1799), "1800s": (1800, 1899), "1900-1949": (1900, 1949), "since1950": (1950, 2100),
}


def _ia_query(words: list[str], op: str, region: list[str] | None = None, years: tuple[int, int] | None = None) -> str:
    terms = f" {op} ".join(words)
    extra = ""
    if region:
        any_of = " OR ".join(f'"{w}"' if " " in w else w for w in region)
        extra += f" AND (title:({any_of}) OR subject:({any_of}) OR description:({any_of}))"
    if years:
        extra += f" AND date:[{years[0]}-01-01 TO {years[1]}-12-31]"
    return (f"(title:({terms}) OR subject:({terms}) OR description:({terms})){extra} AND mediatype:texts "
            "AND NOT collection:(inlibrary OR printdisabled OR lendinglibrary OR ciareadingroom OR usgovernmentmirrors OR opensource OR community OR folkscanomy* "
            "OR wikipediapdfs OR wikicollections OR christian-tracts-literature-society) "
            "AND NOT access-restricted-item:true AND format:(*PDF*)")


def internet_archive(q: str, n: int, region: list[str] | None = None,
                     years: tuple[int, int] | None = None) -> list[dict[str, Any]]:
    # Matches titles, subjects and descriptions (full-text matches are mostly noise),
    # only items anyone can download (no lending-library copies), and only with a PDF.
    words = [re.sub(r"[^\w]", "", w) for w in _words(q)] or [re.sub(r"[^\w ]", "", q)]

    broad = len(words) == 1
    # "History" alone must not mean natural history.
    not_natural = " AND NOT title:(\"natural history\")" if any("histor" in w.lower() for w in words) else ""

    def ask(op: str) -> list[dict[str, Any]]:
        params: dict[str, Any] = {
            "q": _ia_query(words, op, region, years) + not_natural, "rows": n * 2, "output": "json",
            "fl[]": ["identifier", "title", "creator", "date", "description", "subject", "publisher", "collection"]}
        if broad and not years:
            # A one-word search ("History"): the most-read public-domain books.
            params["q"] += " AND date:[1500-01-01 TO 1929-12-31]"
            params["sort[]"] = "downloads desc"
        r = requests.get("https://archive.org/advancedsearch.php", timeout=_T, headers=_UA, params=params)
        r.raise_for_status()
        return (r.json().get("response") or {}).get("docs") or []
    docs = ask("AND")
    if len(docs) < 3 and len(words) > 1:
        docs += [d for d in ask("OR") if d["identifier"] not in {x["identifier"] for x in docs}]
    # Community uploads (opensource, community, folkscanomy) are left out above: too many
    # are copyrighted books uploaded without permission. Library scans are public domain.
    docs = docs[:n * 2]
    # Most items keep their scan at <id>/<id>.pdf. When one doesn't, fetch.py looks the
    # real file name up when the PDF is opened, so search stays fast.
    pdfs = [f"https://archive.org/download/{d['identifier']}/{d['identifier']}.pdf" for d in docs]
    out = []
    for d, pdf in zip(docs, pdfs):
        creators = d.get("creator") or []
        creators = creators if isinstance(creators, list) else [creators]
        subjects = d.get("subject") or []
        subjects = subjects if isinstance(subjects, list) else [subjects]
        out.append({
            "id": d["identifier"], "title": _clean(_first(d.get("title"))), "source": "internet_archive",
            "authors": [_clean(c) for c in creators][:8], "year": _year(d.get("date")),
            "summary": _clean(_first(d.get("description")))[:2000],
            "url": f"https://archive.org/details/{d['identifier']}", "pdfUrl": pdf,
            "venue": _clean(_first(d.get("publisher"))) or "Internet Archive", "doi": None,
            "openAccess": True, "subjects": [_clean(x) for x in subjects][:6], "kind": "book",
        })
    return _relevant(q, [p for p in out if p["title"]])[:n]


def loc(q: str, n: int, region: list[str] | None = None,
        years: tuple[int, int] | None = None) -> list[dict[str, Any]]:
    params = {"q": f"{q} {region[0]}" if region else q, "fo": "json", "c": n + 4, "fa": "online-format:pdf"}
    if years:
        params["dates"] = f"{years[0]}/{years[1]}"
    r = requests.get("https://www.loc.gov/books/", timeout=_T, headers=_UA, params=params)
    r.raise_for_status()
    out = []
    for d in r.json().get("results") or []:
        pdf = next((res.get("pdf") for res in d.get("resources") or [] if res.get("pdf")), None)
        out.append({
            "id": str(d.get("id") or d.get("url") or ""), "title": _clean(d.get("title")), "source": "loc",
            "authors": [c.title() for c in (d.get("contributor") or [])][:8], "year": _year(d.get("date")),
            "summary": _clean(" ".join(d.get("description") or []))[:2000],
            "url": d.get("url") or d.get("id"), "pdfUrl": pdf, "venue": "Library of Congress", "doi": None,
            "openAccess": True, "subjects": [str(x) for x in (d.get("subject") or [])][:6], "kind": "book",
        })
    return _relevant(q, [p for p in out if p["title"]])


def europeana(q: str, n: int, region: list[str] | None = None,
              years: tuple[int, int] | None = None) -> list[dict[str, Any]]:
    qf = ["TYPE:TEXT"] + ([f"YEAR:[{years[0]} TO {min(years[1], 2100)}]"] if years else [])
    r = requests.get("https://api.europeana.eu/record/v2/search.json", timeout=_T, headers=_UA, params={
        "wskey": os.getenv("EUROPEANA_API_KEY") or "api2demo",
        "query": (f"{q} {region[0]}" if region else q) + (' NOT "natural history"' if re.search(r"histor", q, re.I) else ""),
        "rows": n, "qf": qf, "reusability": "open", "profile": "rich"})
    r.raise_for_status()
    out = []
    for d in r.json().get("items") or []:
        shown = _first(d.get("edmIsShownBy"))
        out.append({
            "id": str(d.get("id")), "title": _clean(_first(d.get("title"))), "source": "europeana",
            "authors": [_clean(c) for c in (d.get("dcCreator") or [])][:8], "year": _year(_first(d.get("year"))),
            "summary": _clean(" ".join(d.get("dcDescription") or []))[:2000],
            "url": _first(d.get("edmIsShownAt")) or str(d.get("guid") or "").split("?")[0],
            "pdfUrl": shown if shown.lower().split("?")[0].endswith(".pdf") else None,
            "venue": _first(d.get("dataProvider")) or "Europeana", "doi": None,
            "openAccess": True, "subjects": [], "kind": "document",
        })
    # Archive catalogues often hold placeholder titles like "- arkivdokument -".
    return [p for p in out if len(re.sub(r"[^\w]", "", p["title"])) >= 6 and not p["title"].startswith("-")]


HISTORY = {"internet_archive": internet_archive, "loc": loc, "europeana": europeana}
# Scholarly sources that also carry history journals and theses.
HISTORY_SCHOLARLY = ["openalex", "doaj", "zenodo", "core"]


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
    **HISTORY,
}

# Searched only in History & archives, never in "All sources".
EXTRA = set(HISTORY)

# How much a top result from each source counts when ranking the merged list.
WEIGHT = {"openalex": 1.0, "semantic_scholar": 1.0, "europepmc": 0.95, "arxiv": 0.9, "crossref": 0.8,
          "doaj": 0.85, "plos": 0.85, "core": 0.8, "zenodo": 0.6,
          "internet_archive": 1.0, "loc": 1.0, "europeana": 0.5}


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


def _cached(source: str, q: str, n: int, fetch: Callable | None = None, key: tuple = ()) -> list[dict[str, Any]]:
    fn = fetch or SOURCES[source]
    return discover.cached(("src", source, q, n, *key), lambda: fn(q, n))


def search_all(q: str, limit: int = 30, sort: str = "relevance", only: list[str] | None = None,
               open_access: bool = False, queries: dict[str, str] | None = None, per: int | None = None,
               fetchers: dict[str, Callable] | None = None, key: tuple = ()) -> dict[str, Any]:
    """Every source at once. Returns {papers, sources: {name: count or "error"}}."""
    names = [s for s in SOURCES if (s in only if only else s not in EXTRA)]
    per = per or max(6, min(15, limit // 2))
    results: dict[str, list[dict[str, Any]]] = {}
    status: dict[str, Any] = {}
    pool = cf.ThreadPoolExecutor(max_workers=len(names))
    futures = {pool.submit(_cached, s, (queries or {}).get(s, q), per, (fetchers or {}).get(s), key): s for s in names}
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


def search_history(q: str, limit: int = 30, sort: str = "relevance", open_access: bool = False,
                   per: int | None = None, region: str | None = None, written: str | None = None,
                   kind: str = "all") -> dict[str, Any]:
    """Digitised books and archives first, plus history scholarship.

    region: a REGIONS code. written: a WRITTEN code (when the source was written,
    so older periods mean primary sources). kind: all, books (archives only) or
    articles (journals only)."""
    reg = REGIONS.get(region or "")
    years = WRITTEN.get(written or "")
    archives = ({name: functools.partial(SOURCES[name], region=reg[1] if reg else None, years=years) for name in HISTORY}
                if reg or years else None)
    # Journals are modern: a period before 1950 means primary sources, so archives only.
    use_journals = kind != "books" and not (years and years[1] < 1950)
    names = ([] if kind == "articles" else list(HISTORY)) + (HISTORY_SCHOLARLY if use_journals else [])
    # Journals cover every field, so steer them to history; the archives are history already.
    scholarly = q if re.search(r"histor", q, re.I) else f"{q} history"
    if reg:
        scholarly = f"{scholarly} {reg[0]}"
    result = search_all(q, limit * 2, sort, names, open_access,
                        queries={s: scholarly for s in HISTORY_SCHOLARLY}, per=per,
                        fetchers=archives, key=(region or "", written or ""))
    # Keep journal results only when they're about what was asked (and the region).
    wanted = f"{q} {reg[0]}" if reg else q
    keep = {id(p) for p in _relevant(wanted, result["papers"])} if _words(wanted) else set()
    out, titles = [], set()
    for p in result["papers"]:
        t = re.sub(r"[^a-z0-9]", "", (p.get("title") or "").lower())[:80]
        if (p["source"] in HISTORY or id(p) in keep) and t not in titles:
            titles.add(t)
            out.append(p)
    result["papers"] = out[:limit]
    return result


# ── Paging ───────────────────────────────────────────────────────────

POOL_PER_SOURCE = 25   # each source answers in one call, so asking for 25 costs about the same as 10
POOL_MAX = 200


def search_pool(kind: str, q: str, sort: str = "relevance", only: list[str] | None = None,
                open_access: bool = False, history: dict[str, str] | None = None) -> dict[str, Any]:
    """One ranked list of everything the sources returned for this search,
    cached so "load more" pages come from the same order without asking again."""
    history = history or {}
    key = ("pool", kind, q, sort, tuple(only or ()), open_access, tuple(sorted(history.items())))
    box: dict[str, Any] = {}

    def fetch() -> list[dict[str, Any]]:
        if kind == "history":
            box["r"] = search_history(q, POOL_MAX, sort, open_access, per=POOL_PER_SOURCE,
                                      region=history.get("region"), written=history.get("written"),
                                      kind=history.get("kind") or "all")
        else:
            box["r"] = search_all(q, POOL_MAX, sort, only, open_access, per=POOL_PER_SOURCE)
        return [box["r"]] if box["r"]["papers"] else []

    hit = discover.cached(key, fetch)
    return hit[0] if hit else box.get("r", {"papers": [], "sources": {}})


def page(papers: list[dict[str, Any]], offset: int, limit: int, more_upstream: bool = False) -> dict[str, Any]:
    chunk = papers[offset:offset + limit]
    return {"papers": chunk, "offset": offset, "total": len(papers),
            "hasMore": offset + limit < len(papers) or (more_upstream and len(chunk) == limit)}


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
