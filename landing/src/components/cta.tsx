export function CTA() {
  return (
    <section className="py-24 md:py-32 bg-foreground text-background relative overflow-hidden">
      {/* Grain */}
      <div className="absolute inset-0 opacity-[0.04]" style={{
        backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.8' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='1'/%3E%3C/svg%3E")`,
        backgroundSize: '256px 256px',
      }} />

      <div className="relative z-10 max-w-3xl mx-auto px-6 text-center">
        <h2 className="font-serif text-4xl md:text-6xl font-bold tracking-tight leading-tight mb-6">
          Less noise. <br />
          <span className="italic text-background/50">More signal.</span>
        </h2>
        <p className="text-background/60 text-lg mb-10 max-w-lg mx-auto">
          Stop drowning in tabs. Start building a research library that works as hard as you do.
        </p>
        <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
          <a
            href="https://dscvr-9d362.web.app/?demo=true"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2.5 px-8 py-4 bg-background text-foreground text-sm font-semibold rounded-full hover:bg-background/90 transition-all hover:shadow-lg"
          >
            Try the demo
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M5 12h14M12 5l7 7-7 7" />
            </svg>
          </a>
          <span className="text-sm text-background/40">No sign-up required</span>
        </div>
      </div>
    </section>
  );
}
