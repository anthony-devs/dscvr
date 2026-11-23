#!/usr/bin/env bash
# Runs DSCVR's server and landing site on Google Cloud Run, in the Firebase
# project. Run from the repo root on your Mac.
#
#   ./scripts/gcp.sh all               everything below, in order, stopping at the first problem
#   ./scripts/gcp.sh setup             one-time: APIs, service account, secrets copied from Railway
#   ./scripts/gcp.sh deploy server     build and deploy the Flask server
#   ./scripts/gcp.sh deploy landing    build and deploy the Next.js site
#   ./scripts/gcp.sh deploy all
#   ./scripts/gcp.sh schedule          daily alerts job (Cloud Scheduler)
#   ./scripts/gcp.sh domains           map api.askpinda.com and www.askpinda.com; prints the DNS records
#   ./scripts/gcp.sh status            URLs, domains and health
#   ./scripts/gcp.sh secret NAME       set or change one server secret (prompts, hidden)
#
# Needs: gcloud (signed in with `gcloud auth login`) and, for `setup`, the
# Railway CLI signed in, so variables are copied straight from Railway into
# Secret Manager without being printed.
set -euo pipefail

PROJECT="${GCP_PROJECT:-dscvr-9d362}"
API_DOMAIN="${API_DOMAIN:-api.askpinda.com}"
WWW_DOMAIN="${WWW_DOMAIN:-www.askpinda.com}"
APEX_DOMAIN="${APEX_DOMAIN:-askpinda.com}"
RAILWAY_SERVER_SERVICE="${RAILWAY_SERVER_SERVICE:-dscvr-server}"
RAILWAY_LANDING_SERVICE="${RAILWAY_LANDING_SERVICE:-dscvr}"
SA_NAME="dscvr-server"
SA="${SA_NAME}@${PROJECT}.iam.gserviceaccount.com"
REPO="dscvr"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE="$ROOT/.gcp"   # git-ignored: region and the variable lists (names only, no values)
mkdir -p "$STATE"

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
die() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }
g() { gcloud --project "$PROJECT" --quiet "$@"; }
# Newly enabled Google APIs take a few minutes to start working: retry until they do.
retry() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    "$@" && return 0
    echo "  Google is still switching that on, trying again in 20 seconds ($i/12)..."
    sleep 20
  done
  return 1
}
TMP_VARS=""
# Never leave copied variable values on disk, even if something fails.
trap 'rm -f "$TMP_VARS" "$STATE"/.val-* 2>/dev/null' EXIT

command -v gcloud >/dev/null || die "Install the Google Cloud CLI first: https://cloud.google.com/sdk/docs/install"
gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q . || die "Run: gcloud auth login"

# ── Region: next to Firestore, in a region that supports custom domains ──
region() {
  if [[ -s "$STATE/region" ]]; then cat "$STATE/region"; return; fi
  local loc
  loc="$(g firestore databases describe --database='(default)' --format='value(locationId)' 2>/dev/null || true)"
  local r
  case "$loc" in
    nam5|nam7|us-central1) r=us-central1 ;;
    eur3|europe-west1) r=europe-west1 ;;
    us-east1|us-east4|us-west1|europe-west4|europe-north1|asia-east1|asia-northeast1|asia-southeast1) r="$loc" ;;
    europe-*) r=europe-west1 ;;
    asia-*|australia-*) r=asia-southeast1 ;;
    *) r=us-central1 ;;
  esac
  echo "$r" > "$STATE/region"
  echo "$r"
}

image() { echo "$(region)-docker.pkg.dev/${PROJECT}/${REPO}/$1:$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || date +%s)"; }

# ── setup ──────────────────────────────────────────────────────────────
setup() {
  local r; r="$(region)"
  say "Project $PROJECT, region $r (Firestore is in $(g firestore databases describe --database='(default)' --format='value(locationId)' 2>/dev/null || echo unknown))"

  say "Turning on the Google Cloud services DSCVR needs"
  g services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com \
    secretmanager.googleapis.com cloudscheduler.googleapis.com iam.googleapis.com firestore.googleapis.com

  say "Container registry"
  g artifacts repositories describe "$REPO" --location "$r" >/dev/null 2>&1 || \
    retry g artifacts repositories create "$REPO" --repository-format docker --location "$r" --description "DSCVR images" || \
    die "The Artifact Registry API still isn't on. Check billing is enabled for $PROJECT, wait a few minutes, then run setup again."

  say "Service account for the server (replaces the service-account JSON key)"
  g iam service-accounts describe "$SA" >/dev/null 2>&1 || \
    retry g iam service-accounts create "$SA_NAME" --display-name "DSCVR server"
  for role in roles/datastore.user roles/firebaseauth.admin roles/storage.objectAdmin \
              roles/secretmanager.secretAccessor roles/logging.logWriter; do
    # A just-created service account can take a minute to be visible to IAM.
    retry g projects add-iam-policy-binding "$PROJECT" --member "serviceAccount:$SA" --role "$role" --condition=None >/dev/null
  done
  # Cloud Build needs to push images and deploy.
  local num; num="$(g projects describe "$PROJECT" --format='value(projectNumber)')"
  for role in roles/artifactregistry.writer roles/run.admin roles/iam.serviceAccountUser; do
    g projects add-iam-policy-binding "$PROJECT" --member "serviceAccount:${num}@cloudbuild.gserviceaccount.com" --role "$role" --condition=None >/dev/null || true
  done

  say "Copying the server's variables from Railway"
  import_vars server "$RAILWAY_SERVER_SERVICE"
  say "Copying the landing site's variables from Railway"
  import_vars landing "$RAILWAY_LANDING_SERVICE"

  # The daily alerts job proves itself with CRON_SECRET. Make one if Railway had none.
  if ! grep -qx CRON_SECRET "$STATE/server.secrets" 2>/dev/null; then
    say "Creating CRON_SECRET for the daily alerts job"
    g secrets describe server-CRON_SECRET >/dev/null 2>&1 || g secrets create server-CRON_SECRET --replication-policy automatic >/dev/null
    python3 -c 'import secrets; print(secrets.token_urlsafe(32), end="")' | g secrets versions add server-CRON_SECRET --data-file=- >/dev/null
    echo CRON_SECRET >> "$STATE/server.secrets"
  fi

  say "Setup done. Next: ./scripts/gcp.sh deploy all"
}

# Reads a Railway service's variables and stores them: anything secret-looking
# in Secret Manager, the rest as plain Cloud Run variables. Values go straight
# from Railway to Google; only the names are written to .gcp/.
import_vars() {
  local which="$1" service="$2"
  command -v railway >/dev/null || die "Install and sign in to the Railway CLI to copy variables, or add them with: ./scripts/gcp.sh secret NAME"
  TMP_VARS="$(mktemp)"; chmod 600 "$TMP_VARS"
  local tmp="$TMP_VARS"
  (cd "$ROOT/server" && railway variables --service "$service" --json) > "$tmp" || die "Couldn't read Railway variables for $service. Run 'railway link' in server/ first."
  WHICH="$which" API_DOMAIN="$API_DOMAIN" STATE="$STATE" python3 - "$tmp" <<'PY'
import json, os, re, sys
which, state = os.environ["WHICH"], os.environ["STATE"]
data = json.load(open(sys.argv[1]))
skip = re.compile(r"^(RAILWAY_|PORT$|NIXPACKS_|FIREBASE_SERVICE_ACCOUNT_JSON$|GOOGLE_APPLICATION_CREDENTIALS$|K_)")
secret = re.compile(r"(KEY|SECRET|PASSWORD|TOKEN|HASH|TOTP)", re.I)
plain, secrets = {}, []
for k, v in sorted(data.items()):
    if skip.search(k) or v is None:
        continue
    if secret.search(k):
        secrets.append(k)
        with open(os.path.join(state, f".val-{which}-{k}"), "w") as f:
            f.write(str(v))
        os.chmod(os.path.join(state, f".val-{which}-{k}"), 0o600)
    else:
        plain[k] = str(v)
if which == "server":
    plain["SERVER_URL"] = f"https://{os.environ['API_DOMAIN']}"
    plain.setdefault("TRUST_PROXY", "1")
else:
    plain["BLOG_API_URL"] = f"https://{os.environ['API_DOMAIN']}"
with open(os.path.join(state, f"{which}.env.yaml"), "w") as f:
    for k, v in plain.items():
        f.write(f"{k}: {json.dumps(v)}\n")
with open(os.path.join(state, f"{which}.secrets"), "w") as f:
    f.write("\n".join(secrets) + ("\n" if secrets else ""))
print(f"  {len(plain)} plain variables, {len(secrets)} secrets: {', '.join(secrets) or 'none'}")
PY
  local k
  while read -r k; do
    [[ -z "$k" ]] && continue
    local id="${which}-${k}" f="$STATE/.val-${which}-${k}"
    g secrets describe "$id" >/dev/null 2>&1 || g secrets create "$id" --replication-policy automatic >/dev/null
    g secrets versions add "$id" --data-file="$f" >/dev/null
    rm -f "$f"
    echo "  stored $id"
  done < "$STATE/${which}.secrets"
  rm -f "$tmp"
}

secret_flags() {
  local which="$1" out="" k
  [[ -s "$STATE/${which}.secrets" ]] || { echo ""; return; }
  while read -r k; do [[ -n "$k" ]] && out+="${out:+,}${k}=${which}-${k}:latest"; done < "$STATE/${which}.secrets"
  echo "--set-secrets=$out"
}

# ── deploy ─────────────────────────────────────────────────────────────
deploy_server() {
  local r img; r="$(region)"; img="$(image server)"
  [[ -s "$STATE/server.env.yaml" ]] || die "Run ./scripts/gcp.sh setup first."
  say "Building the server ($img)"
  g builds submit "$ROOT/server" --tag "$img" --region "$r"
  say "Deploying dscvr-server"
  # shellcheck disable=SC2046
  g run deploy dscvr-server --image "$img" --region "$r" --service-account "$SA" \
    --allow-unauthenticated --port 8080 --cpu 1 --memory 1Gi --concurrency 16 \
    --timeout 3600 --min-instances "${SERVER_MIN_INSTANCES:-1}" --max-instances 10 \
    --env-vars-file "$STATE/server.env.yaml" $(secret_flags server)
  local url; url="$(g run services describe dscvr-server --region "$r" --format='value(status.url)')"
  say "Server is up at $url"
  curl -fsS "$url/health" && echo
}

deploy_landing() {
  local r img; r="$(region)"; img="$(image landing)"
  [[ -s "$STATE/landing.env.yaml" ]] || die "Run ./scripts/gcp.sh setup first."
  say "Building the landing site ($img)"
  g builds submit "$ROOT/landing" --tag "$img" --region "$r"
  say "Deploying dscvr-landing"
  # shellcheck disable=SC2046
  g run deploy dscvr-landing --image "$img" --region "$r" --service-account "$SA" \
    --allow-unauthenticated --port 8080 --cpu 1 --memory 512Mi --concurrency 80 \
    --min-instances "${LANDING_MIN_INSTANCES:-0}" --max-instances 5 \
    --env-vars-file "$STATE/landing.env.yaml" $(secret_flags landing)
  say "Landing site is up at $(g run services describe dscvr-landing --region "$r" --format='value(status.url)')"
}

# ── daily alerts ───────────────────────────────────────────────────────
schedule() {
  local r; r="$(region)"
  local url="https://${API_DOMAIN}"
  if ! curl -fsS -o /dev/null "$url/health" 2>/dev/null; then
    url="$(g run services describe dscvr-server --region "$r" --format='value(status.url)')"
  fi
  g secrets describe server-CRON_SECRET >/dev/null 2>&1 || die "CRON_SECRET isn't set. Run: ./scripts/gcp.sh secret CRON_SECRET"
  local cron; cron="$(g secrets versions access latest --secret server-CRON_SECRET)"
  local args=(--location "$r" --schedule "0 7 * * *" --time-zone "Africa/Lagos" --uri "$url/alerts/run"
              --http-method POST --headers "X-Cron-Secret=${cron},Content-Type=application/json" --message-body '{}'
              --attempt-deadline 30m)
  if g scheduler jobs describe dscvr-daily-alerts --location "$r" >/dev/null 2>&1; then
    g scheduler jobs update http dscvr-daily-alerts "${args[@]}" >/dev/null
  else
    g scheduler jobs create http dscvr-daily-alerts "${args[@]}" >/dev/null
  fi
  say "Daily alerts run at 07:00 Lagos time against $url"
}

# ── custom domains ─────────────────────────────────────────────────────
domains() {
  local r; r="$(region)"
  for pair in "dscvr-server:$API_DOMAIN" "dscvr-landing:$WWW_DOMAIN" "dscvr-landing:$APEX_DOMAIN"; do
    local svc="${pair%%:*}" dom="${pair#*:}"
    g run services describe "$svc" --region "$r" >/dev/null 2>&1 || die "$svc isn't deployed yet. Run: ./scripts/gcp.sh deploy all"
    g beta run domain-mappings describe --domain "$dom" --region "$r" >/dev/null 2>&1 || \
      g beta run domain-mappings create --service "$svc" --domain "$dom" --region "$r" >/dev/null || \
      die "Couldn't map $dom. Your Google account must be a verified owner of askpinda.com in Search Console."
  done
  say "Add these records in OpenSRS (DNS for askpinda.com):"
  for dom in "$API_DOMAIN" "$WWW_DOMAIN" "$APEX_DOMAIN"; do
    g beta run domain-mappings describe --domain "$dom" --region "$r" \
      --format='table[box](metadata.name:label=DOMAIN,status.resourceRecords[].type:label=TYPE,status.resourceRecords[].rrdata:label=VALUE)'
  done
  echo "Google issues the HTTPS certificates once DNS points here (usually 15 to 60 minutes)."
}

status() {
  local r; r="$(region)"
  say "Services ($r)"
  g run services list --region "$r" --format='table(metadata.name,status.url,status.conditions[0].status:label=READY)'
  say "Domains"
  g beta run domain-mappings list --region "$r" --format='table(metadata.name,spec.routeName,status.conditions[0].status:label=READY)' 2>/dev/null || true
  for u in "https://${API_DOMAIN}/health" "https://${WWW_DOMAIN}"; do
    printf '%-40s %s\n' "$u" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$u" || echo down)"
  done
}

set_secret() {
  local name="${1:?Usage: ./scripts/gcp.sh secret NAME}" which="${2:-server}"
  local id="${which}-${name}" val
  read -r -s -p "Value for ${name} (hidden): " val; echo
  [[ -n "$val" ]] || die "Nothing entered."
  g secrets describe "$id" >/dev/null 2>&1 || g secrets create "$id" --replication-policy automatic >/dev/null
  printf '%s' "$val" | g secrets versions add "$id" --data-file=- >/dev/null
  grep -qx "$name" "$STATE/${which}.secrets" 2>/dev/null || echo "$name" >> "$STATE/${which}.secrets"
  echo "Saved. Redeploy to use it: ./scripts/gcp.sh deploy ${which}"
}

case "${1:-}" in
  setup) setup ;;
  all) setup; deploy_server; deploy_landing; schedule; domains ;;
  deploy)
    case "${2:-all}" in
      server) deploy_server ;;
      landing) deploy_landing ;;
      all) deploy_server; deploy_landing ;;
      *) die "deploy server | landing | all" ;;
    esac ;;
  schedule) schedule ;;
  domains) domains ;;
  status) status ;;
  secret) set_secret "${2:-}" "${3:-server}" ;;
  *) sed -n '2,17p' "$0"; exit 1 ;;
esac
