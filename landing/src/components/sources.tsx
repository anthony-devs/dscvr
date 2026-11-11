const sources = ["arXiv", "PubMed", "Semantic Scholar", "OpenAlex", "Crossref", "DOAJ", "PLOS", "Zenodo", "UK case law"];

/** The free scholarly sources Discover searches, shown as plain names (not logos). */
export function Sources() {
  return (
    <section aria-label="Sources DSCVR searches">
      <div className="rails max-w-6xl mx-auto px-6 md:px-10 pb-16 md:pb-20">
        <p className="text-[11px] font-semibold tracking-widest uppercase text-muted text-center">One search across</p>
        <ul className="mt-6 flex flex-wrap justify-center gap-x-8 md:gap-x-12 gap-y-4">
          {sources.map((s) => (
            <li key={s} className="text-lg md:text-xl font-semibold tracking-tight text-foreground/70">
              {s}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
