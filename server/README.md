# DSCVR server

Flask API on Railway: research search, Pinda (Claude), reports, ratings, rooms, enterprise billing,
plus two private tools:

| Tool | Where | Who |
|---|---|---|
| Admin dashboard | `https://<server>/admin` | You as founder: users, editions, teams and invoices, AI cost, ratings, live rooms, switches, audit log |
| Developer console | `../devconsole` (runs on your Mac) | You as engineer: uptime, live checks, errors, maintenance, migrations, deploys |

## Environment

| Variable | What |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Service-account JSON (one line) |
| `ANTHROPIC_API_KEY` | Claude key for Pinda, reports, recaps, fact-checks |
| `PINDA_MODEL` | Optional model override (default `claude-sonnet-5-5`) |
| `S2_API_KEY` | Optional Semantic Scholar key |
| `PINDA_FAST_MODEL` | Model for Free-plan chat and lighter work (default `claude-haiku-5-5`) |
| `PLAN_<NAME>_PRICE_USD`, `PLAN_<NAME>_DAILY_USD`, `PLAN_<NAME>_MONTHLY_USD` | Plan prices and usage budgets (see `plans.py`); NAME is FREE, STUDENT_PLUS, RESEARCH_PLUS or MAX |
| `AI_FAST_INPUT_PER_M_USD`, `AI_FAST_OUTPUT_PER_M_USD` | What Anthropic charges for the fast model (default 1 / 5), used by the usage meter |
| `PAYSTACK_SECRET_KEY`, `PAYSTACK_PLAN_STUDENT_PLUS`, `PAYSTACK_PLAN_RESEARCH_PLUS`, `PAYSTACK_PLAN_MAX`, `PAYSTACK_CALLBACK_URL` | Paid plans (see `billing.py`). Without them, checkout is off |
| `SEAT_DAY_USD`, `SEAT_MONTH_CAP_USD`, `AI_INPUT_PER_M_USD`, `AI_OUTPUT_PER_M_USD` | Enterprise prices |
| `ANTHROPIC_INPUT_PER_M_USD`, `ANTHROPIC_OUTPUT_PER_M_USD` | What Anthropic charges for the best model (default 2 / 10, Claude Sonnet 5.5), for the usage meter and cost chart |
| `ADMIN_USERNAME`, `ADMIN_PASSWORD_HASH` | Founder sign-in. Make the hash with `python manage.py hash-password` |
| `ADMIN_KEY` | Second lock for the dashboard (16+ chars, `python manage.py gen-secret`) |
| `SESSION_SECRET` | Signs dashboard sessions (32+ chars) |
| `DEV_API_SECRET` | Shared with the developer console (32+ chars). Without it `/internal/dev/*` is off |
| `DEV_ALLOWED_IPS` | Optional allowlist for the developer API |
| `TRUST_PROXY` | Proxies in front of the app (default 1 on Railway) |

## Switches without a deploy

Stored in Firestore `config/flags`, picked up by every worker within 15 s:
pause Pinda (admin dashboard), free daily limit (admin dashboard), maintenance mode (developer console:
pause all changes and AI, or AI only).

## Tests

```bash
pip install -r requirements.txt pytest
python -m pytest -q tests
```
