# Chrome Web Store listing (paste into the developer dashboard)

**Name:** DSCVR: save papers, free PDFs, Ask Pinda

**Summary (132 characters max):**
Save papers and pages to your DSCVR library, find free PDFs, cite in any style and ask Pinda about what you're reading.

**Category:** Education (secondary: Productivity / Tools)

**Language:** English

**Description:**

DSCVR puts your research library next to every page you read.

Open a journal article, an arXiv paper, a PubMed record, a news story or a YouTube lecture, click the DSCVR icon, and a panel opens beside it.

SAVE IT
Save the page to a category and topic in your DSCVR library in one click. DSCVR reads the title, authors, year, journal and DOI that publishers put in the page, so you don't type anything. Right-click any page and choose "Save page to DSCVR" to save without opening the panel.

FIND THE FREE PDF
Hit a paywall? DSCVR checks open-access repositories for a free, legal copy of the paper (often the author's accepted version) and attaches it when you save.

ASK PINDA
Ask Pinda, DSCVR's research assistant, about the page you're on: summarise it, pull out the methods and findings, explain a hard paragraph, or check whether a claim is supported. Highlight text and right-click to ask about just that part. Pinda answers from the page, not from guesswork.

CITE IT
Copy a citation in APA 7, Harvard, Vancouver, MLA 9, Chicago, OSCOLA or Nigerian legal style, or as BibTeX for Zotero, Mendeley and LaTeX.

Everything you save appears in DSCVR on the web and your phone, where Pinda can read across your whole library, make flashcards and practice questions, and draft cited reports.

Free to start. Sign in with your DSCVR account (or create one free at askpinda.com).

Privacy: DSCVR reads a page only when you open the panel on it or use the right-click menu. It does not record your browsing history, and it sells nothing. Full policy: https://www.askpinda.com/privacy

Keyboard shortcut: Alt+Shift+D opens DSCVR.

**Images (in extension/store/):**
- Store icon: `../icons/128.png`
- Screenshots (1280x800): `screenshot-1-save.png`, `screenshot-2-ask.png`, `screenshot-3-cite.png`
- Small promo tile (440x280): `promo-small-440x280.png`
- Marquee promo tile (1400x560): `promo-marquee-1400x560.png`

**Website:** https://www.askpinda.com
**Support:** https://www.askpinda.com/support
**Privacy policy:** https://www.askpinda.com/privacy

## Privacy practices tab

**Single purpose:**
Save web pages and research papers to the user's DSCVR library, and help them read, cite and ask questions about the page they are viewing.

**Permission justifications:**
- `activeTab`: reads the page the user is on when they open DSCVR on it, so it can be saved, cited or asked about.
- `scripting`: runs the script that reads the page's title, authors, DOI and text, only on the tab the user is working with.
- `sidePanel`: shows DSCVR in Chrome's side panel next to the page.
- `storage`: keeps the user's sign-in token, last-used category and preferred citation style on their device.
- `contextMenus`: adds "Save page to DSCVR" and "Ask Pinda about the selection" to the right-click menu.
- Host permission (api.askpinda.com): the DSCVR server, used to save items to the library, look up free PDFs and answer questions.
- Optional host permission (all sites): only requested if the user chooses "Allow on all sites", so DSCVR can read pages without the toolbar button being clicked first on each one.
- Remote code: No, all code is in the package.

**Data usage (tick these):**
- Personally identifiable information: email address (shown as the signed-in account).
- Authentication information: the DSCVR sign-in token.
- Website content: text, title and details of pages the user chooses to save or ask about.

Certify: not sold to third parties; not used for purposes unrelated to the single purpose; not used to determine creditworthiness or for lending.
