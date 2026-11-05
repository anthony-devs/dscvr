# DSCVR developer console

Your private control room for the DSCVR server. It is a **separate program**, so it can tell you when the
server is down, run checks against it, and deploy or migrate it. Its own history lives in a local SQLite
file, so watching costs **zero Firestore reads**.

```
founder  ->  /admin on the server        (users, editions, teams and invoices, AI cost, ratings, rooms, switches)
you      ->  this console                (own login + authenticator code, own host)
                 |  signed requests (HMAC) to /internal/dev/*          plain GET /healthz every 30 s
                 v
            DSCVR server (Railway)
```

## What it does

| Tab | |
|---|---|
| Overview | Up/down, latency, 24 h / 7 d uptime, error rate, p50/p95, version (git commit), and a plain-language **Problems** list: Claude key missing, Claude calls failing, Pinda paused, Firestore quota used up, weak admin secrets, service account missing, certificate expiring. Alerts go to Slack/Discord/Telegram once per problem. |
| Tests | 16 live checks: answers fast, Pinda and reports need a sign-in, forged tokens refused, admin locked, developer API refuses unsigned calls, HTTPS certificate, database read **and write**, Claude key valid (listing models is free), not in maintenance. |
| Errors | Recent server errors with traces, and error groups by type and route. |
| Controls | **Maintenance mode** (pause all changes and AI, or AI only) and **data migrations** (dry run first): backfill editions for older accounts, recount paper ratings. |
| Deploy & tools | Fixed commands from `actions.json`: server tests, Firestore backup, deploy server or landing to Railway (`railway up`), build and deploy the web app, deploy Firestore/Storage rules. |
| Audit log | Every sign-in, failed attempt and change, hash-chained so tampering shows. |

## Security model

- Password (scrypt) **and** a 6-digit authenticator code on every sign-in; each code works once.
- 5 wrong attempts lock the username and the address for 15 minutes. The error never says which part was wrong.
- Sessions: random tokens stored hashed, `HttpOnly` + `Secure` + `SameSite=Strict` cookie, 30 min idle / 8 h absolute, CSRF token on every change, same-origin check.
- Deploy, migrate, maintenance and "sign out everywhere" need a **new** authenticator code **and** a typed word.
- The browser never sends a command. `actions.json` holds fixed argument lists (no shell); the only blanks are named parameters that must match a pattern.
- Strict CSP, no framing, no caching of API answers. Optional IP allowlist (`CONSOLE_ALLOWED_IPS`).
- Server link: every call is signed with `DEV_API_SECRET` (method, path, time, one-time nonce, body hash). 60 s window, replay refused, wrong signatures rate-limited, off entirely unless the secret is 32+ characters.
- Secrets live only in environment variables.

If your laptop or the console host is compromised, so is everything it can deploy. Run it on a machine you trust, behind HTTPS, ideally with `CONSOLE_ALLOWED_IPS` set, and keep the TOTP secret in a password manager.

## Set up (on your Mac)

```bash
cd devconsole
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
python manage.py setup            # prints CONSOLE_USER / CONSOLE_PASSWORD_HASH / CONSOLE_TOTP_SECRET and the authenticator link
python manage.py gen-secret       # a DEV_API_SECRET; put the SAME value on the server
cp .env.example .env.local        # fill it in
cp targets.example.json targets.json
python wsgi.py                    # http://127.0.0.1:9090
```

On the **server** (Railway > dscvr-server > Variables) add `DEV_API_SECRET=<same value>`. Without it the developer API is off.

Running the console on your Mac is the simplest setup: the Deploy & tools actions use the `railway`, `firebase`,
`flutter` and `gcloud` CLIs you already have signed in there.

Tests: `python -m pytest -q tests` (24 tests, including ones that start the real DSCVR server and run every check against it).

## Hosting on Railway (optional, monitoring only)

Hosted, the console watches the server around the clock and sends alerts, but the deploy actions won't work
(no CLIs there). Second service in the same project, Root Directory `devconsole`, with a Volume at `/data`:

```
CONSOLE_USER, CONSOLE_PASSWORD_HASH, CONSOLE_TOTP_SECRET   (from: python manage.py setup)
TARGET_URL=https://dscvr-server-production.up.railway.app
DEV_API_SECRET=<same value as on the server>
CONSOLE_DB=/data/console.db
TRUST_PROXY=1
ALERT_WEBHOOK_URL=<optional Slack/Discord webhook>
```
