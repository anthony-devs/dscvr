# DSCVR setup

One Flutter codebase ships to **iOS, Android and the web (installable PWA)**.
Backend: Firebase (Auth, Firestore, Storage, Hosting, Cloud Functions).
Pinda talks to Claude through a Cloud Function, so the API key never ships in an app binary or the browser.

## 1. Run it

```bash
flutter pub get

# Real app (needs Firebase; see below)
flutter run -d chrome
flutter run -d <ios-or-android-device>

# Demo mode: in-memory sample library, no Firebase, canned Pinda replies.
# Good for design review, screenshots and portfolio demos.
flutter run -d chrome --dart-define=DSCVR_DEMO=true
```

## 2. Firebase console (one time)

1. **Authentication**: enable *Email/Password* and *Google*. Under *Settings → Authorized domains*, add any custom domain you deploy the PWA to.
2. **Firestore**: create the database (production mode).
3. **Storage**: enable it (bucket `dscvr-9d362.firebasestorage.app`, as the app already expects).
4. **Plan**: Cloud Functions require the **Blaze** (pay-as-you-go) plan.

Deploy the security rules:

```bash
firebase deploy --only firestore:rules,storage
```

Rules summary: every document lives under `users/{uid}` and only that user can read or write it. Uploads must be PDFs under 50 MB. Usage counters (`users/{uid}/meta`) are writable only by functions.

## 3. Cloud Functions (Pinda, link previews, Discover proxy)

```bash
firebase functions:secrets:set ANTHROPIC_API_KEY   # paste your Claude API key
cd functions && npm install && cd ..
firebase deploy --only functions
```

| Function | What it does |
|---|---|
| `pinda` | Verifies the user's Firebase ID token, loads the requested context from *their* Firestore (one material, a topic, a category or the whole library, including uploaded PDFs and margin notes), and streams Claude's answer back as Server-Sent Events. |
| `unfurl` | Title, authors, year and readable text for a link; oEmbed for YouTube. Blocks private/internal addresses (SSRF). |
| `discover` | arXiv and Semantic Scholar search. Needed on the web because those APIs do not send CORS headers; mobile calls them directly and falls back to this. |

Optional parameters (set during deploy or in `functions/.env`):

- `PINDA_MODEL`, default `claude-sonnet-5-5`
- `PINDA_DAILY_LIMIT`, default `150` questions per user per day
- `S2_API_KEY`, a Semantic Scholar API key for higher rate limits (env var)

If you deploy to a custom domain, add it to `ALLOWED_ORIGINS` in `functions/src/index.ts`.

The app reads the functions base URL from `--dart-define=DSCVR_FUNCTIONS_URL=...`. It defaults to `https://us-central1-dscvr-9d362.cloudfunctions.net`.

## 4. Ship the PWA

```bash
flutter build web --release
firebase deploy --only hosting
```

- `web/manifest.json` and the icons make it installable ("Add to Home Screen" on iOS, "Install app" on Chrome/Edge/Android).
- `web/sw.js` makes it open offline: it caches the app shell, fonts and CanvasKit. Live data (Firestore, functions) is never cached. Bump `VERSION` in `sw.js` to force-drop old caches.
- `firebase.json` rewrites every path to `index.html` (clean URLs like `/c/<id>` and `/m/<id>`) and sets cache headers.

## 5. Ship iOS and Android

```bash
flutter build ipa       # then upload with Xcode / Transporter
flutter build appbundle # then upload to Play Console
```

- App name is `DSCVR` on both. Icons are generated from the brand mark; replace them with `flutter_launcher_icons` later if you change the logo.
- Android: `INTERNET` permission and an `https` intent query (for opening links) are in the manifest. `minSdk` comes from Flutter (24), which covers Firebase and WebView.
- Google Sign-In on iOS needs the reversed client ID URL scheme from `GoogleService-Info.plist` in `Info.plist` (standard FlutterFire step).
- PDFs on Android open through Google's document viewer inside a WebView; iOS renders them natively. For an in-app PDF renderer with page tracking, add `pdfrx` and swap it into `lib/widgets/embed/embed_view_io.dart`.

## Architecture

```
lib/
  app.dart                 App root: theme, router, per-user services
  config/env.dart          --dart-define flags (demo mode, functions URL)
  theme/                   Design tokens (light/dark), typography
  models/                  auth (existing), library, pinda, paper
  data/                    Firestore + demo repositories, Pinda SSE client,
                           Discover (arXiv/S2/Wikipedia), link unfurling
  state/                   Session, settings, library and Pinda controllers
  router/app_router.dart   go_router: auth redirects, deep links
  screens/
    shell/                 Sidebar (wide) / bottom nav + drawer (phone)
    library/               Recent, category/topic pages, reading list, search
    add/                   Add material: link, PDF, arXiv paper, YouTube
    reader/                Reader, note editor, margin notes
    pinda/                 Chat surface + full-page Pinda
    discover/  onboarding/  settings/
    login.dart signup.dart auth_widgets.dart   (existing, restyled)
  widgets/                 Material card, progress ring, markdown, icons,
                           embed view (iframe on web, WebView on mobile)
functions/                 TypeScript Cloud Functions
```

Firestore layout (all under `users/{uid}`): `categories`, `topics`, `materials` (+ `notes` subcollection), `conversations` (+ `messages`), `meta/usage`.

Legacy, no longer routed: `screens/home.dart`, `screens/recents_page.dart`, `screens/components/*`, `screens/dscvr_repository.dart`, `models/file.dart`. They're safe to delete once you've checked nothing in them is still needed.
