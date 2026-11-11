# Three AI readers argue about your claim: designing a fact-checker that shows its disagreements

*Notes on building "Parliament", the fact-check feature in DSCVR.*

---

Ask one AI model whether a claim is true and you get one confident answer. The confidence is the problem. A single answer hides the uncertainty that any careful reader would feel, and it gives you nothing to push back on.

When I built the fact-check feature in DSCVR, a research app for students and researchers, I wanted the opposite: an answer that shows its working, including where the reasoning splits.

The result is called Parliament.

## The design

Parliament takes a claim and, optionally, the source material it came from. Then it asks three readers to judge it independently, each with a different brief:

- **The Advocate** looks for the strongest reading of the evidence in favour of the claim.
- **The Skeptic** looks for weaknesses, missing context and alternative explanations.
- **The Analyst** weighs the evidence as neutrally as it can.

Each reader returns the same structure:

- a **verdict**: supported, partially supported, unsupported, misleading, or insufficient evidence;
- a **confidence** score;
- a short paragraph of **reasoning**.

The three readers run in parallel, so the whole thing takes roughly as long as one answer.

## Consensus, and what happens when there isn't one

If two or more readers agree, that's the consensus. If all three disagree, the consensus is "partially supported", which in practice means "this is contested, read the reasoning".

Finally, a fourth step writes a two-to-three sentence synthesis of the three perspectives. It's deliberately short. The point is to send you to the reasoning, not to replace it.

## Why structure beats prose

Each reader has to return a verdict from a fixed list, a number and a paragraph. Forcing structured output does two useful things.

First, it stops the model from hedging forever. "It's complicated" isn't on the list.

Second, it makes disagreement visible. A user sees three bars, three verdicts and three confidence scores before reading a word. When the Skeptic sits at "misleading" and the Advocate at "supported", you know immediately that the claim deserves a closer look.

## Grounding matters more than the number of readers

Three readers arguing from memory is still three readers arguing from memory. Parliament is most useful when it's given the source: in DSCVR, you can run it on a claim from a paper in your library, and the readers judge it against that material.

Parliament also doesn't go and fetch new evidence. It judges the claim and the material you gave it. That's a limitation, and I'd rather state it plainly than pretend otherwise. It's a way to stress-test a claim, not an oracle.

## What it's good for

- Checking a sentence before you build a paragraph of your essay on it.
- Seeing whether a striking result in an abstract survives a skeptical read.
- Practising critical appraisal: reading the Skeptic's reasoning teaches you what to look for.

## What I learned

The most useful output isn't the verdict. It's the disagreement. When three readers agree, you move on. When they don't, you've found exactly the place where you need to read more carefully, and that's what a good research tool should do: point your attention, not replace it.

Parliament is part of DSCVR, alongside one search across arXiv, PubMed, Semantic Scholar and other free sources, a library with a built-in PDF reader, and Pinda, an assistant that answers from the papers you saved. It's free to start at [askpinda.com](https://www.askpinda.com).
