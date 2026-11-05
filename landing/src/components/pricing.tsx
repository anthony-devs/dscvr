import { Icon } from "./icons";
import { SIGNUP_URL } from "@/lib/site";

const faqs = [
  {
    q: "Is it really free for students and researchers?",
    a: "Yes. The library, reader, Discover, reports, ratings, voice and sessions are free. Pinda includes 40 AI requests a day, which resets every day.",
  },
  {
    q: "How is Enterprise billed?",
    a: "Like an API, by usage. A member counts as active on a day they open DSCVR, and you never pay more than $8 for any member in a month. AI is billed by the tokens your team actually uses.",
  },
  {
    q: "What does a typical team pay?",
    a: "A 10-person lab where everyone works 15 days a month pays $60 for seats, plus AI. Someone who opens DSCVR twice that month costs $0.80.",
  },
  {
    q: "Which model powers Pinda?",
    a: "Pinda runs on Claude by Anthropic. Answers are grounded in the papers and notes you choose, with citations back to them.",
  },
];

export function Pricing() {
  return (
    <section id="pricing" className="py-24 md:py-32 bg-white border-y border-border/60">
      <div className="max-w-6xl mx-auto px-6">
        <div className="max-w-2xl mx-auto text-center mb-14">
          <p className="text-sm font-medium text-muted mb-3 tracking-wide uppercase">Pricing</p>
          <h2 className="font-serif text-3xl md:text-5xl font-bold tracking-tight leading-tight">
            Free to learn. <span className="italic text-muted/60">Pay as your team grows.</span>
          </h2>
          <p className="mt-5 text-muted">No seats to guess, no annual contract. Teams pay for the days people actually do research.</p>
        </div>

        <div className="grid lg:grid-cols-[1fr_1.35fr] gap-5 max-w-5xl mx-auto">
          <div className="rounded-2xl border border-border p-8 bg-background flex flex-col">
            <p className="text-sm font-semibold">Students and Researchers</p>
            <div className="mt-4 flex items-baseline gap-2">
              <span className="font-serif text-6xl font-bold tracking-tight">$0</span>
              <span className="text-muted text-sm">forever</span>
            </div>
            <ul className="mt-7 space-y-3 text-sm flex-1">
              {["Unlimited library and PDFs", "40 Pinda requests a day", "Reports, ratings, voice notes", "Focus and group sessions", "Every device, synced"].map((p) => (
                <li key={p} className="flex gap-2.5"><Icon.check className="mt-1 shrink-0" size={12} />{p}</li>
              ))}
            </ul>
            <a href={SIGNUP_URL} className="mt-8 inline-flex items-center justify-center gap-2 px-5 py-3 rounded-full text-sm font-semibold border border-border hover:bg-foreground/5 transition-colors">
              Start free <Icon.arrow size={14} />
            </a>
          </div>

          <div className="rounded-2xl p-8 bg-foreground text-background flex flex-col relative overflow-hidden">
            <div className="absolute -right-20 -top-20 w-64 h-64 rounded-full bg-white/5" aria-hidden />
            <p className="text-sm font-semibold">Enterprise</p>
            <div className="mt-4 flex items-baseline gap-2 flex-wrap">
              <span className="font-serif text-6xl font-bold tracking-tight">$0.40</span>
              <span className="text-background/60 text-sm">per active member, per day</span>
            </div>
            <p className="mt-2 text-sm text-background/60">Capped at $8 per member each month. Inactive days are free.</p>

            <div className="mt-7 grid sm:grid-cols-2 gap-3">
              <div className="rounded-xl bg-white/[0.06] border border-white/10 p-4">
                <p className="text-[11px] uppercase tracking-wider text-background/50">AI input</p>
                <p className="mt-1 text-lg font-semibold">$4 <span className="text-sm font-normal text-background/60">/ million tokens</span></p>
              </div>
              <div className="rounded-xl bg-white/[0.06] border border-white/10 p-4">
                <p className="text-[11px] uppercase tracking-wider text-background/50">AI output</p>
                <p className="mt-1 text-lg font-semibold">$20 <span className="text-sm font-normal text-background/60">/ million tokens</span></p>
              </div>
            </div>

            <ul className="mt-7 grid sm:grid-cols-2 gap-x-6 gap-y-3 text-sm flex-1">
              {["Everything in Researchers", "No daily AI limit", "Organisation, roles, invite codes", "Live usage dashboard", "Monthly invoice per organisation", "Remove members any time"].map((p) => (
                <li key={p} className="flex gap-2.5"><Icon.check className="mt-1 shrink-0" size={12} />{p}</li>
              ))}
            </ul>
            <a href={SIGNUP_URL} className="mt-8 inline-flex items-center justify-center gap-2 px-5 py-3 rounded-full text-sm font-semibold bg-background text-foreground hover:bg-background/90 transition-colors">
              Start a team <Icon.arrow size={14} />
            </a>
          </div>
        </div>

        <div className="max-w-3xl mx-auto mt-16 divide-y divide-border border-y border-border">
          {faqs.map((f) => (
            <details key={f.q} className="group py-5">
              <summary className="flex items-center justify-between cursor-pointer list-none font-medium">
                {f.q}
                <span className="ml-4 text-muted transition-transform group-open:rotate-45 text-xl leading-none">+</span>
              </summary>
              <p className="mt-3 text-sm text-muted leading-relaxed">{f.a}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
