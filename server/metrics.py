"""In-process request metrics for the developer console.

Each worker keeps its own numbers (requests, latency, recent errors and error
groups) in memory. Nothing here touches Firestore, so watching costs nothing.
"""
from __future__ import annotations

import hashlib
import threading
import time
import traceback
from collections import deque


def is_quota(exc: BaseException) -> bool:
    text = f"{type(exc).__name__} {exc}".lower()
    return "resourceexhausted" in text or "quota" in text or "429" in text


class Metrics:
    def __init__(self) -> None:
        self.started = time.time()
        self._lock = threading.Lock()
        self.requests: deque = deque(maxlen=20000)  # (at, ms, status, path)
        self.errors: deque = deque(maxlen=100)
        self.groups: dict[str, dict] = {}
        self.quota_errors = 0
        self.ai_calls = 0
        self.ai_failures = 0

    def record(self, path: str, status: int, ms: float) -> None:
        with self._lock:
            self.requests.append((time.time(), ms, status, path))

    def error(self, exc: BaseException, path: str) -> None:
        quota = is_quota(exc)
        kind = type(exc).__name__
        message = str(exc)[:300]
        fp = hashlib.sha1(f"{kind}|{path}|{message[:80]}".encode()).hexdigest()[:16]
        now = time.time()
        with self._lock:
            if quota:
                self.quota_errors += 1
            self.errors.append({
                "at": now, "type": kind, "message": message, "path": path, "quota": quota,
                "trace": "".join(traceback.format_exception(type(exc), exc, exc.__traceback__))[-4000:],
            })
            g = self.groups.get(fp)
            if g is None:
                if len(self.groups) > 500:
                    self.groups.clear()
                g = self.groups[fp] = {"fingerprint": fp, "kind": kind, "message": message, "path": path,
                                       "count": 0, "firstSeenAt": now, "status": "open", "source": "server"}
            g["count"] += 1
            g["lastSeenAt"] = now

    def ai(self, ok: bool) -> None:
        with self._lock:
            self.ai_calls += 1
            if not ok:
                self.ai_failures += 1

    def snapshot(self, window: float = 300) -> dict:
        cutoff = time.time() - window
        with self._lock:
            rows = [r for r in self.requests if r[0] >= cutoff]
            quota, calls, fails = self.quota_errors, self.ai_calls, self.ai_failures
        times = sorted(r[1] for r in rows)
        failed = sum(1 for r in rows if r[2] >= 500)

        def pct(p: float) -> float:
            return round(times[min(len(times) - 1, int(len(times) * p))], 1) if times else 0.0

        return {
            "windowSeconds": window, "requests": len(rows), "errors": failed,
            "errorRate": round(failed / len(rows), 4) if rows else 0.0,
            "p50": pct(0.5), "p95": pct(0.95), "quotaErrors": quota, "flushFailures": 0,
            "aiCalls": calls, "aiFailures": fails, "uptimeSeconds": round(time.time() - self.started),
        }

    def error_groups(self) -> list[dict]:
        with self._lock:
            rows = [dict(g) for g in self.groups.values()]
        rows.sort(key=lambda g: g["lastSeenAt"], reverse=True)
        for g in rows:
            g["lastSeenAt"] = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(g["lastSeenAt"])) + "Z"
        return rows


metrics = Metrics()
