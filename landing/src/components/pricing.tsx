import { Icon } from "./icons";
import { SIGNUP_URL } from "@/lib/site";

const plans = [
  {
    name: "Free",
    price: "$0",
    note: "For Students and Researchers",
    blurb: "Everything in DSCVR, with a daily Pinda allowance.",
    points: ["Pinda on our fast model", "Allowance resets every day", "Library, reader, notes, voice notes", "Reports, focus sessions, study rooms", "arXiv, Semantic Scholar and journals"],
    cta: "Start free",
  },
  {
    name: "Student Plus",
    price: "$4.99",
    note: "per month",
    blurb: "For students who lean on Pinda every day.",
    points: ["5x the daily Pinda usage of Free", "Bigger monthly allowance", "More study guides, quizzes and recaps", "Everything in Free"],
    cta: "Get Student Plus",
  },
  {
    name: "Research Plus",
    price: "$9.99",
    note: "per month",
    blurb: "For researchers who read, write and review all week.",
    points: ["10x the daily Pinda usage of Free", "Our best model for reports, recaps and fact-checks", "Longer literature reviews", "Everything in Free"],
    cta: "Get Research Plus",
    featured: true,
  },
  {
    name: "DSCVR Max",
    price: "$24.99",
    note: "per month",
    blurb: "Our best model everywhere and the most usage.",
    points: ["30x the daily Pinda usage of Free", "Best model for everything, chat included", "The largest monthly allowance", "Everything in Research Plus"],
    cta: "Get Max",
  },
];

const faqs = [
  {
    q: "Is it really free for students and researchers?",
    a: "Yes. The library, reader, Discover, reports, ratings, voice and sessions are all free. Pinda comes with a daily allowance that resets every day.",
  },
  {
    q: "What do Plus and Max add?",
    a: "More Pinda. Each plan has a usage allowance, shown as a meter in the app, that resets daily and monthly. Student Plus gives 5x the daily usage of Free, Research Plus 10x with our best model for reports and fact-checks, and Max 30x with the best model everywhere.",
  },
  {
    q: "How do I pay, and can I cancel?",
    a: "Plans are billed monthly through Paystack, which accepts cards from most countries. Prices are shown in US dollars; Paystack charges the local-currency equivalent and your bank handles any conversion. Cancel any time from Settings; your plan runs to the end of the month you paid for.",
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
    q: "How does Pinda work?",
    a: "Pinda is DSCVR's research assistant, built on a leading large language model. It answers from the papers and notes you choose, names the sources it used, and says so when something isn't in your material.",
  },
];

export function Pricing() {
  return (
    <section id="pricing" className="py-24 md:py-32 bg-white border-y border-border/60">
      <div className="max-w-6xl mx-auto px-6">
        <div className="max-w-2xl mx-auto text-center mb-14">
          <p className="text-sm font-medium text-muted mb-3 tracking-wide uppercase">Pricing</p>
          <h2 className="font-serif text-3xl md:text-5xl font-bold tracking-tight leading-tight">
            Free to start. <span className="italic text-muted/60">More Pinda when you need it.</span>
          </h2>
          <p className="mt-5 text-muted">Every plan includes all of DSCVR. Paid plans give Pinda more room to work. Cancel any time.</p>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {plans.map((p) => (
            <div
              key={p.name}
              className={`rounded-3xl p-2.5 flex flex-col border ${p.featured ? "border-foreground shadow-xl shadow-foreground/10" : "border-border"} bg-white`}
            >
              <div className={`rounded-2xl p-5 ${p.featured ? "bg-foreground text-background" : "bg-gray-100"}`}>
                <div className="flex items-center justify-between">
                  <span className={`text-[11px] font-bold tracking-wider uppercase px-3 py-1 rounded-full ${p.featured ? "bg-white/10" : "bg-white"}`}>{p.name}</span>
                  {p.featured && <span className="text-[11px] font-semibold">Recommended</span>}
                </div>
                <div className="mt-6 flex items-baseline gap-1.5">
                  <span className="font-serif text-4xl font-bold tracking-tight">{p.price}</span>
                  <span className={`text-sm ${p.featured ? "text-background/60" : "text-muted"}`}>{p.note === "per month" ? "/month" : ""}</span>
                </div>
                {p.note !== "per month" && <p className="mt-1 text-xs text-muted">{p.note}</p>}
              </div>
              <p className="px-3 pt-4 text-sm font-medium min-h-[3.2rem]">{p.blurb}</p>
              <a
                href={SIGNUP_URL}
                className={`mx-1 mt-2 inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-full text-sm font-semibold transition-colors ${p.featured ? "bg-foreground text-background hover:bg-foreground/90" : "border border-border hover:bg-foreground/5"}`}
              >
                {p.cta} <Icon.arrow size={13} />
              </a>
              <ul className="px-3 pt-5 pb-4 space-y-2.5 text-sm flex-1">
                {p.points.map((x) => (
                  <li key={x} className="flex gap-2.5"><Icon.check className="mt-1 shrink-0 text-muted" size={12} />{x}</li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-5 rounded-3xl bg-foreground text-background p-7 md:p-8 grid md:grid-cols-[1.2fr_1fr] gap-6 items-center relative overflow-hidden">
          <div className="absolute -right-20 -top-20 w-64 h-64 rounded-full bg-white/5" aria-hidden />
          <div>
            <p className="text-sm font-semibold">DSCVR Enterprise</p>
            <div className="mt-3 flex items-baseline gap-2 flex-wrap">
              <span className="font-serif text-5xl font-bold tracking-tight">$0.40</span>
              <span className="text-background/60 text-sm">per active member, per day</span>
            </div>
            <p className="mt-2 text-sm text-background/60">Capped at $8 per member each month. No daily limit. AI billed by the tokens your team uses.</p>
          </div>
          <div className="flex flex-col gap-3 md:items-end">
            <ul className="grid grid-cols-2 gap-x-6 gap-y-2 text-sm">
              {["Organisation and roles", "Usage dashboard", "Team rooms", "One monthly invoice"].map((x) => (
                <li key={x} className="flex gap-2"><Icon.check className="mt-1 shrink-0" size={12} />{x}</li>
              ))}
            </ul>
            <a href={SIGNUP_URL} className="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-full text-sm font-semibold bg-background text-foreground hover:bg-background/90 transition-colors">
              Start a team <Icon.arrow size={13} />
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
