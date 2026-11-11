---
title: Why AI chatbots make up citations, and how to use AI for research safely
description: Why general-purpose chatbots produce references that don't exist, how to spot them, and a safer way to use AI for reading and writing research.
date: 2026-11-06
author: The DSCVR team
tags: [AI for research, citations, academic integrity, ChatGPT]
---

If you've asked a general AI chatbot for sources, you may have received a perfectly formatted reference to a paper that doesn't exist. The authors are real, the journal is real, the title sounds right. The paper isn't.

This isn't a rare glitch. It follows from how these models work.

## Why it happens

A large language model writes by predicting likely text. Ask it for a reference and it produces something that looks like a reference: plausible authors, a plausible journal, a plausible year. Unless it's connected to a real database of papers and told to use only what's there, nothing forces that reference to point to a real document.

The same thing happens with quotes, statistics and case citations. Lawyers have been sanctioned by courts for filing briefs that cited cases a chatbot invented.

## How to spot a fake citation

- Search the exact title in Crossref, Google Scholar or the journal's site. No result is a red flag.
- Check the DOI. If it doesn't resolve, or resolves to a different paper, the citation is wrong.
- Check that the authors actually work in that field.
- Open the paper and find the claim. If you can't find it, don't cite it.

<!-- cta -->

## A safer way to use AI for research

The fix isn't to avoid AI. It's to change what the AI is answering from. Instead of asking a model what it remembers about the world, give it the sources and ask it questions about those sources. This is often called grounding.

A grounded workflow looks like this:

1. **Find real sources first**, in real databases.
2. **Give the AI those sources**, ideally the full text, not just abstracts.
3. **Ask it to answer only from them**, and to say when the answer isn't there.
4. **Check the important claims** against the page.

## How DSCVR does this

DSCVR was designed around that workflow:

- **Discover** searches real scholarly databases, so every paper in your library exists and links to its source.
- **Pinda**, DSCVR's AI research assistant, answers from the material you choose: one paper, a topic, a category, a selection or your whole library. It reads the full PDFs, names the sources it used, and says plainly when something isn't in your material. It's instructed never to invent citations, quotes or statistics.
- **Reports** are drafted only from the sources you pick, with numbered citations back to them.
- **Parliament** fact-checks a claim with three AI readers who each give a verdict, a confidence score and their reasoning.

No AI is perfect, and grounding reduces errors rather than eliminating them. The habit that protects you is the same one good researchers have always had: if you cite it, you've read it.
