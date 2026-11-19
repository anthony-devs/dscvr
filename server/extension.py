"""The DSCVR browser extension.

The extension signs in through the web app: on app.askpinda.com/connect-extension
the signed-in user asks for an extension token (POST /extension/token), and the
page hands it to the extension. Tokens look like "dx_..." and work as Bearer
tokens on every endpoint. Only a SHA-256 hash is stored, at
extension_tokens/{hash}, so a leaked database can't be replayed. Tokens last
TOKEN_DAYS and can be revoked from the extension (Sign out) or by deleting the
account.
"""
from __future__ import annotations

import hashlib
import os
import re
import secrets
import time
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import urlparse

from security import get_firestore_client

PREFIX = "dx_"
TOKEN_DAYS = 180
MAX_TOKENS_PER_USER = 10
_CACHE: dict[str, tuple[float, dict[str, Any] | None]] = {}
_CACHE_SECONDS = 60

KINDS = {"paper", "link", "youtube"}
PAGE_TEXT_MAX = 60_000


class ExtensionError(Exception):
    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.status = status


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def is_extension_token(token: str) -> bool:
    return token.startswith(PREFIX)


# ── Tokens ───────────────────────────────────────────────────────────

def issue(uid: str, email: str | None, email_verified: bool, agent: str = "", db=None) -> str:
    db = db or get_firestore_client()
    col = db.collection("extension_tokens")
    # Keep a user's connected browsers to a sensible number: drop the oldest.
    mine = sorted(col.where("uid", "==", uid).get(), key=lambda s: _ts((s.to_dict() or {}).get("createdAt")))
    for old in mine[: max(0, len(mine) - (MAX_TOKENS_PER_USER - 1))]:
        old.reference.delete()
    token = PREFIX + secrets.token_urlsafe(32)
    col.document(_hash(token)).set({
        "uid": uid, "email": email or "", "emailVerified": bool(email_verified),
        "createdAt": _now(), "expiresAt": _now() + timedelta(days=TOKEN_DAYS),
        "agent": (agent or "")[:200],
    })
    return token


def _ts(v: Any) -> float:
    if v is None:
        return 0.0
    return v.timestamp() if hasattr(v, "timestamp") else float(v)


def claims(token: str, db=None) -> dict[str, Any] | None:
    """Claims for an extension token (like a Firebase ID token's), or None."""
    if not is_extension_token(token) or len(token) > 100:
        return None
    key = _hash(token)
    hit = _CACHE.get(key)
    if hit and time.monotonic() - hit[0] < _CACHE_SECONDS:
        return hit[1]
    db = db or get_firestore_client()
    snap = db.collection("extension_tokens").document(key).get()
    d = snap.to_dict() if snap.exists else None
    out = None
    if d and _ts(d.get("expiresAt")) > _now().timestamp():
        out = {"uid": d["uid"], "email": d.get("email") or None, "email_verified": bool(d.get("emailVerified")),
               "extension": True}
    _CACHE[key] = (time.monotonic(), out)
    return out


def revoke(token: str, db=None) -> None:
    db = db or get_firestore_client()
    key = _hash(token)
    db.collection("extension_tokens").document(key).delete()
    _CACHE.pop(key, None)


def revoke_all(uid: str, db=None) -> int:
    db = db or get_firestore_client()
    n = 0
    for s in db.collection("extension_tokens").where("uid", "==", uid).get():
        s.reference.delete()
        n += 1
    _CACHE.clear()
    return n


# ── Library ──────────────────────────────────────────────────────────

def library(uid: str, db=None) -> dict[str, Any]:
    db = db or get_firestore_client()
    user = db.document(f"users/{uid}")
    cats = [{"id": s.id, "name": (s.to_dict() or {}).get("name") or "Untitled",
             "order": (s.to_dict() or {}).get("order") or 0} for s in user.collection("categories").get()]
    cats.sort(key=lambda c: c["order"])
    topics = [{"id": s.id, "name": (s.to_dict() or {}).get("name") or "Untitled",
               "categoryId": (s.to_dict() or {}).get("categoryId") or ""} for s in user.collection("topics").get()]
    topics.sort(key=lambda t: t["name"].lower())
    return {"categories": [{"id": c["id"], "name": c["name"]} for c in cats], "topics": topics}


def _str(v: Any, n: int) -> str:
    return re.sub(r"\s+", " ", str(v or "")).strip()[:n]


def _url(v: Any) -> str | None:
    s = str(v or "").strip()[:2000]
    p = urlparse(s)
    return s if p.scheme in ("http", "https") and p.netloc else None


def save(uid: str, data: dict[str, Any], db=None) -> dict[str, Any]:
    """Saves the page the user is on as a library item. Returns {id, existing}."""
    db = db or get_firestore_client()
    user = db.document(f"users/{uid}")
    title = _str(data.get("title"), 400)
    url = _url(data.get("url"))
    if not title or not url:
        raise ExtensionError("This page has no title or address to save.")
    kind = data.get("kind") if data.get("kind") in KINDS else "link"

    materials = user.collection("materials")
    for s in materials.where("url", "==", url).limit(1).get():
        return {"id": s.id, "existing": True, "categoryId": (s.to_dict() or {}).get("categoryId")}

    category_id = _str(data.get("categoryId"), 64)
    topic_id = _str(data.get("topicId"), 64) or None
    now = _now()
    if not category_id or not user.collection("categories").document(category_id).get().exists:
        # No category yet (or it was deleted): file it under "Saved from the web".
        existing = list(user.collection("categories").where("name", "==", "Saved from the web").limit(1).get())
        if existing:
            category_id = existing[0].id
        else:
            ref = user.collection("categories").document()
            ref.set({"name": "Saved from the web", "description": "Pages saved with the DSCVR extension.",
                     "colorIndex": 3, "order": int(now.timestamp() * 1000), "createdAt": now, "updatedAt": now})
            category_id = ref.id
        topic_id = None
    if topic_id:
        t = user.collection("topics").document(topic_id).get()
        if not t.exists or (t.to_dict() or {}).get("categoryId") != category_id:
            topic_id = None

    authors = [a for a in (_str(x, 120) for x in (data.get("authors") or [])[:40]) if a]
    year = data.get("year")
    year = int(year) if isinstance(year, (int, float)) or (isinstance(year, str) and year.isdigit()) else None
    if year is not None and not 1400 <= year <= now.year + 1:
        year = None
    source = _str(data.get("source"), 40) or None
    doc = {
        "kind": kind, "title": title, "categoryId": category_id, "topicId": topic_id,
        "authors": authors, "year": year, "url": url, "pdfUrl": _url(data.get("pdfUrl")),
        "storagePath": None, "fileName": None,
        "summary": _str(data.get("summary"), 4000),
        "content": str(data.get("content") or "")[:PAGE_TEXT_MAX] if kind == "link" else "",
        "thumbnailUrl": _url(data.get("thumbnailUrl")), "siteName": _str(data.get("siteName"), 120) or None,
        "source": source, "externalId": _str(data.get("externalId"), 120) or None,
        "doi": _str(data.get("doi"), 200) or None,
        "progress": 0, "noteCount": 0, "colorIndex": 0, "inReadingList": bool(data.get("readingList")),
        "rating": 0, "createdAt": now, "updatedAt": now, "lastOpenedAt": None, "savedFrom": "extension",
    }
    ref = materials.document()
    ref.set(doc)
    return {"id": ref.id, "existing": False, "categoryId": category_id}


def app_url() -> str:
    return os.getenv("APP_URL", "https://app.askpinda.com").rstrip("/")


# ── Pinda on the current page ────────────────────────────────────────

def page_context(page: dict[str, Any], pdf_block=None) -> list[dict[str, Any]]:
    """Context blocks for questions about the page open in the browser."""
    title = (_str(page.get("title"), 300) or "Untitled page").replace('"', "'")
    url = _url(page.get("url")) or ""
    text = str(page.get("text") or "")[:PAGE_TEXT_MAX]
    selection = str(page.get("selection") or "")[:8000].strip()
    blocks: list[dict[str, Any]] = []
    if pdf_block:
        blocks.append(pdf_block)
    parts = [f'<page title="{title}" url="{url}">',
             "The user is reading this page in their browser and is asking about it."]
    if text:
        parts.append(text)
    elif not pdf_block:
        parts.append("(The page's text couldn't be read. Say so if the question needs it.)")
    parts.append("</page>")
    if selection:
        parts.append(f"<selection>\nThe user highlighted this part:\n{selection}\n</selection>")
    blocks.append({"type": "text", "text": "\n".join(parts), "cache_control": {"type": "ephemeral"}})
    return blocks
