# Running DSCVR on Google Cloud

The Flask server and the Next.js landing site run on **Cloud Run** in the Firebase project (`dscvr-9d362`).
`scripts/gcp.sh` does all of it. Run it from the repo root on your Mac.

| Piece | Where |
| --- | --- |
| Server (`server/`) | Cloud Run service `dscvr-server`, at **https://api.askpinda.com** |
| Landing site (`landing/`) | Cloud Run service `dscvr-landing`, at **https://www.askpinda.com** |
| Web app | Firebase Hosting (unchanged), at app.askpinda.com |
| Secrets (API keys, passwords) | Secret Manager, named `server-NAME` / `landing-NAME` |
| Firestore, Auth and Storage access | the `dscvr-server` service account (no JSON key needed) |
| Daily alerts | Cloud Scheduler job `dscvr-daily-alerts`, 07:00 Lagos time |

## First time

```bash
brew install --cask google-cloud-sdk        # if gcloud isn't installed
gcloud auth login                            # sign in with the Google account that owns the Firebase project
./scripts/gcp.sh setup                       # APIs, service account, copies Railway variables into Google
./scripts/gcp.sh deploy all                  # builds in Cloud Build (no Docker needed on the Mac)
./scripts/gcp.sh schedule                    # daily alerts
./scripts/gcp.sh domains                     # prints the DNS records to add in OpenSRS
./scripts/gcp.sh status                      # once DNS and HTTPS are ready
```

`setup` reads each Railway service's variables with the Railway CLI. Anything whose name contains KEY, SECRET,
PASSWORD, TOKEN, HASH or TOTP goes to Secret Manager; the rest become plain Cloud Run variables, listed (names and
values) in `.gcp/*.env.yaml`, which git ignores. Values are never printed. `FIREBASE_SERVICE_ACCOUNT_JSON` is not
copied, because the service account replaces it.

## Switching over without downtime

1. Deploy, then test the `run.app` addresses that `deploy` prints (sign in, Discover, Pinda, a payment page).
2. `./scripts/gcp.sh domains`, then add the records it prints in OpenSRS:
   - `api` CNAME `ghs.googlehosted.com.`
   - `www`: change the existing CNAME from Railway to `ghs.googlehosted.com.`
3. Wait until `./scripts/gcp.sh status` shows 200 for both (HTTPS certificates take 15 to 60 minutes).
4. In Paystack (Settings, API Keys & Webhooks), set the webhook URL to
   `https://api.askpinda.com/billing/paystack/webhook`.
5. Deploy the web app (`./scripts/deploy_web.sh`), which now calls api.askpinda.com.
6. Reload the extension. Its server is now api.askpinda.com, so submit it to the Chrome Web Store after this.
7. Keep Railway running for a day or two, then delete both Railway services.

## Everyday

```bash
./scripts/gcp.sh deploy server               # after server changes
./scripts/gcp.sh deploy landing              # after landing or blog changes
./scripts/gcp.sh secret RESEND_API_KEY       # add or change a server secret (asks for the value, hidden)
./scripts/gcp.sh secret REVALIDATE_SECRET landing
```

To change a plain variable, edit `.gcp/server.env.yaml` (or `landing.env.yaml`) and redeploy. Logs are in the
Cloud Console under Cloud Run, then the service, then Logs.

## Costs and settings

- The server keeps one instance warm (`SERVER_MIN_INSTANCES=1`) so the first request after a quiet spell isn't
  slow. That costs a few dollars a month. Use `SERVER_MIN_INSTANCES=0 ./scripts/gcp.sh deploy server` to scale to
  zero instead.
- The landing site scales to zero (`LANDING_MIN_INSTANCES=0`).
- Requests can run for up to an hour, so Pinda's streamed answers and large PDF downloads aren't cut off.
- Cloud Run runs in the region next to Firestore that supports custom domains. The choice is saved in `.gcp/region`.
