export function Hero() {
  return (
    <section className="relative pt-32 pb-24 md:pt-44 md:pb-36 overflow-hidden grain">
      <div className="relative z-10 max-w-6xl mx-auto px-6">
        <div className="max-w-3xl mx-auto text-center">
          {/* Pill badge */}
          <div className="fade-up inline-flex items-center gap-2 px-4 py-1.5 mb-8 border border-border rounded-full text-xs font-medium text-muted">
            <span className="w-1.5 h-1.5 bg-green-500 rounded-full" />
            Now in beta
          </div>

          {/* Main headline — Mindly / Google Research style */}
          <h1 className="fade-up delay-1">
            <span className="block font-serif text-5xl md:text-7xl lg:text-8xl font-bold tracking-tight leading-[1.05]">
              Research,
            </span>
            <span className="block font-serif text-5xl md:text-7xl lg:text-8xl font-bold tracking-tight leading-[1.05] italic text-muted/60">
              organized.
            </span>
          </h1>

          {/* Subline */}
          <p className="fade-up delay-2 mt-8 text-lg md:text-xl text-muted max-w-xl mx-auto leading-relaxed">
            Save papers, highlight what matters, and let AI find
            answers grounded in your own library.
          </p>

          {/* CTAs */}
          <div className="fade-up delay-3 mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
            <a
              href="https://dscvr-9d362.web.app/?demo=true"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2.5 px-7 py-3.5 bg-foreground text-background text-sm font-semibold rounded-full hover:bg-foreground/90 transition-all hover:shadow-lg hover:shadow-foreground/10"
            >
              Try the demo
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <path d="M5 12h14M12 5l7 7-7 7" />
              </svg>
            </a>
            <a
              href="#how-it-works"
              className="inline-flex items-center gap-2 px-7 py-3.5 border border-border text-sm font-medium rounded-full hover:bg-foreground/5 transition-colors"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <circle cx="12" cy="12" r="10" />
                <polygon points="10 8 16 12 10 16 10 8" fill="currentColor" stroke="none" />
              </svg>
              See how it works
            </a>
          </div>
        </div>

        {/* Floating UI preview cards */}
        <div className="fade-up delay-4 relative mt-20 md:mt-28 max-w-4xl mx-auto">
          {/* Main app preview */}
          <div className="relative bg-white rounded-2xl border border-border shadow-2xl shadow-foreground/5 overflow-hidden">
            <div className="h-8 bg-gray-50 border-b border-border flex items-center px-4 gap-2">
              <div className="w-2.5 h-2.5 rounded-full bg-gray-300" />
              <div className="w-2.5 h-2.5 rounded-full bg-gray-300" />
              <div className="w-2.5 h-2.5 rounded-full bg-gray-300" />
              <div className="ml-4 h-4 w-48 bg-gray-200 rounded-full" />
            </div>
            <div className="p-6 md:p-10">
              {/* Simulated app UI */}
              <div className="flex gap-6">
                {/* Sidebar */}
                <div className="hidden md:block w-48 space-y-3">
                  <div className="h-5 w-24 bg-gray-100 rounded" />
                  <div className="space-y-2 mt-4">
                    <div className="h-9 bg-gray-100 rounded-lg px-3 flex items-center">
                      <div className="w-3.5 h-3.5 bg-gray-300 rounded mr-2" />
                      <div className="h-3 w-16 bg-gray-300 rounded" />
                    </div>
                    <div className="h-9 bg-foreground/5 rounded-lg px-3 flex items-center">
                      <div className="w-3.5 h-3.5 bg-foreground/20 rounded mr-2" />
                      <div className="h-3 w-20 bg-foreground/20 rounded" />
                    </div>
                    <div className="h-9 bg-gray-100 rounded-lg px-3 flex items-center">
                      <div className="w-3.5 h-3.5 bg-gray-300 rounded mr-2" />
                      <div className="h-3 w-14 bg-gray-300 rounded" />
                    </div>
                    <div className="h-9 bg-gray-100 rounded-lg px-3 flex items-center">
                      <div className="w-3.5 h-3.5 bg-gray-300 rounded mr-2" />
                      <div className="h-3 w-12 bg-gray-300 rounded" />
                    </div>
                  </div>
                </div>
                {/* Content */}
                <div className="flex-1 space-y-4">
                  <div className="flex gap-3">
                    {[1, 2, 3].map((i) => (
                      <div key={i} className="flex-1 p-4 bg-gray-50 rounded-xl border border-gray-100">
                        <div className="h-20 bg-gray-200 rounded-lg mb-3" />
                        <div className="h-3 w-3/4 bg-gray-200 rounded mb-2" />
                        <div className="h-3 w-1/2 bg-gray-100 rounded" />
                      </div>
                    ))}
                  </div>
                  <div className="p-4 bg-gray-50 rounded-xl border border-gray-100">
                    <div className="h-3 w-full bg-gray-200 rounded mb-2" />
                    <div className="h-3 w-5/6 bg-gray-200 rounded mb-2" />
                    <div className="h-3 w-2/3 bg-gray-100 rounded" />
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Floating card: Discover */}
          <div className="float-1 absolute -top-6 -left-4 md:-left-12 bg-white rounded-xl border border-border shadow-lg shadow-foreground/5 p-4 w-48">
            <div className="flex items-center gap-2 mb-2">
              <div className="w-6 h-6 bg-blue-100 rounded-lg flex items-center justify-center">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#3B82F6" strokeWidth="2.5"><circle cx="11" cy="11" r="7" /><path d="M21 21l-4.35-4.35" /></svg>
              </div>
              <span className="text-xs font-semibold">Discover</span>
            </div>
            <p className="text-[10px] text-muted leading-relaxed">Search arXiv and Semantic Scholar in one place.</p>
          </div>

          {/* Floating card: Pinda AI */}
          <div className="float-2 absolute -bottom-4 -right-4 md:-right-10 bg-white rounded-xl border border-border shadow-lg shadow-foreground/5 p-4 w-52">
            <div className="flex items-center gap-2 mb-2">
              <div className="w-6 h-6 bg-purple-100 rounded-lg flex items-center justify-center">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#8B5CF6" strokeWidth="2.5"><path d="M12 2a7 7 0 0 1 7 7c0 3-2 5-3.5 6.5L12 19l-3.5-3.5C7 14 5 12 5 9a7 7 0 0 1 7-7z" /></svg>
              </div>
              <span className="text-xs font-semibold">Pinda AI</span>
              <span className="ml-auto text-[9px] px-1.5 py-0.5 bg-amber-100 text-amber-700 rounded-full font-medium">Soon</span>
            </div>
            <p className="text-[10px] text-muted leading-relaxed">Ask questions. Get answers grounded in your library.</p>
          </div>

          {/* Floating card: Parliament */}
          <div className="float-3 absolute top-1/3 -right-4 md:-right-16 bg-white rounded-xl border border-border shadow-lg shadow-foreground/5 p-3 w-44">
            <div className="flex items-center gap-2 mb-1.5">
              <div className="w-5 h-5 bg-green-100 rounded-lg flex items-center justify-center">
                <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#22C55E" strokeWidth="2.5"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" /></svg>
              </div>
              <span className="text-[11px] font-semibold">Fact-Check</span>
            </div>
            <p className="text-[10px] text-muted">3 AI perspectives on every claim.</p>
          </div>
        </div>
      </div>
    </section>
  );
}
