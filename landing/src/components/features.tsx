import { Icon } from "./icons";

const features = [
  {
    icon: Icon.paper,
    title: "arXiv, straight to your desk",
    description: "Paste an arXiv link or ID. DSCVR pulls the metadata and saves the full PDF into your library, ready to read offline.",
    tag: "New",
  },
  {
    icon: Icon.graph,
    title: "Semantic Scholar built in",
    description: "Search arXiv and Semantic Scholar from one bar, then open any paper's related work without leaving the reader.",
    tag: "New",
  },
  {
    icon: Icon.pinda,
    title: "Pinda, powered by Claude",
    description: "Ask questions across your whole library, one topic or a single paper. Pinda reads the PDFs and cites them back.",
    tag: "Live",
  },
  {
    icon: Icon.report,
    title: "Reports that write with you",
    description: "Literature reviews, summaries, study notes and comparisons, drafted from the sources you pick. Edit, then export.",
    tag: "New",
  },
  {
    icon: Icon.star,
    title: "Rate what you read",
    description: "Star papers and materials, sort your library by what mattered, and see how other readers rated a paper in Discover.",
    tag: "New",
  },
  {
    icon: Icon.mic,
    title: "Talk to your research",
    description: "Dictate notes while you read and ask Pinda out loud. It can answer back in voice, so your hands stay on the page.",
    tag: "New",
  },
  {
    icon: Icon.timer,
    title: "Focus and group sessions",
    description: "Run a timed focus block with notes, or open a live room to study with others. Pinda writes the recap when you finish.",
    tag: "New",
  },
  {
    icon: Icon.scale,
    title: "Parliament fact-check",
    description: "Three independent AI readers vote on a claim, then a synthesis explains where they agree and where the evidence is thin.",
  },
  {
    icon: Icon.devices,
    title: "Everywhere you are",
    description: "Installable on phone, tablet and desktop. Your library syncs, and you can see and sign out every device from settings.",
  },
];

export function Features() {
  return (
    <section id="features" className="py-24 md:py-32">
      <div className="max-w-6xl mx-auto px-6">
        <div className="max-w-2xl mb-16 md:mb-20">
          <p className="text-sm font-medium text-muted mb-3 tracking-wide uppercase">Features</p>
          <h2 className="font-serif text-3xl md:text-5xl font-bold tracking-tight leading-tight">
            Find it, read it, <br className="hidden md:block" />
            <span className="italic text-muted/60">understand it, write it up.</span>
          </h2>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-5">
          {features.map((f) => (
            <div
              key={f.title}
              className="group p-6 md:p-7 rounded-2xl border border-border bg-white hover:shadow-lg hover:shadow-foreground/5 transition-all duration-300 hover:-translate-y-1"
            >
              <div className="flex items-start justify-between mb-5">
                <div className="w-11 h-11 rounded-xl bg-gray-100 flex items-center justify-center text-foreground group-hover:bg-foreground group-hover:text-background transition-colors duration-300">
                  <f.icon size={21} />
                </div>
                {f.tag && (
                  <span className="text-[10px] font-semibold tracking-wide uppercase px-2 py-0.5 rounded-full border border-border text-muted">
                    {f.tag}
                  </span>
                )}
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
