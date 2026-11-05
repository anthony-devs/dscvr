"""Switches the founder and developer can flip without a deploy.

Stored in Firestore at config/flags and cached for a few seconds, so a change
reaches every worker within ~15 s. If the database can't be reached, a change
still applies to this worker (``shared: False``).
"""
from __future__ import annotations

import time
from datetime import datetime, timezone
from typing import Any

from security import get_firestore_client

CACHE_SECONDS = 15
DEFAULTS: dict[str, Any] = {
    "maintenance": {"on": False, "scope": "all", "message": ""},
    "aiPaused": False,
    "aiPausedMessage": "Pinda is taking a short break. Please try again soon.",
    "freeDailyAi": None,  # None = use FREE_DAILY_AI from the environment
}

_cache: tuple[float, dict[str, Any]] | None = None
_local: dict[str, Any] = {}


def _merge(doc: dict[str, Any]) -> dict[str, Any]:
    out = {**DEFAULTS, **{k: v for k, v in doc.items() if k in DEFAULTS}}
    out.update(_local)
    return out


def get(fresh: bool = False) -> dict[str, Any]:
    global _cache
    if _cache and not fresh and time.monotonic() - _cache[0] < CACHE_SECONDS:
        return _cache[1]
    try:
        doc = get_firestore_client().document("config/flags").get().to_dict() or {}
        _local.clear()
    except Exception:  # noqa: BLE001
        doc = (_cache[1] if _cache else {})
    value = _merge(doc)
    _cache = (time.monotonic(), value)
    return value


def update(fields: dict[str, Any], by: str) -> dict[str, Any]:
    global _cache
    fields = {k: v for k, v in fields.items() if k in DEFAULTS}
    shared = True
    try:
        get_firestore_client().document("config/flags").set(
            {**fields, "updatedBy": by[:40], "updatedAt": datetime.now(timezone.utc)}, merge=True)
    except Exception:  # noqa: BLE001
        shared = False
        _local.update(fields)
    _cache = None
    out = get(fresh=True) if shared else _merge({**(get()), **fields})
    return {**out, "shared": shared}


def maintenance() -> dict[str, Any] | None:
    m = get().get("maintenance") or {}
    return m if m.get("on") else None


def set_maintenance(on: bool, scope: str, message: str, by: str) -> dict[str, Any]:
    scope = scope if scope in ("all", "ai") else "all"
    doc = {"on": bool(on), "scope": scope, "message": (message or "").strip()[:200], "by": by[:40]}
    out = update({"maintenance": doc}, by)
    return {**doc, "shared": out["shared"]}


def ai_block_message() -> str | None:
    """Why AI requests are refused right now, or None."""
    f = get()
    m = f.get("maintenance") or {}
    if m.get("on"):
        return m.get("message") or "DSCVR is being updated. Back shortly."
    if f.get("aiPaused"):
        return f.get("aiPausedMessage") or DEFAULTS["aiPausedMessage"]
    return None


def free_daily_ai(default: int) -> int:
    v = get().get("freeDailyAi")
    return int(v) if isinstance(v, (int, float)) and v >= 0 else default
