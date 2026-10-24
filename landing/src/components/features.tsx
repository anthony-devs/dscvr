const features = [
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M4 19.5A2.5 2.5 0 016.5 17H20" />
        <path d="M6.5 2H20v20H6.5A2.5 2.5 0 014 19.5v-15A2.5 2.5 0 016.5 2z" />
        <path d="M8 7h8M8 11h5" />
      </svg>
    ),
    title: "Your library, your way",
    description:
      "Papers, PDFs, links, notes, YouTube lectures. Save them all in one organized space with topics and categories you define.",
  },
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="11" cy="11" r="8" />
        <path d="M21 21l-4.35-4.35" />
        <path d="M8 8h6M8 11h4" />
      </svg>
    ),
    title: "Discover new research",
    description:
      "Search arXiv and Semantic Scholar directly in the app. No tab-switching, no CORS headaches. One search bar, all the papers.",
  },
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M9 11l3 3L22 4" />
        <path d="M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11" />
      </svg>
    ),
    title: "Parliament Fact-Check",
    description:
      "Three AI perspectives — Advocate, Skeptic, Analyst — evaluate every claim. Not one opinion. A verdict from a panel.",
  },
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
        <path d="M8 21h8M12 17v4" />
      </svg>
    ),
    title: "Works everywhere",
    description:
      "Install as a PWA on any device. Your library syncs across desktop, tablet and phone. Offline-ready with bundled fonts.",
  },
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
        <path d="M9 12l2 2 4-4" />
      </svg>
    ),
    title: "Secure by design",
    description:
      "Dedicated server with Firebase auth, rate limiting, abuse detection, and token verification on every request. Your data stays yours.",
  },
  {
    icon: (
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
        <path d="M16 21v-2a4 4 0 00-4-4H5a4 4 0 00-4-4v-2" />
        <path d="M8.56 3.44a2 2 0 100 2.83" />
        <path d="M18 8h.01M18 12h.01M18 16h.01" />
        <path d="M13 6l3-3 3 3" />
        <path d="M16 3v10" />
      </svg>
    ),
    title: "Share and collaborate",
    description:
      "Figma-style link sharing with view, fork, and comment permissions. Share your research desk with collaborators.",
  },
];

export function Features() {
  return (
    <section id="features" className="py-24 md:py-32">
      <div className="max-w-6xl mx-auto px-6">
        {/* Section heading */}
        <div className="max-w-2xl mb-16 md:mb-20">
          <p className="text-sm font-medium text-muted mb-3 tracking-wide uppercase">Features</p>
          <h2 className="font-serif text-3xl md:text-5xl font-bold tracking-tight leading-tight">
            Everything a researcher <br className="hidden md:block" />
            <span className="italic text-muted/60">actually needs.</span>
          </h2>
        </div>

        {/* Grid */}
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((f, i) => (
            <div
              key={i}
              className="group p-6 md:p-8 rounded-2xl border border-border bg-white hover:shadow-lg hover:shadow-foreground/5 transition-all duration-300 hover:-translate-y-1"
            >
              <div className="w-12 h-12 rounded-xl bg-gray-100 flex items-center justify-center mb-5 text-foreground group-hover:bg-foreground group-hover:text-background transition-colors duration-300">
                {f.icon}
              </div>
              <h3 className="font-semibold text-lg mb-2">{f.title}</h3>
              <p className="text-sm text-muted leading-relaxed">{f.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
