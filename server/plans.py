"""Plans and the AI usage meter.

Every AI call costs real money, so each plan gets a usage budget measured in
what the call actually cost (tokens x model price), like Claude's own usage
limits. There is a daily budget (resets at midnight UTC) and a monthly one
(resets on the 1st). Users see a percentage, never dollars.

    Plan            Price/mo   Chat model   Daily   Monthly   (our AI cost, USD)
    free            0          fast         0.10    1.50
    student_plus    4.99       fast         0.50    2.50      5x Free per day
    research_plus   9.99       best*        1.00    5.00      10x Free per day
    max             24.99      best         3.00    12.50     30x Free per day
    enterprise      metered    best         none    none      billed per use (orgs.py)

    * Research Plus chats on the fast model and uses the best model for
      reports, recaps and fact-checks, where quality matters most.

Every number can be changed with environment variables, e.g.
PLAN_STUDENT_PLUS_PRICE_USD, PLAN_MAX_MONTHLY_USD, AI_FAST_INPUT_PER_M_USD.
"""
from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from typing import Any


def _f(name: str, default: float) -> float:
    try:
        return float(os.getenv(name, default))
    except ValueError:
        return default


BEST_MODEL = os.getenv("PINDA_MODEL", "claude-sonnet-5-5")
FAST_MODEL = os.getenv("PINDA_FAST_MODEL", "claude-haiku-5-5")

# What Anthropic charges per million tokens. Check these against your
# Anthropic billing page and set them on the server if they differ.
RATES = {
    "fast": (_f("AI_FAST_INPUT_PER_M_USD", 1.0), _f("AI_FAST_OUTPUT_PER_M_USD", 5.0)),
    "best": (_f("ANTHROPIC_INPUT_PER_M_USD", 2.0), _f("ANTHROPIC_OUTPUT_PER_M_USD", 10.0)),  # Claude Sonnet 5.5
}

PAID = ("student_plus", "research_plus", "max")


def _plan(pid: str, label: str, price: float, daily: float, monthly: float, chat: str, heavy: str, x: int) -> dict[str, Any]:
    key = pid.upper()
    return {
        "id": pid, "label": label,
        "priceUsd": _f(f"PLAN_{key}_PRICE_USD", price),
        "dailyUsd": _f(f"PLAN_{key}_DAILY_USD", daily),
        "monthlyUsd": _f(f"PLAN_{key}_MONTHLY_USD", monthly),
        "chatModel": chat, "heavyModel": heavy, "multiplier": x,
    }


PLANS: dict[str, dict[str, Any]] = {
    "free": _plan("free", "Free", 0, 0.10, 1.50, "fast", "fast", 1),
    "student_plus": _plan("student_plus", "Student Plus", 4.99, 0.50, 2.50, "fast", "fast", 5),
    "research_plus": _plan("research_plus", "Research Plus", 9.99, 1.00, 5.00, "fast", "best", 10),
    "max": _plan("max", "DSCVR Max", 24.99, 3.00, 12.50, "best", "best", 30),
}


def public_plans() -> list[dict[str, Any]]:
    return [{k: p[k] for k in ("id", "label", "priceUsd", "multiplier")} | {"bestModel": p["heavyModel"] == "best"}
            for p in PLANS.values()]


def plan_of(profile: dict[str, Any]) -> str:
    """The plan a user is on right now. Lapsed or cancelled plans fall back to free
    once the paid period ends."""
    if profile.get("orgId"):
        return "enterprise"
    pid = profile.get("plan") or "free"
    if pid not in PLANS:
        return "free"
    if pid != "free":
        status = profile.get("planStatus")
        ends = profile.get("planEndsAt")
        if hasattr(ends, "timestamp"):
            ends = ends.timestamp()
        grace = 3 * 86400  # keep access for 3 days while a renewal retries
        if status in ("cancelled", "past_due") and isinstance(ends, (int, float)) and datetime.now(timezone.utc).timestamp() > ends + (grace if status == "past_due" else 0):
            return "free"
    return pid


def model_for(plan: str, kind: str) -> str:
    """kind is "chat" (Pinda, voice) or "heavy" (reports, recaps, fact-checks)."""
    if plan == "enterprise":
        return BEST_MODEL
    p = PLANS.get(plan, PLANS["free"])
    tier = p["chatModel"] if kind == "chat" else p["heavyModel"]
    return BEST_MODEL if tier == "best" else FAST_MODEL


def cost_usd(model: str, input_tokens: int, output_tokens: int) -> float:
    rate_in, rate_out = RATES["best" if model == BEST_MODEL and BEST_MODEL != FAST_MODEL else "fast"]
    return input_tokens / 1e6 * rate_in + output_tokens / 1e6 * rate_out


def budgets(plan: str, free_daily_override: float | None = None) -> tuple[float, float] | None:
    if plan == "enterprise":
        return None
    p = PLANS.get(plan, PLANS["free"])
    daily = p["dailyUsd"]
    if plan == "free" and free_daily_override is not None:
        daily = free_daily_override
    return daily, p["monthlyUsd"]


def resets() -> tuple[datetime, datetime]:
    now = datetime.now(timezone.utc)
    day = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
    month = (now.replace(day=28) + timedelta(days=4)).replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    return day, month


def until(when: datetime) -> str:
    secs = max(0, int((when - datetime.now(timezone.utc)).total_seconds()))
    if secs >= 86400:
        return f"{secs // 86400} day{'s' if secs >= 172800 else ''}"
    h, m = secs // 3600, (secs % 3600) // 60
    return f"{h}h {m}m" if h else f"{m}m"
