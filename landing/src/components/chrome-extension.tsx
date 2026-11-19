import { CHROME_EXTENSION_URL } from "@/lib/site";

const points: [string, string][] = [
  ["Save in one click", "Papers, articles and YouTube lectures go straight into a category and topic, with title, authors, year and DOI filled in."],
  ["Find the free PDF", "On a paywalled paper, DSCVR looks for a free, legal copy and attaches it when you save."],
  ["Ask Pinda about the page", "Summarise it, pull out the methods and findings, or highlight a paragraph and ask what it means."],
  ["Cite it", "APA, Harvard, Vancouver, MLA, Chicago, OSCOLA, Nigerian legal style or BibTeX, copied in a click."],
];

export function ChromeExtension() {
  const live = Boolean(CHROME_EXTENSION_URL);
  return (
    <section id="chrome" className="py-24 md:py-32 bg-foreground/[0.03] border-y border-border">
      <div className="max-w-6xl mx-auto px-6">
        <div className="max-w-2xl">
          <p className="text-sm font-medium text-muted mb-3 tracking-wide uppercase">DSCVR for Chrome</p>
          <h2 className="font-serif text-3xl md:text-5xl font-bold tracking-tight leading-tight mb-6">
            Your library, <span className="italic text-muted/60">on every page.</span>
          </h2>
          <p className="text-muted leading-relaxed mb-8">
            Reading a journal article, an arXiv paper or a news story? Open DSCVR beside it. Save it, find the free
            PDF, cite it or ask Pinda about it without leaving the page.
          </p>
          <div className="flex flex-wrap items-center gap-3 mb-12">
            {live ? (
              <a href={CHROME_EXTENSION_URL} target="_blank" rel="noopener noreferrer"
                 className="inline-flex items-center gap-2 px-5 py-3 text-xs font-semibold tracking-wide uppercase bg-foreground text-background hover:bg-foreground/90 transition-colors">
                Add to Chrome, it&apos;s free
              </a>
            ) : (
              <span className="inline-flex items-center gap-2 px-5 py-3 text-xs font-semibold tracking-wide uppercase border border-border bg-white text-muted">
                Coming soon to the Chrome Web Store
              </span>
            )}
            <span className="text-xs text-muted">Works in Chrome, Edge, Brave and Arc.</span>
          </div>
        </div>

        <div className="grid lg:grid-cols-[1fr_1.5fr] gap-10 lg:gap-14 items-center">
          <div className="space-y-6 order-2 lg:order-1">
            {points.map(([title, body]) => (
              <div key={title} className="flex items-start gap-3">
                <div className="mt-1 w-5 h-5 rounded-full bg-foreground flex items-center justify-center shrink-0">
                  <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><path d="M20 6L9 17l-5-5" /></svg>
                </div>
                <div>
                  <p className="text-sm font-semibold">{title}</p>
                  <p className="text-sm text-muted leading-relaxed mt-0.5">{body}</p>
                </div>
              </div>
            ))}
          </div>
          <div className="order-1 lg:order-2">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/chrome-extension.webp" width={1100} height={640} loading="lazy"
                 alt="The DSCVR panel open beside a journal article, with Pinda explaining a highlighted sentence"
                 className="w-full h-auto rounded-xl shadow-xl shadow-foreground/10" />
          </div>
        </div>
      </div>
    </section>
  );
}
