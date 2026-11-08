# DSCVR server

Flask API on Railway: research search (papers, Europe PMC health literature, UK case law), Pinda (Claude),
study tools, subject alerts, reports, ratings, rooms, plans and enterprise billing,
plus two private tools:

| Tool | Where | Who |
|---|---|---|
| Admin dashboard | `https://<server>/admin` | You as founder: users, editions, teams and invoices, AI cost, ratings, live rooms, switches, audit log |
| Developer console | `../devconsole` (runs on your Mac) | You as engineer: uptime, live checks, errors, maintenance, migrations, deploys |

## Environment

| Variable | What |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Service-account JSON (one line). Pasting it into `GOOGLE_APPLICATION_CREDENTIALS` also works |
| `ANTHROPIC_API_KEY` | Claude key for Pinda, reports, recaps, fact-checks |
| `PINDA_MODEL` | Optional model override (default `claude-sonnet-5-5`) |
| `S2_API_KEY`, `OPENALEX_API_KEY`, `CORE_API_KEY` | Optional free keys: higher rate limits for Semantic Scholar and OpenAlex, and turns on CORE in the combined search |
| `SEAT_DAY_USD`, `SEAT_MONTH_CAP_USD`, `AI_INPUT_PER_M_USD`, `AI_OUTPUT_PER_M_USD` | Enterprise prices |
| `ANTHROPIC_INPUT_PER_M_USD`, `ANTHROPIC_OUTPUT_PER_M_USD` | What Anthropic charges for the best model (default 2 / 10, Sonnet 5.5). Plans and the cost chart use it |
| `AI_FAST_INPUT_PER_M_USD`, `AI_FAST_OUTPUT_PER_M_USD` | Same for the fast model (default 1 / 5) |
| `PAYSTACK_SECRET_KEY`, `PAYSTACK_PLAN_*`, `PAYSTACK_CALLBACK_URL` | Plus and Max subscriptions (see `billing.py`) |
| `CONTACT_EMAIL` | Sent to OpenAlex and Europe PMC so they give steadier service |
| `CRON_SECRET` | Lets the daily scheduler call `POST /alerts/run` (header `X-Cron-Secret`). Without it the route is off |
| `RESEND_API_KEY`, `ALERTS_FROM_EMAIL` | Optional: email digests for alerts, sent through Resend from e.g. `DSCVR <alerts@yourdomain>` |
| `APP_URL` | Link used in alert emails (default `https://dscvr-9d362.web.app`) |
| `ADMIN_USERNAME`, `ADMIN_PASSWORD_HASH` | Founder sign-in. Make the hash with `python manage.py hash-password` |
| `ADMIN_TOTP_SECRET` | Second step: the 6-digit authenticator code. Make it with `python manage.py totp-setup` and add it to Google Authenticator |
| `SESSION_SECRET` | Signs dashboard sessions (32+ chars) |
| `DEV_API_SECRET` | Shared with the developer console (32+ chars). Without it `/internal/dev/*` is off |
| `DEV_ALLOWED_IPS` | Optional allowlist for the developer API |
| `TRUST_PROXY` | Proxies in front of the app (default 1 on Railway) |

## Sources and their terms

| Source | Used for | Terms |
|---|---|---|
| arXiv, OpenAlex, Semantic Scholar, Crossref, DOAJ, PLOS, Zenodo, CORE | Searched together (`/discover?source=all`), merged by DOI, every source labelled | Open APIs |
| Unpaywall | Finds a legal free PDF for a DOI (`/pdf/find`) | Free, sends `CONTACT_EMAIL` |
| Europe PMC | Medicine, nursing, pharmacy, public health; clinical guidelines | Free REST API, no key |
| Find Case Law (The National Archives) | UK judgments | Open Justice Licence. One request per user search is fine; bulk or computational analysis needs their transactional licence (caselawlicence@nationalarchives.gov.uk) |
| NigeriaLII, GhaLII, Kenya Law, SAFLII, ULII, CommonLII | Nigerian and Commonwealth judgments | The app links to their own search. They forbid automated search and AI use, so the server never calls them. Ask them for API access to go further |
| NWLR, LawPavilion | Nigerian law reports | Paid. Users can add reports they subscribe to as PDFs. A data deal needs a partnership |

## Daily alerts

Users switch alerts on in Settings. Once a day something has to run them, either:

- a Railway cron service from this repo with start command `python manage.py alerts`, schedule `0 6 * * *`,
  and the same variables as this service; or
- any scheduler that sends `POST https://<server>/alerts/run` with header `X-Cron-Secret: <CRON_SECRET>`.

## Switches without a deploy

Stored in Firestore `config/flags`, picked up by every worker within 15 s:
pause Pinda (admin dashboard), free daily limit (admin dashboard), maintenance mode (developer console:
pause all changes and AI, or AI only).

## Tests

```bash
pip install -r requirements.txt pytest
python -m pytest -q tests
```
