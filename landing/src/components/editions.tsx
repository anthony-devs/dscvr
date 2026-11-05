import { Icon } from "./icons";
import { SIGNUP_URL } from "@/lib/site";

const editions = [
  {
    icon: Icon.cap,
    name: "DSCVR Students",
    line: "Study smarter, not longer.",
    body: "Pinda explains in plain language, quizzes you and turns lectures into study notes.",
    points: ["Study notes and exam prep from your sources", "Focus timer with an AI recap", "Group study rooms with a shared timer", "Voice notes in lectures"],
  },
  {
    icon: Icon.flask,
    name: "DSCVR Researchers",
    line: "The research desk, complete.",
    body: "Precise, citation-first answers and drafts for people who live in papers.",
    points: ["arXiv PDFs and Semantic Scholar related work", "Literature reviews and paper comparisons", "Parliament fact-check on any claim", "Community paper ratings"],
    featured: true,
  },
  {
    icon: Icon.building,
    name: "DSCVR Enterprise",
    line: "Your team's shared brain.",
    body: "Everything in Researchers for a whole lab, company or department, billed only for what you use.",
    points: ["Organisation with invite codes and roles", "Usage dashboard and monthly invoices", "Team rooms and shared papers", "Admin control over members and devices"],
  },
];

export function Editions() {
  return (
    <section id="editions" className="py-24 md:py-32 border-t border-border/60">
      <div className="max-w-6xl mx-auto px-6">
        <div className="max-w-2xl mb-14">
          <p className="text-sm font-medium text-muted mb-3 tracking-wide uppercase">Editions</p>
          <h2 className="font-serif text-3xl md:text-5xl font-bold tracking-tight leading-tight">
            One app. <span className="italic text-muted/60">Tuned to how you work.</span>
          </h2>
          <p className="mt-5 text-muted leading-relaxed">
            Pick your edition when you sign up. It changes how Pinda talks, which reports it suggests and how sessions work.
            Switch any time from settings.
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-5">
          {editions.map((e) => (
            <div
              key={e.name}
              className={`relative rounded-2xl p-7 border flex flex-col ${
                e.featured ? "bg-foreground text-background border-foreground shadow-2xl shadow-foreground/20" : "bg-white border-border"
              }`}
            >
              <div className={`w-11 h-11 rounded-xl flex items-center justify-center mb-6 ${e.featured ? "bg-white/10" : "bg-gray-100"}`}>
                <e.icon size={21} />
              </div>
              <h3 className="text-xl font-semibold tracking-tight">{e.name}</h3>
              <p className={`font-serif italic text-lg mt-1 ${e.featured ? "text-background/60" : "text-muted"}`}>{e.line}</p>
              <p className={`text-sm leading-relaxed mt-4 ${e.featured ? "text-background/70" : "text-muted"}`}>{e.body}</p>
              <ul className="mt-6 space-y-2.5 text-sm flex-1">
                {e.points.map((p) => (
                  <li key={p} className="flex gap-2.5">
                    <Icon.check className={`mt-1 shrink-0 ${e.featured ? "text-background" : "text-foreground"}`} size={12} />
                    <span>{p}</span>
                  </li>
                ))}
              </ul>
              <a
                href={SIGNUP_URL}
                className={`mt-8 inline-flex items-center justify-center gap-2 px-5 py-3 rounded-full text-sm font-semibold transition-colors ${
                  e.featured ? "bg-background text-foreground hover:bg-background/90" : "border border-border hover:bg-foreground/5"
                }`}
              >
                {e.name.includes("Enterprise") ? "Start a team" : "Start free"}
                <Icon.arrow size={14} />
              </a>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
