const steps = [
  {
    number: "01",
    title: "Save anything",
    description:
      "Drop a paper URL, upload a PDF, paste a YouTube link, or write a note. DSCVR extracts titles, metadata and readable text automatically.",
  },
  {
    number: "02",
    title: "Organize naturally",
    description:
      "Create categories and topics that mirror how you think. Not rigid folders — a flexible, visual structure that grows with your research.",
  },
  {
    number: "03",
    title: "Read and highlight",
    description:
      "A clean reader with adjustable text size, dark mode, and inline highlights. Focus on the content, not the chrome.",
  },
  {
    number: "04",
    title: "Ask Pinda",
    description:
      "Your AI research companion reads your entire library (or a slice of it) and answers questions with citations back to your own materials.",
  },
];

export function HowItWorks() {
  return (
    <section id="how-it-works" className="py-24 md:py-32 bg-foreground text-background relative overflow-hidden">
      {/* Background decoration — like Google Research's curved lines */}
      <svg className="absolute top-0 right-0 w-96 h-96 text-background/5" viewBox="0 0 400 400" fill="none">
        <circle cx="300" cy="100" r="200" stroke="currentColor" strokeWidth="1" />
        <circle cx="300" cy="100" r="150" stroke="currentColor" strokeWidth="1" />
        <circle cx="300" cy="100" r="100" stroke="currentColor" strokeWidth="1" />
      </svg>

      <div className="relative z-10 max-w-6xl mx-auto px-6">
        <div className="max-w-2xl mb-16 md:mb-20">
          <p className="text-sm font-medium text-background/50 mb-3 tracking-wide uppercase">How it works</p>
          <h2 className="font-serif text-3xl md:text-5xl font-bold tracking-tight leading-tight">
            From chaos <br className="hidden md:block" />
            <span className="italic text-background/40">to clarity.</span>
          </h2>
        </div>

        <div className="grid md:grid-cols-2 gap-8 md:gap-12">
          {steps.map((step, i) => (
            <div key={i} className="flex gap-6 group">
              <div className="shrink-0">
                <span className="block font-serif text-4xl md:text-5xl font-bold text-background/15 group-hover:text-background/30 transition-colors">
                  {step.number}
                </span>
              </div>
              <div className="pt-2">
                <h3 className="font-semibold text-xl mb-2">{step.title}</h3>
                <p className="text-sm text-background/60 leading-relaxed">{step.description}</p>
              </div>
            </div>
          ))}
        </div>

        {/* Decorative arrow — like Google Research */}
        <div className="hidden md:block absolute bottom-12 right-24">
          <svg width="80" height="60" viewBox="0 0 80 60" fill="none" className="text-background/10">
            <path d="M5 55C15 25 45 5 75 10" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
            <path d="M65 5l10 5-5 10" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </div>
      </div>
    </section>
  );
}
