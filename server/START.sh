#!/bin/bash
# ── DSCVR Flask Server ──────────────────────────
cd "$(dirname "$0")"

# Create venv if it doesn't exist
if [ ! -d "venv" ]; then
  echo "Setting up virtual environment..."
  python3 -m venv venv
  source venv/bin/activate
  pip install -r requirements.txt
  echo ""
  echo "⚠  Copy .env.example to .env and set GOOGLE_APPLICATION_CREDENTIALS"
  echo "   to your Firebase service account key path before running again."
  cp .env.example .env 2>/dev/null
  exit 0
fi

source venv/bin/activate
echo "Starting DSCVR server on http://localhost:8080 ..."
FLASK_DEBUG=true python app.py
