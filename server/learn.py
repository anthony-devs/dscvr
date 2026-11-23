"""Free textbooks, course notes and open books, for the everyday topics research search skips.

Someone studying databases, calculus or macroeconomics wants a textbook or a
good set of notes first, not a 2024 preprint. These sources answer that:

    open_textbooks  Open Textbook Library (University of Minnesota): peer-reviewed free textbooks
    openstax        OpenStax: free college textbooks from Rice University
    wikibooks       Wikibooks: open textbooks and study guides, one page per topic
    openlibrary     Open Library: public-domain books with a free scan (only when searched on its own)
"""
from __future__ import annotations

import re
import threading
import time
from typing import Any

import requests

_UA = {"User-Agent": "DSCVR/1.1 (research library; mailto:hello@askpinda.com)"}
_T = 7


def _clean(t: str | None) -> str:
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", t or "")).strip()


def _year(v: Any) -> int | None:
    m = re.search(r"(1[4-9]|20)\d{2}", str(v or ""))
    return int(m.group(0)) if m else None


def open_textbooks(q: str, n: int) -> list[dict[str, Any]]:
    r = requests.get("https://open.umn.edu/opentextbooks/textbooks.json", params={"q": q}, timeout=_T, headers=_UA)
    r.raise_for_status()
    out = []
    for b in (r.json().get("data") or [])[:n]:
        title = _clean(b.get("title"))
        if not title:
            continue
        formats = b.get("formats") or []
        free = [f for f in formats if ((f.get("price") or {}).get("cents") or 0) == 0 and f.get("url")]
        pdf = next((f["url"] for f in free if "pdf" in str(f.get("type", "")).lower() and f["url"].lower().split("?")[0].endswith(".pdf")), None)
        online = next((f["url"] for f in free if str(f.get("type", "")).lower() == "online"), None)
        authors = []
        for c in b.get("contributors") or []:
            name = " ".join(x for x in (c.get("first_name"), c.get("last_name")) if x).strip()
            if name:
                authors.append(name)
        out.append({
            "id": f"otl-{b.get('id')}", "title": title, "source": "open_textbooks", "authors": authors[:8],
            "year": b.get("copyright_year") if isinstance(b.get("copyright_year"), int) else _year(b.get("copyright_year")),
            "summary": _clean(b.get("description"))[:1200], "url": online or b.get("url"), "pdfUrl": pdf,
            "venue": "Open Textbook Library", "doi": None, "openAccess": True, "kind": "textbook",
            "subjects": [s.get("name") for s in (b.get("subjects") or []) if s.get("name")][:4],
        })
    return out


_OPENSTAX: dict[str, Any] = {"at": 0.0, "books": []}
_OPENSTAX_LOCK = threading.Lock()


def _openstax_catalog() -> list[dict[str, Any]]:
    with _OPENSTAX_LOCK:
        if _OPENSTAX["books"] and time.time() - _OPENSTAX["at"] < 86400:
            return _OPENSTAX["books"]
    r = requests.get("https://openstax.org/apps/cms/api/v2/pages/", timeout=_T, headers=_UA, params={
        "type": "books.Book", "limit": 200, "locale": "en",
        "fields": "title,description,book_state,webview_rex_link,high_resolution_pdf_url,publish_date"})
    r.raise_for_status()
    books = [b for b in r.json().get("items") or [] if b.get("book_state") == "live"]
    with _OPENSTAX_LOCK:
        _OPENSTAX.update(at=time.time(), books=books)
    return books


def openstax(q: str, n: int) -> list[dict[str, Any]]:
    words = [w for w in re.findall(r"[^\W_]+", q.lower()) if len(w) > 2]
    if not words:
        return []
    scored = []
    for b in _openstax_catalog():
        title, desc = (b.get("title") or "").lower(), _clean(b.get("description")).lower()
        s = sum(2 for w in words if w in title) + sum(1 for w in words if w in desc)
        if s >= 2 and sum(w in title or w in desc for w in words) >= max(1, len(words) * 0.6):
            scored.append((s, b))
    scored.sort(key=lambda x: -x[0])
    out = []
    for _, b in scored[:n]:
        out.append({
            "id": f"openstax-{b.get('id')}", "title": _clean(b.get("title")), "source": "openstax",
            "authors": ["OpenStax"], "year": _year(b.get("publish_date")),
            "summary": _clean(b.get("description"))[:1200],
            "url": b.get("webview_rex_link") or (b.get("meta") or {}).get("html_url"),
            "pdfUrl": b.get("high_resolution_pdf_url") or None,
            "venue": "OpenStax", "doi": None, "openAccess": True, "kind": "textbook", "subjects": [],
        })
    return out


def wikibooks(q: str, n: int) -> list[dict[str, Any]]:
    r = requests.get("https://en.wikibooks.org/w/api.php", timeout=_T, headers=_UA, params={
        "action": "query", "list": "search", "srsearch": q, "srnamespace": 0, "srlimit": min(n * 3, 50),
        "srprop": "snippet|wordcount", "format": "json"})
    r.raise_for_status()
    out, per_book = [], {}
    for h in (r.json().get("query") or {}).get("search") or []:
        title = h.get("title") or ""
        root = title.split("/")[0]
        if per_book.get(root, 0) >= 2 or (h.get("wordcount") or 0) < 120 or "printable version" in title.lower():
            continue
        per_book[root] = per_book.get(root, 0) + 1
        out.append({
            "id": f"wikibooks-{h.get('pageid')}", "title": title.replace("/", ": ", 1).replace("/", " › "),
            "source": "wikibooks", "authors": ["Wikibooks contributors"], "year": None,
            "summary": _clean(h.get("snippet")), "url": "https://en.wikibooks.org/wiki/" + requests.utils.quote(title.replace(" ", "_")),
            "pdfUrl": None, "venue": f"Wikibooks · {root}" if "/" in title else "Wikibooks", "doi": None,
            "openAccess": True, "kind": "study guide", "subjects": [],
        })
        if len(out) >= n:
            break
    return out


def openlibrary(q: str, n: int) -> list[dict[str, Any]]:
    r = requests.get("https://openlibrary.org/search.json", timeout=_T, headers=_UA, params={
        "q": q, "has_fulltext": "true", "limit": n * 3,
        "fields": "key,title,author_name,first_publish_year,ia,ebook_access,subject"})
    r.raise_for_status()
    out = []
    for d in r.json().get("docs") or []:
        ia = (d.get("ia") or [None])[0]
        if d.get("ebook_access") != "public" or not ia:
            continue
        out.append({
            "id": f"ol-{ia}", "title": _clean(d.get("title")), "source": "openlibrary",
            "authors": (d.get("author_name") or [])[:6], "year": d.get("first_publish_year"), "summary": "",
            "url": f"https://archive.org/details/{ia}", "pdfUrl": f"https://archive.org/download/{ia}/{ia}.pdf",
            "venue": "Open Library", "doi": None, "openAccess": True, "kind": "book",
            "subjects": (d.get("subject") or [])[:4],
        })
        if len(out) >= n:
            break
    return [p for p in out if p["title"]]
