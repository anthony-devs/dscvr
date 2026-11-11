"""Deleting an account and everything in it.

The app calls POST /account/delete. We remove, in order: an active paid
subscription (so it stops renewing), organisation membership, share links,
community ratings (taking them out of each paper's average), uploaded files,
the whole users/{uid} tree, and finally the sign-in itself.
"""
from __future__ import annotations

import logging
from typing import Any

log = logging.getLogger("account")


def delete_everything(uid: str, db, bucket, auth, cancel_subscription=None, detach_org=None) -> dict[str, Any]:
    done: dict[str, Any] = {}
    profile = db.document(f"users/{uid}").get().to_dict() or {}

    if cancel_subscription and (profile.get("paystack") or {}).get("subscriptionCode"):
        try:
            cancel_subscription(uid)
            done["subscription"] = "cancelled"
        except Exception:  # noqa: BLE001 - an already-cancelled plan must not block deletion
            log.warning("subscription cancel failed during account deletion", exc_info=True)

    if detach_org and profile.get("orgId"):
        try:
            detach_org(profile["orgId"], uid)
            done["org"] = "left"
        except Exception:  # noqa: BLE001
            log.warning("org detach failed during account deletion", exc_info=True)

    shares = db.collection("shares").where("ownerId", "==", uid).get()
    for s in shares:
        s.reference.delete()
    done["shares"] = len(shares)

    ratings = 0
    for r in db.collection_group("ratings").where("uid", "==", uid).get():
        stars = int((r.to_dict() or {}).get("stars", 0))
        paper = r.reference.parent.parent
        agg = paper.get().to_dict() or {}
        count = max(0, int(agg.get("count", 0)) - 1)
        paper.set({"count": count, "sum": max(0, int(agg.get("sum", 0)) - stars)}, merge=True)
        r.reference.delete()
        ratings += 1
    done["ratings"] = ratings

    files = 0
    for blob in bucket.list_blobs(prefix=f"users/{uid}/"):
        blob.delete()
        files += 1
    done["files"] = files

    db.recursive_delete(db.document(f"users/{uid}"))
    auth.delete_user(uid)
    log.info("account deleted: %s", {k: v for k, v in done.items()})
    return done
