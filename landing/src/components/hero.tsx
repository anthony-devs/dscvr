import { Icon } from "./icons";
import { DEMO_URL, SIGNUP_URL } from "@/lib/site";

export function Hero() {
  return (
    <section className="relative pt-32 pb-20 md:pt-44 md:pb-32 overflow-hidden grain">
      <div className="hero-glow" aria-hidden />
      <div className="relative z-10 max-w-6xl mx-auto px-6">
        <div className="max-w-3xl mx-auto text-center">
          <a
            href="#editions"
            className="fade-up inline-flex items-center gap-2 pl-1.5 pr-4 py-1.5 mb-8 border border-border bg-white/70 rounded-full text-xs font-medium text-muted hover:text-foreground transition-colors"
          >
            <span className="px-2 py-0.5 rounded-full bg-foreground text-background text-[10px] font-semibold tracking-wide">NEW</span>
            Now for medicine, nursing, law and every other field
            <Icon.arrow size={12} />
          </a>

          <h1 className="fade-up delay-1">
            <span className="block font-serif text-5xl md:text-7xl lg:text-8xl font-bold tracking-tight leading-[1.02]">
              Research,
            </span>
            <span className="block font-serif text-5xl md:text-7xl lg:text-8xl font-bold tracking-tight leading-[1.02] italic text-muted/60">
              answered.
            </span>
          </h1>

          <p className="fade-up delay-2 mt-8 text-lg md:text-xl text-muted max-w-2xl mx-auto leading-relaxed">
            Search arXiv, PubMed, journals and case law at once, read any PDF with Pinda beside you,
            and turn what you learn into flashcards, case briefs and reports. One research desk, from first year to the courtroom.
          </p>

          <div className="fade-up delay-3 mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
            <a
              href={SIGNUP_URL}
              className="inline-flex items-center gap-2.5 px-7 py-3.5 bg-foreground text-background text-sm font-semibold rounded-full hover:bg-foreground/90 transition-all hover:shadow-lg hover:shadow-foreground/10"
            >
              Start free
              <Icon.arrow />
            </a>
            <a
              href={DEMO_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 px-7 py-3.5 border border-border bg-white/60 text-sm font-medium rounded-full hover:bg-foreground/5 transition-colors"
            >
              Try the demo
            </a>
          </div>
          <p className="fade-up delay-3 mt-4 text-xs text-muted">Free for students and researchers. No card needed.</p>
        </div>

        <div className="fade-up delay-4 relative mt-16 md:mt-24 max-w-5xl mx-auto">
          <AppPreview />

          <div className="float-1 hidden sm:block absolute -top-6 -left-4 md:-left-12 bg-white rounded-xl border border-border shadow-lg shadow-foreground/5 p-4 w-52">
            <div className="flex items-center gap-2 mb-2">
              <span className="w-7 h-7 rounded-lg bg-red-50 text-red-600 flex items-center justify-center"><Icon.paper size={14} /></span>
              <span className="text-xs font-semibold">arXiv 2310.06825</span>
            </div>
            <p className="text-[11px] text-muted leading-relaxed">PDF saved to your library. Pinda has read it.</p>
          </div>

          <div className="float-2 hidden sm:block absolute -bottom-6 -right-4 md:-right-10 bg-white rounded-xl border border-border shadow-lg shadow-foreground/5 p-4 w-56">
            <div className="flex items-center gap-2 mb-2">
              <span className="w-7 h-7 rounded-lg bg-violet-50 text-violet-600 flex items-center justify-center"><Icon.mic size={14} /></span>
              <span className="text-xs font-semibold">Voice note</span>
              <span className="ml-auto flex items-end gap-[2px] h-3">
                {[5, 9, 6, 11, 7, 4].map((h, i) => (
                  <span key={i} className="eq w-[2px] bg-violet-500 rounded-full" style={{ height: h, animationDelay: `${i * 0.12}s` }} />
                ))}
              </span>
            </div>
            <p className="text-[11px] text-muted leading-relaxed">&ldquo;Compare their ablation with the 2022 baseline...&rdquo;</p>
          </div>

          <div className="float-3 hidden md:block absolute top-1/3 -right-16 bg-white rounded-xl border border-border shadow-lg shadow-foreground/5 p-3 w-48">
            <div className="flex items-center gap-2 mb-1.5">
              <span className="w-6 h-6 rounded-lg bg-emerald-50 text-emerald-600 flex items-center justify-center"><Icon.users size={12} /></span>
              <span className="text-[11px] font-semibold">Study room</span>
              <span className="ml-auto w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
            </div>
            <p className="text-[10px] text-muted">4 people focusing. 18:42 left.</p>
          </div>
        </div>
      </div>
    </section>
  );
}

function AppPreview() {
  const nav = ["Recent", "Reading list", "Discover", "Pinda", "Reports", "Sessions"];
  return (
    <div className="relative bg-white rounded-2xl border border-border shadow-2xl shadow-foreground/10 overflow-hidden">
      <div className="h-9 bg-gray-50 border-b border-border flex items-center px-4 gap-2">
        <span className="w-2.5 h-2.5 rounded-full bg-gray-300" />
        <span className="w-2.5 h-2.5 rounded-full bg-gray-300" />
        <span className="w-2.5 h-2.5 rounded-full bg-gray-300" />
        <span className="ml-4 text-[11px] text-muted">dscvr / Reader</span>
      </div>
      <div className="flex text-left">
        <aside className="hidden md:block w-48 border-r border-border p-4 space-y-1">
          <div className="flex items-center gap-2 mb-4">
            <span className="w-6 h-6 rounded-md bg-foreground text-background text-[11px] font-bold flex items-center justify-center">D</span>
            <span className="text-sm font-semibold">DSCVR</span>
          </div>
          {nav.map((n, i) => (
            <div key={n} className={`text-[12px] px-2.5 py-1.5 rounded-md ${i === 3 ? "bg-gray-100 font-medium" : "text-muted"}`}>{n}</div>
          ))}
          <div className="pt-4 text-[10px] uppercase tracking-wider text-muted">Researchers</div>
        </aside>

        <div className="flex-1 grid md:grid-cols-[1.25fr_1fr] min-h-[340px]">
          <div className="p-5 md:p-7 border-r border-border">
            <p className="text-[10px] uppercase tracking-wider text-muted mb-2">arXiv · 2023</p>
            <h3 className="font-serif text-xl md:text-2xl font-bold leading-snug">Mistral 7B</h3>
            <div className="flex items-center gap-1 mt-2 text-amber-500">
              {[0, 1, 2, 3].map((i) => <Icon.star key={i} size={12} className="fill-amber-400" />)}
              <Icon.star size={12} />
              <span className="ml-2 text-[11px] text-muted">4.3 from 128 readers</span>
            </div>
            <div className="mt-5 space-y-2">
              <div className="h-2.5 w-full bg-gray-100 rounded" />
              <div className="h-2.5 w-[94%] bg-gray-100 rounded" />
              <div className="h-2.5 w-[88%] bg-yellow-100 rounded" />
              <div className="h-2.5 w-[96%] bg-gray-100 rounded" />
              <div className="h-2.5 w-[70%] bg-gray-100 rounded" />
              <div className="h-2.5 w-[91%] bg-gray-100 rounded" />
              <div className="h-2.5 w-[60%] bg-gray-100 rounded" />
            </div>
          </div>
          <div className="hidden md:flex flex-col p-5 bg-gray-50/60">
            <div className="flex items-center gap-2 mb-4">
              <span className="w-6 h-6 rounded-md bg-violet-100 text-violet-600 flex items-center justify-center"><Icon.pinda size={13} /></span>
              <span className="text-xs font-semibold">Pinda</span>
              <span className="ml-auto text-[10px] text-muted">this paper</span>
            </div>
            <div className="self-end bg-foreground text-background text-[11px] px-3 py-2 rounded-xl rounded-br-sm max-w-[85%]">
              Why does sliding window attention help here?
            </div>
            <div className="mt-3 bg-white border border-border text-[11px] px-3 py-2.5 rounded-xl rounded-bl-sm leading-relaxed">
              Each layer attends to the previous 4,096 tokens, but stacking layers lets information travel further, so the effective span grows with depth while memory stays fixed. <span className="text-muted">(Section 2)</span>
            </div>
            <div className="mt-auto flex items-center gap-2 bg-white rounded-lg border border-border px-3 py-2">
              <span className="text-[11px] text-muted flex-1">Ask about this paper...</span>
              <Icon.mic size={13} className="text-muted" />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
