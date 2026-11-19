"""Browser extension: tokens, scoped access, saving pages, Pinda on a page."""
from __future__ import annotations

import os
import sys
from unittest import mock

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
os.environ.setdefault("FIREBASE_PROJECT_ID", "test")

import extension  # noqa: E402
import orgs  # noqa: E402
import security  # noqa: E402


# ── A tiny in-memory Firestore ───────────────────────────────────────

class Snap:
    def __init__(self, ref, data):
        self.reference, self.id, self._d = ref, ref.id, data

    @property
    def exists(self):
        return self._d is not None

    def to_dict(self):
        return None if self._d is None else dict(self._d)


class Ref:
    def __init__(self, db, path):
        self.db, self.path, self.id = db, path, path.rsplit("/", 1)[-1]

    def get(self, **_):
        return Snap(self, self.db.data.get(self.path))

    def set(self, data, merge=False):
        self.db.data[self.path] = {**(self.db.data.get(self.path) or {}), **data} if merge else dict(data)

    def delete(self):
        self.db.data.pop(self.path, None)

    def collection(self, name):
        return Col(self.db, f"{self.path}/{name}")


class Col:
    def __init__(self, db, path, filters=(), n=None):
        self.db, self.path, self.filters, self.n = db, path, filters, n

    def document(self, doc_id=None):
        self.db.counter += 1
        return Ref(self.db, f"{self.path}/{doc_id or f'id{self.db.counter}'}")

    def where(self, field, op, value):
        return Col(self.db, self.path, (*self.filters, (field, value)), self.n)

    def limit(self, n):
        return Col(self.db, self.path, self.filters, n)

    def get(self):
        depth = self.path.count("/") + 1
        out = [Snap(Ref(self.db, p), d) for p, d in self.db.data.items()
               if p.startswith(self.path + "/") and p.count("/") == depth
               and all(d.get(f) == v for f, v in self.filters)]
        return out[: self.n] if self.n else out


class MemDB:
    def __init__(self):
        self.data, self.counter = {}, 0

    def collection(self, name):
        return Col(self, name)

    def document(self, path):
        return Ref(self, path)


@pytest.fixture()
def db():
    d = MemDB()
    extension._CACHE.clear()
    with mock.patch.object(extension, "get_firestore_client", return_value=d):
        yield d


# ── Tokens ───────────────────────────────────────────────────────────

def test_tokens_are_hashed_checked_and_revocable(db):
    token = extension.issue("u1", "a@b.com", True, "Chrome")
    assert token.startswith("dx_") and len(token) > 40
    stored = db.data[f"extension_tokens/{extension._hash(token)}"]
    assert stored["uid"] == "u1" and token not in str(stored)
    assert extension.claims(token) == {"uid": "u1", "email": "a@b.com", "email_verified": True, "extension": True}
    assert extension.claims("dx_wrong") is None
    extension.revoke(token)
    assert extension.claims(token) is None


def test_expired_tokens_fail_and_old_ones_are_trimmed(db):
    token = extension.issue("u1", None, False)
    db.data[f"extension_tokens/{extension._hash(token)}"]["expiresAt"] = 0
    extension._CACHE.clear()
    assert extension.claims(token) is None
    for _ in range(extension.MAX_TOKENS_PER_USER + 3):
        extension.issue("u1", None, False)
    assert len([k for k in db.data if k.startswith("extension_tokens/")]) == extension.MAX_TOKENS_PER_USER


# ── Routes ───────────────────────────────────────────────────────────

@pytest.fixture()
def app_client(db):
    with mock.patch("app.init_firebase"):
        import app as app_module
        flask_app = app_module.create_app()
    flask_app.testing = True
    with mock.patch.object(orgs, "user_profile", return_value={"displayName": "Ada Lovelace"}), \
         mock.patch.object(orgs, "check_allowance", return_value=None), \
         mock.patch.object(orgs, "record_usage"), mock.patch("app.log_usage"):
        yield flask_app.test_client()


def firebase_user(uid="u1"):
    real = security.verify_token
    return mock.patch("security.verify_token",
                      side_effect=lambda t: real(t) if t.startswith("dx_") else {"uid": uid, "email": "a@b.com", "email_verified": True})


def test_connect_then_use_token_only_where_allowed(app_client, db):
    with firebase_user():
        r = app_client.post("/extension/token", headers={"Authorization": "Bearer firebase"})
        assert r.status_code == 200
        token = r.get_json()["token"]
        ext = {"Authorization": f"Bearer {token}"}
        # An extension token can't mint more tokens or reach account-level endpoints.
        assert app_client.post("/extension/token", headers=ext).status_code == 403
        assert app_client.post("/account/delete", headers=ext).status_code == 403
        assert app_client.get("/orgs/me", headers=ext).status_code == 403
        db.data["users/u1/categories/c1"] = {"name": "Thesis", "order": 1}
        db.data["users/u1/topics/t1"] = {"name": "Methods", "categoryId": "c1"}
        me = app_client.get("/extension/me", headers=ext).get_json()
        assert me["uid"] == "u1" and me["categories"] == [{"id": "c1", "name": "Thesis"}]
        assert me["topics"][0]["id"] == "t1"
        assert app_client.post("/extension/signout", headers=ext).status_code == 200
        assert app_client.get("/extension/me", headers=ext).status_code == 401


def test_save_page_creates_item_once(app_client, db):
    db.data["users/u1/categories/c1"] = {"name": "Thesis"}
    db.data["users/u1/topics/t1"] = {"name": "Methods", "categoryId": "c1"}
    page = {"title": "Attention Is All You Need", "url": "https://arxiv.org/abs/1706.03762", "kind": "paper",
            "authors": ["Ashish Vaswani", "Noam Shazeer"], "year": 2017, "pdfUrl": "https://arxiv.org/pdf/1706.03762",
            "source": "arxiv", "externalId": "1706.03762", "categoryId": "c1", "topicId": "t1",
            "content": "should not be stored for papers"}
    with firebase_user():
        r = app_client.post("/extension/save", json=page, headers={"Authorization": "Bearer f"})
        out = r.get_json()
        assert r.status_code == 200 and not out["existing"] and out["open"].endswith(f"/m/{out['id']}")
        item = db.data[f"users/u1/materials/{out['id']}"]
        assert item["kind"] == "paper" and item["topicId"] == "t1" and item["year"] == 2017
        assert item["pdfUrl"] == "https://arxiv.org/pdf/1706.03762" and item["content"] == ""
        again = app_client.post("/extension/save", json=page, headers={"Authorization": "Bearer f"}).get_json()
        assert again["existing"] and again["id"] == out["id"]


def test_save_without_category_files_it_under_saved_from_the_web(app_client, db):
    with firebase_user():
        bad = app_client.post("/extension/save", json={"title": "x", "url": "javascript:alert(1)"}, headers={"Authorization": "Bearer f"})
        assert bad.status_code == 400
        r = app_client.post("/extension/save", json={"title": "A blog post", "url": "https://example.com/post",
                                                      "content": "Body text", "topicId": "nope", "year": "1200"},
                            headers={"Authorization": "Bearer f"})
    item = db.data[f"users/u1/materials/{r.get_json()['id']}"]
    cat = db.data[f"users/u1/categories/{item['categoryId']}"]
    assert cat["name"] == "Saved from the web" and item["topicId"] is None and item["year"] is None
    assert item["kind"] == "link" and item["content"] == "Body text"


def test_pinda_answers_about_the_page(app_client):
    seen = {}

    def fake_stream(**kw):
        seen.update(kw)
        yield 'data: {"type": "done"}\n\n'
    page = {"title": 'A "quoted" page', "url": "https://example.com/a", "text": "Mitochondria make ATP.",
            "selection": "make ATP"}
    with firebase_user(), mock.patch("ai.stream_text", side_effect=fake_stream), mock.patch("ai._pdf_block") as pdf:
        r = app_client.post("/pinda", json={"context": {"scope": "page", "page": page},
                                            "messages": [{"role": "user", "text": "What does this say?"}]},
                            headers={"Authorization": "Bearer f"})
        r.get_data()
    pdf.assert_not_called()
    first = seen["messages"][0]["content"]
    text = first[0]["text"]
    assert "Mitochondria make ATP." in text and "<selection>" in text and "A 'quoted' page" in text
    assert first[-1]["text"] == "What does this say?"
