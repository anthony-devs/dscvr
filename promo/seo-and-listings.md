# DSCVR: search engines and listings kit

Everything you need to get DSCVR found: what's already built into the site, the search engines to register with, the directories to list on, and copy you can paste into each.

---

## 1. Already built into the website

These ship with the new landing site. Nothing to do except deploy.

- **Sitemap** at `https://www.askpinda.com/sitemap.xml`, listing the home page, blog, every blog post, support, privacy and terms. New posts are added automatically.
- **robots.txt** at `https://www.askpinda.com/robots.txt`, allowing everything and pointing to the sitemap.
- **Page titles and descriptions** on every page, plus canonical URLs so Google doesn't index duplicates.
- **Social previews**: a generated 1200×630 image for links shared on X, LinkedIn, WhatsApp and Slack.
- **Structured data** Google reads: `SoftwareApplication` (with the four prices) and `Organization` on the home page, `BlogPosting` on every article.
- **Blog** at `/blog` with 7 articles aimed at real searches (see section 5).

---

## 2. Search engines (do these first)

### Google Search Console

1. Go to search.google.com/search-console and sign in with your Google account.
2. Add property, choose **Domain**, enter `askpinda.com`.
3. Google shows a TXT record like `google-site-verification=...`. Add it in OpenSRS: Name Servers/DNS, Modify DNS Zone, new TXT record on `@`. I can add this for you when you're signed in to OpenSRS.
4. Click Verify (can take a few minutes to an hour).
5. Sitemaps, enter `sitemap.xml`, Submit.
6. URL inspection, paste `https://www.askpinda.com`, Request indexing. Repeat for `/blog` and each post.

### Bing Webmaster Tools (also covers DuckDuckGo, Yahoo and Ecosia, which use Bing's index)

1. Go to bing.com/webmasters.
2. Choose **Import from Google Search Console**. It copies the verified site and sitemap in one step.

### Others worth a minute

- **Yandex Webmaster** (webmaster.yandex.com): add the site and sitemap if you want reach in Eastern Europe and Central Asia.
- **IndexNow**: Bing and Yandex accept instant pings when you publish. Optional; I can add it later.

---

## 3. Directories and launch sites

Ordered by how useful they are for a product like DSCVR. Some charge for faster listing; rules change, so check each site's current terms. I can't create these accounts for you, but every listing below can be filled from the copy in section 4.

### AI tool directories (high-intent traffic)

| Site | Notes |
| --- | --- |
| There's An AI For That (theresanaiforthat.com) | The biggest AI directory. Paid submission. |
| Futurepedia (futurepedia.io) | Large AI directory. Free or paid submission. |
| Toolify (toolify.ai) | Large AI directory. Paid submission. |
| AI Tool Hunt, TopAI.tools, AItoolsclub | Smaller, mostly free. Good for backlinks. |

### Launch platforms (pick one launch day, do them together)

| Site | Notes |
| --- | --- |
| Product Hunt (producthunt.com) | Schedule the launch for a Tuesday to Thursday. Prepare the gallery images and a first comment. |
| Hacker News, "Show HN" | Title: "Show HN: DSCVR, search papers and ask an AI that answers only from your library". Post on a weekday morning US time. Reply to every comment. |
| Peerlist Launchpad (peerlist.io) | Weekly launches, developer-friendly audience. |
| Uneed (uneed.best), Microlaunch (microlaunch.net), Fazier (fazier.com) | Smaller launch sites, free tiers, good backlinks. |
| BetaList (betalist.com) | For early-stage products. Free with a wait, or paid to skip it. |

### Software directories (comparison shoppers)

| Site | Notes |
| --- | --- |
| AlternativeTo (alternativeto.net) | List DSCVR as an alternative to Elicit, Consensus, SciSpace, Zotero, Mendeley and Quizlet. |
| SaaSHub (saashub.com) | Free listing, similar "alternatives" pages. |
| G2 and Capterra | Free vendor listing. Worth it once you have a few reviews from real users. |

### Profiles that build trust

- **Crunchbase**: company profile with founder, founding date and links.
- **LinkedIn company page**: "DSCVR", link to askpinda.com, post each blog article.
- **X / Instagram bios**: link to `https://www.askpinda.com` (always the www link until the bare domain moves to Cloudflare).
- **GitHub profile README**: add DSCVR to your pinned projects with the link.

### Communities (share help, not ads)

Read each community's rules first; most allow sharing your own work only in specific threads.

- Reddit: r/GradSchool, r/PhD, r/medicalschool, r/nursing, r/LawSchool, r/AskAcademia, r/studytips, r/SideProject, r/indiehackers.
- Indie Hackers: post the "I built" story as a milestone.
- Student Discord servers and university societies: offer a free walkthrough.

---

## 4. Copy to paste

**Name:** DSCVR

**URL:** https://www.askpinda.com

**Tagline (under 60 characters):**
Search papers, read with AI, and write it up.

**Short description (under 160 characters):**
Search arXiv, PubMed and journals at once, read PDFs with Pinda, an AI that answers from your own library, and turn reading into flashcards and cited reports.

**Long description:**
DSCVR is a research desk for students, researchers, clinicians and lawyers. One search covers arXiv, Semantic Scholar, OpenAlex, Europe PMC, Crossref, DOAJ, PLOS and Zenodo, plus clinical guidelines and UK case law, with every result labelled by source and a filter for free PDFs. Save papers, PDFs, links, YouTube lectures and notes into a library you organise your way, and read them in a built-in PDF reader.

Pinda, DSCVR's AI research assistant, answers questions from the material you choose: one paper, a topic or your whole library. It reads the full PDFs, names its sources, and says when something isn't in your material. Turn any reading into flashcards, practice questions, case briefs or evidence summaries; draft literature reviews and comparisons from up to 40 sources with numbered citations; fact-check claims with Parliament, where three AI readers vote and explain their reasoning; and study in timed focus sessions or live rooms with a recap at the end. Cite in APA, Harvard, Vancouver, MLA, Chicago or OSCOLA, and export to Zotero, Mendeley or EndNote.

Free for students and researchers, with paid plans for heavier AI use and a usage-based plan for teams.

**Categories:** Education, Research, AI assistant, Productivity, Note-taking, Study tools

**Tags:** AI research assistant, academic search, literature review, PDF reader, flashcards, study app, medical students, law students, citations

**Pricing:** Free; Student Plus $4.99/month; Research Plus $9.99/month; DSCVR Max $24.99/month; Enterprise usage-based ($0.40 per active member per day, capped at $8 per member per month, plus AI usage).

**Alternatives to list against:** Elicit, Consensus, SciSpace, Semantic Scholar, Zotero, Mendeley, Quizlet, Anki, NotebookLM.

**Founder:** Anthony Ude

**Contact:** mail@askpinda.com

**Assets:** use the Instagram carousel images and the 14.6-second reel from `promo/` for gallery slots. Product Hunt wants 1270×760 images; I can render those on request.

---

## 5. The blog (SEO on your own domain)

Seven articles are live at `askpinda.com/blog`, each aimed at a search people really make, each ending with a DSCVR call to action:

| Article | Search it targets |
| --- | --- |
| How to write a literature review, step by step | "how to write a literature review" |
| Where to find free research papers: 10 sources worth knowing | "free research papers", "free academic databases" |
| How to read a research paper quickly | "how to read a research paper" |
| How to brief a case: a template law students can reuse | "how to brief a case", "case brief template" |
| Active recall for exams: flashcards and practice questions | "active recall", "how to make flashcards" |
| Why AI chatbots make up citations | "ChatGPT fake citations", "AI hallucinated references" |
| The Pomodoro technique for studying | "pomodoro technique for studying" |

**To add a post:** create a new `.md` file in `landing/content/blog/` with the same header block (title, description, date, author, tags). Put `<!-- cta -->` where you want the DSCVR box to appear. Deploy, and it appears on `/blog` and in the sitemap automatically.

**Cadence that works:** one new post a week for the first three months. Search traffic builds slowly: expect the first visits after 4 to 8 weeks, more after 3 to 6 months.

**Ideas for the next posts:** how to write a systematic review protocol; PICO questions explained; how to cite a court case in OSCOLA; how to study for nursing exams; Zotero vs Mendeley; how to summarise a research paper; how to find the ratio decidendi; how to write a discussion section.

---

## 6. Medium

Four articles are in `promo/medium/`, written to be different from the blog posts so they don't compete with them in search. Paste each into Medium's editor, add a cover image, and add these tags: Research, Artificial Intelligence, Education, Students, Productivity. Each ends with a link back to askpinda.com.

Also worth submitting to Medium publications that accept outside writers, such as those focused on education, AI or startups. Check each publication's submission guidelines first.
