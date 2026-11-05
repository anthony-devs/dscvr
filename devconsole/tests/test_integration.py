"""Runs the console's checks against the REAL DSCVR server started in-process.
Firestore, Firebase Auth and Claude are replaced by small fakes."""
import os
import sys
import threading
import types
from pathlib import Path
from unittest import mock

import pytest

SERVER = Path(__file__).resolve().parents[2] / "server"
pytestmark = pytest.mark.skipif(not (SERVER / "app.py").is_file(), reason="server folder not found")

DEV_SECRET = "q" * 40


class _Snap:
    def __init__(self, data):
        self._d = data

    @property
    def exists(self):
        return self._d is not None

    def to_dict(self):
        return dict(self._d) if self._d is not None else None


class _Doc:
    def __init__(self, db, path):
        self.db, self.path = db, path

    def get(self, **_):
        return _Snap(self.db.data.get(self.path))

    def set(self, data, merge=False):
        self.db.data[self.path] = {**(self.db.data.get(self.path) or {}), **data} if merge else dict(data)

    def delete(self):
        self.db.data.pop(self.path, None)


class _Col:
    def __init__(self, db, path):
        self.db, self.path = db, path

    def limit(self, _n):
        return self

    def stream(self):
        return iter([_Snap(v) for k, v in self.db.data.items() if k.rsplit("/", 1)[0] == self.path])


class FakeFirestore:
    def __init__(self):
        self.data = {"users/u1": {"displayName": "Ada"}}

    def document(self, path):
        return _Doc(self, path)

    def collection(self, path):
        return _Col(self, path)


@pytest.fixture(scope="module")
def live_server():
    sys.path.insert(0, str(SERVER))
    env = {"ADMIN_USERNAME": "founder-x", "ADMIN_PASSWORD": "Str0ng!Passphrase#1", "ADMIN_KEY": "k" * 24,
           "SESSION_SECRET": "s" * 40, "DEV_API_SECRET": DEV_SECRET, "ANTHROPIC_API_KEY": "test"}
    fake = FakeFirestore()
    fake_claude = types.SimpleNamespace(models=types.SimpleNamespace(list=lambda **_: []))
    patches = [mock.patch.dict(os.environ, env)]
    for p in patches:
        p.start()
    import ai
    import app as app_module
    import security
    more = [mock.patch.object(app_module, "init_firebase"), mock.patch.object(security, "get_firestore_client", return_value=fake),
            mock.patch("flags.get_firestore_client", return_value=fake), mock.patch("staff.get_firestore_client", return_value=fake),
            mock.patch("devapi.get_firestore_client", return_value=fake), mock.patch("migrations.get_firestore_client", return_value=fake), mock.patch.object(security, "verify_token", return_value=None),
            mock.patch.object(ai, "client", return_value=fake_claude)]
    for p in more:
        p.start()
    from werkzeug.serving import make_server

    srv = make_server("127.0.0.1", 0, app_module.create_app(), threaded=True)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{srv.server_port}"
    srv.shutdown()
    for p in more + patches:
        p.stop()
    sys.path.remove(str(SERVER))


def test_every_check_passes_against_a_healthy_server(live_server):
    from console.config import Target
    from console.smoke import run_smoke

    res = run_smoke(Target("it", live_server, DEV_SECRET))
    failed = [(c["name"], c["detail"]) for c in res["results"] if not c["ok"]]
    assert failed == [], failed
    assert res["passed"] >= 15


def test_a_wrong_secret_is_caught_by_the_checks(live_server):
    from console.config import Target
    from console.smoke import run_smoke

    res = run_smoke(Target("it", live_server, "w" * 40))
    bad = {c["name"] for c in res["results"] if not c["ok"]}
    assert "Signed developer link works" in bad and "Database can be read" in bad


def test_monitor_reads_diagnostics_and_flags_nothing_serious(live_server):
    from console.config import Config, Target
    from console.db import DB
    from console.monitor import Monitor

    t = Target("it", live_server, DEV_SECRET)
    db, sent = DB(":memory:"), []
    mon = Monitor(db, Config(targets=(t,)), notify=sent.append)
    r = mon.probe(t, deep=True)
    assert r["ok"] and not sent
    s = mon.summary(t)
    assert s["status"] == "up" and s["diag"]["metrics"] is not None
    assert not [p for p in s["problems"] if p["severity"] == "critical"], s["problems"]


def test_maintenance_round_trip(live_server):
    from console import serverapi
    from console.config import Target

    t = Target("it", live_server, DEV_SECRET)
    r = serverapi.signed(t, "POST", "/internal/dev/maintenance", {"on": True, "scope": "ai", "message": "Deploying", "by": "dev"})
    assert r.ok and r.data["on"] is True and r.data["scope"] == "ai"
    blocked = serverapi.plain(t, "POST", "/pinda", json={})
    assert blocked.status == 503 and blocked.data["error"] == "Deploying"
    assert serverapi.signed(t, "POST", "/internal/dev/maintenance", {"on": False, "by": "dev"}).data["on"] is False
