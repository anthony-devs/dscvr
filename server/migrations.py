"""Versioned data migrations, run from the developer console.

Each migration is safe to repeat: it only changes documents that still need it.
A dry run counts what would change and writes nothing. Applied migrations are
recorded in meta/migrations.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Callable

from security import get_firestore_client

BATCH = 400


def _db():
    return get_firestore_client()


def _commit(updates: list[tuple[Any, dict]], apply: bool) -> int:
    if apply:
        db = _db()
        for i in range(0, len(updates), BATCH):
            batch = db.batch()
            for ref, data in updates[i:i + BATCH]:
                batch.set(ref, data, merge=True)
            batch.commit()
    return len(updates)


def backfill_edition(apply: bool) -> dict:
    """Users created before editions existed get one: enterprise if in an org, students if their role says so, else researchers."""
    updates, scanned = [], 0
    for snap in _db().collection("users").stream():
        scanned += 1
        d = snap.to_dict() or {}
        if d.get("orgId"):
            want = "enterprise"
        elif d.get("edition") in ("students", "researchers"):
            continue
        else:
            want = "students" if "student" in str(d.get("role") or "").lower() else "researchers"
        if d.get("edition") != want:
            updates.append((snap.reference, {"edition": want}))
    return {"scanned": scanned, "changed": _commit(updates, apply)}


def recount_ratings(apply: bool) -> dict:
    """Rebuilds each paper's rating total and count from the individual ratings."""
    updates, scanned = [], 0
    for paper in _db().collection("papers").stream():
        scanned += 1
        stars = [int((r.to_dict() or {}).get("stars") or 0) for r in paper.reference.collection("ratings").stream()]
        stars = [s for s in stars if 1 <= s <= 5]
        agg = paper.to_dict() or {}
        if int(agg.get("sum") or 0) != sum(stars) or int(agg.get("count") or 0) != len(stars):
            updates.append((paper.reference, {"sum": sum(stars), "count": len(stars)}))
    return {"scanned": scanned, "changed": _commit(updates, apply)}


def tag_rating_owners(apply: bool) -> dict:
    """Ratings made before they carried a uid get one (the document id), so account deletion can find them."""
    updates, scanned = [], 0
    for snap in _db().collection_group("ratings").stream():
        scanned += 1
        if not (snap.to_dict() or {}).get("uid"):
            updates.append((snap.reference, {"uid": snap.id}))
    return {"scanned": scanned, "changed": _commit(updates, apply)}


MIGRATIONS: list[tuple[str, str, Callable[[bool], dict]]] = [
    ("2026-11-backfill-edition", "Give every existing user an edition (Students, Researchers or Enterprise).", backfill_edition),
    ("2026-11-recount-ratings", "Recount community paper ratings from the individual ratings.", recount_ratings),
    ("2026-11-tag-rating-owners", "Record who made each rating so deleted accounts take their ratings with them.", tag_rating_owners),
]


def _ledger() -> dict:
    return _db().document("meta/migrations").get().to_dict() or {}


def status() -> list[dict]:
    done = _ledger()
    out = []
    for mid, desc, _fn in MIGRATIONS:
        rec = done.get(mid) or {}
        at = rec.get("appliedAt")
        out.append({"id": mid, "description": desc, "applied": bool(rec),
                    "appliedAt": at.isoformat() if hasattr(at, "isoformat") else at, "by": rec.get("by"), "result": rec.get("result")})
    return out


def run(apply: bool, by: str) -> list[dict]:
    done = _ledger()
    report = []
    for mid, _desc, fn in MIGRATIONS:
        if mid in done:
            continue
        result = fn(apply)
        report.append({"id": mid, "result": result})
        if apply:
            _db().document("meta/migrations").set(
                {mid: {"appliedAt": datetime.now(timezone.utc), "by": by[:40], "result": result}}, merge=True)
    return report
