# DSCVR browser extension

Chrome (and Edge, Brave, Arc) extension. Plain JavaScript, Manifest V3, no build step.

What it does, in a side panel next to any page:

- **Save**: saves the page, paper or YouTube video to a category and topic in the user's library. It reads the
  scholarly tags publishers use (`citation_title`, `citation_author`, `citation_doi`, `citation_pdf_url`), and also
  knows arXiv, PubMed and YouTube. Web articles are saved with their text so Pinda can read them.
- **Free PDF**: on a paper with a DOI and no PDF, it asks the server (`/pdf/find`, Unpaywall) for a legal free copy
  and attaches it when saving.
- **Ask Pinda**: chat about the current page or the highlighted text (`/pinda` with `scope: "page"`). For PDF tabs,
  the server reads the PDF itself. It uses the same plan budgets as the app.
- **Cite**: the same seven styles as the app (APA, Harvard, Vancouver, MLA, Chicago, OSCOLA, Nigerian legal), plus BibTeX.
- **Right-click**: "Save page to DSCVR" saves into the last-used category without opening the panel; "Ask Pinda about
  the selection" opens the panel and asks.
- **Shortcut**: Alt+Shift+D opens the panel.

## Sign-in

The extension never sees a password. **Connect** opens `app.askpinda.com/connect-extension`. The signed-in web app
calls `POST /extension/token`, the server returns a `dx_...` token, and the page passes it to the extension
(`src/connect.js` relays it). The server stores only a SHA-256 hash of the token, at `extension_tokens/{hash}`.
Tokens last 180 days. Sign out revokes the token, and deleting the account removes all of them.

An extension token only works on `/extension/*`, `/pinda`, `/pdf/find`, `/pdf/view` and `/billing/me`. Billing changes,
account deletion, teams and admin all still need the app.

## Files

| File | What it is |
| --- | --- |
| `manifest.json` | Permissions: `activeTab`, `scripting`, `sidePanel`, `storage`, `contextMenus`; host access only to the DSCVR server. "Read all sites" is optional and asked for in the panel. |
| `src/background.js` | Service worker: right-click menu, the connect handshake, quick save |
| `src/connect.js` | Content script on app.askpinda.com: marks the page and relays the token |
| `src/panel.*` | The side panel |
| `src/extract.js` | Reads the page's metadata and text (injected on demand) |
| `src/cite.js` | Citation styles, ported from `lib/models/citation.dart` |
| `src/api.js`, `src/config.js` | Server calls and URLs |

## Test it locally

1. Deploy the server and web app first (the extension uses the new `/extension/*` endpoints and the
   `/connect-extension` page):
   `cd server && railway up`, then `./scripts/deploy_web.sh` from the repo root.
2. Open `chrome://extensions`, turn on **Developer mode** (top right), click **Load unpacked** and choose this
   `extension` folder.
3. A tab opens on `app.askpinda.com/connect-extension`. Sign in if asked, then press **Connect**.
4. Pin the extension (puzzle-piece icon, then the pin), open a paper (for example any arXiv abstract page, or a
   journal article) and click the DSCVR icon.
5. After editing any file, click the reload arrow on the extension's card in `chrome://extensions`.
   Errors from the panel show when you right-click the panel and choose **Inspect**. Errors from the service worker
   show under **service worker** on the extension's card.

To test against a local server, from the panel's Inspect console:
`chrome.storage.local.set({serverUrl: "http://localhost:8080", appUrl: "http://localhost:5000"})`, then allow
"read all sites" when the panel asks. To go back, run `chrome.storage.local.remove(["serverUrl", "appUrl"])`.

## Publish to the Chrome Web Store

1. Zip the folder: `cd extension && zip -r ../dscvr-extension.zip . -x README.md`.
2. Register at the Chrome Web Store developer dashboard (one-time US$5 fee) and upload the zip.
3. The listing needs: a 128x128 icon (`icons/128.png`), at least one 1280x800 screenshot, a short description,
   a privacy policy URL (`https://www.askpinda.com/privacy`), and a reason for each permission:
   - `activeTab` / `scripting`: read the page the user asks to save, cite or ask about
   - `sidePanel`: show DSCVR next to the page
   - `storage`: keep the sign-in token and last-used category
   - `contextMenus`: "Save page to DSCVR" and "Ask Pinda" on right-click
   - host access to the DSCVR server: save to the library and call Pinda
   - optional access to all sites: read pages without clicking the toolbar button first, only if the user allows it
4. Review usually takes a few days. The same zip works on the Microsoft Edge Add-ons store.
