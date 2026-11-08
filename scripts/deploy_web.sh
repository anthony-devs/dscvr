#!/usr/bin/env bash
# Build and deploy the DSCVR web app. Use this instead of running the commands by hand.
#   scripts/deploy_web.sh                       # uses the production server
#   DSCVR_SERVER_URL=https://… scripts/deploy_web.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SERVER_URL="${DSCVR_SERVER_URL:-https://dscvr-server-production.up.railway.app}"
SERVER_URL="${SERVER_URL%/}"

# 1. Refuse obviously broken URLs (this is what broke Discover before).
if [[ ! "$SERVER_URL" =~ ^https://[A-Za-z0-9.-]+$ ]]; then
  echo "✗ DSCVR_SERVER_URL looks wrong: '$SERVER_URL' (expected https://host)"; exit 1
fi
# 2. Make sure the server is actually up before shipping a build that depends on it.
if ! curl -fsS -m 15 "$SERVER_URL/health" >/dev/null; then
  echo "✗ $SERVER_URL/health is not responding. Deploy the server first."; exit 1
fi
echo "✓ server OK: $SERVER_URL"

# 3. Build. --no-web-resources-cdn ships CanvasKit with the app instead of fetching it from
#    www.gstatic.com. Without it the app sits on the loading screen on any network that
#    blocks or throttles Google's CDN (some Wi-Fi, schools, offices).
flutter build web --release --no-web-resources-cdn --dart-define=DSCVR_SERVER_URL="$SERVER_URL"
[ -f build/web/canvaskit/canvaskit.wasm ] || { echo "✗ canvaskit missing from build/web"; exit 1; }
grep -q '"useLocalCanvasKit":true' build/web/flutter_bootstrap.js || { echo "✗ build still loads CanvasKit from the CDN"; exit 1; }

# 4. Give the bundle a content-hashed name so no browser or CDN cache can ever
#    serve an old build: index.html and flutter_bootstrap.js are no-cache and
#    point at the new filename.
cd build/web
HASH=$(shasum -a 256 main.dart.js | cut -c1-12)
mv main.dart.js "main.$HASH.dart.js"
[ -f main.dart.js.map ] && mv main.dart.js.map "main.$HASH.dart.js.map"
sed -i.bak "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.$HASH.dart.js\"/" flutter_bootstrap.js && rm flutter_bootstrap.js.bak
grep -q "main.$HASH.dart.js" flutter_bootstrap.js || { echo "✗ could not patch flutter_bootstrap.js"; exit 1; }
grep -q "$SERVER_URL" "main.$HASH.dart.js" || { echo "✗ server URL missing from bundle"; exit 1; }
echo "✓ bundle: main.$HASH.dart.js"
cd ../..

# 5. Deploy.
firebase deploy --only hosting --project dscvr-9d362
echo "✓ deployed main.$HASH.dart.js"
