# I built an AI research assistant that answers from your papers, not from guesswork

*Why I built DSCVR, and what I learned trying to make AI useful for real research.*

---

The first time an AI chatbot gave me a citation that didn't exist, I almost used it.

It looked perfect. Real authors, a real journal, a sensible year, a title that matched exactly what I needed. I only caught it because I went to download the PDF and there was nothing to download. The paper had never been written.

That moment stuck with me, because the problem wasn't the AI being "bad". It was doing exactly what it was built to do: produce text that looks right. The trouble is that research isn't about what looks right. It's about what you can point to.

So I started building DSCVR.

## The problem I kept running into

Doing research as a student looks something like this:

- PubMed in one tab, Google Scholar in another, arXiv in a third, a law report site in a fourth.
- PDFs in Downloads, in email attachments, in a reference manager I stopped updating in week three.
- An AI chatbot in yet another tab, answering from the whole internet, with no idea what I'd actually read.

Every one of those tools is fine on its own. Together they're a mess, and the mess costs hours.

## The idea: one desk, and an assistant that reads what you read

DSCVR does three things in one place.

**1. Find.** One search runs across arXiv, Semantic Scholar, OpenAlex, Europe PMC, Crossref, DOAJ, PLOS and Zenodo at once. Results are merged, duplicates removed, and every result is labelled with where it came from. You can switch to clinical sources for health questions or to UK case law for legal ones, and filter to papers with a free PDF.

**2. Read.** Everything you save goes into a library you organise your way: categories and topics, not rigid folders. PDFs open in a built-in reader. You can add notes, rate what you read, and see related papers beside it.

**3. Ask and write.** This is where Pinda comes in.

## Pinda, and the rule that shaped it

Pinda is DSCVR's research assistant. It's a pangolin, because pangolin scales look like the pages of a book.

The rule I built Pinda around is simple: **answer from the material the user chose, and say so when the answer isn't there.**

In practice that means:

- You choose what Pinda reads: one paper, a topic, a whole category, a hand-picked selection, or your entire library.
- Pinda reads the full PDFs, not just abstracts, along with your own notes.
- It names the source it used in its answer.
- If something isn't in your material, it says so, and labels anything that comes from general knowledge.
- It's instructed never to invent citations, quotes or statistics.

No AI is perfect, and grounding reduces mistakes rather than removing them. But it changes the relationship. Instead of trusting a chatbot's memory, you're asking a reader about pages you can open and check.

## The features people actually use

When I started, I thought chat would be the main thing. It isn't. What students and researchers lean on most are the tools that turn reading into something useful:

- **Study sets:** flashcards, exam-style practice questions with explanations, case briefs for judgments, and evidence summaries for clinical studies, all generated from one item in your library.
- **Reports:** literature reviews, executive summaries, study notes and comparisons drafted from up to 40 sources you pick, with numbered citations back to them. You edit the draft and export it as Markdown.
- **Parliament:** a fact-check where three AI readers (an advocate, a skeptic and an analyst) each give a verdict, a confidence score and their reasoning, followed by a short summary of where they agree.
- **Focus sessions:** a timer, a notes box and your sources side by side, and a recap at the end with what you covered and what to do next. There are live sessions too, for studying with friends.
- **Citations:** APA, Harvard, Vancouver, MLA, Chicago and OSCOLA, with BibTeX and RIS export for Zotero, Mendeley and EndNote.

## What I'd tell anyone using AI for research

Whether or not you ever use DSCVR, three habits will save you:

1. **Find real sources first**, in real databases.
2. **Make the AI answer from those sources**, not from memory.
3. **If you cite it, open it.** Find the sentence on the page.

## Try it

DSCVR is free for students and researchers, with a daily Pinda allowance. If you rely on Pinda every day, paid plans give it more room.

You can try it at [askpinda.com](https://www.askpinda.com). I read every message that comes in, so tell me what's missing.

*Anthony Ude, builder of DSCVR*
