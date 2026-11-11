import { Icon } from "./icons";
import { DEMO_URL, SIGNUP_URL } from "@/lib/site";

/** Deterministic blues for the mosaic, so the server and browser render the same picture. */
function mosaic(count: number) {
  const out: string[] = [];
  let seed = 7;
  for (let i = 0; i < count; i++) {
    seed = (seed * 9301 + 49297) % 233280;
    const r = seed / 233280;
    const col = i % 24;
    const row = Math.floor(i / 24);
    // Brighter towards the centre and the left edge, softer to the right.
    const centre = 1 - Math.min(1, Math.hypot((col - 9) / 14, (row - 6) / 8));
    const a = Math.max(0.08, Math.min(0.95, 0.25 + centre * 0.55 + (r - 0.5) * 0.45));
    out.push(`rgba(${Math.round(60 + r * 40)}, ${Math.round(80 + r * 50)}, 255, ${a.toFixed(2)})`);
  }
  return out;
}

const tiles = mosaic(24 * 13);

export function Hero() {
  return (
    <section className="pt-24 md:pt-28">
      <div className="rails max-w-6xl mx-auto px-6 md:px-10 pt-14 md:pt-20 pb-16">
        <a
          href="#features"
          className="fade-up inline-flex items-center gap-2 text-xs font-medium text-muted hover:text-foreground transition-colors"
        >
          <span className="w-4 h-4 rounded-[4px] bg-brand text-white flex items-center justify-center">
            <Icon.spark size={10} />
          </span>
          For students, researchers, clinicians and lawyers
        </a>

        <h1 className="fade-up delay-1 mt-5 font-serif text-[2.6rem] leading-[1.05] md:text-6xl lg:text-7xl font-semibold tracking-tight max-w-4xl">
          Find the research. Read it with Pinda. <span className="text-muted/70">Write it up.</span>
        </h1>

        <p className="fade-up delay-2 mt-6 text-base md:text-lg text-muted max-w-2xl leading-relaxed">
          DSCVR searches arXiv, PubMed, journals and case law at once, keeps everything in one library, and gives you an AI
          research assistant that answers from the papers you saved, not from guesswork.
        </p>

        <div className="fade-up delay-3 mt-9 flex flex-wrap items-center gap-3">
          <a
            href={DEMO_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center px-5 py-3 border border-border bg-white text-xs font-semibold tracking-wide uppercase hover:bg-foreground/5 transition-colors"
          >
            Try the demo
          </a>
          <a
            href={SIGNUP_URL}
            className="inline-flex items-center gap-2.5 px-5 py-3 bg-foreground text-background text-xs font-semibold tracking-wide uppercase hover:bg-foreground/90 transition-colors"
          >
            <Icon.arrow size={14} />
            Start for free
          </a>
        </div>
        <p className="fade-up delay-3 mt-3 text-xs text-muted">No card needed. A daily Pinda allowance on the free plan.</p>

        <div className="fade-up delay-4 relative mt-14 md:mt-16 overflow-hidden bg-[#dfe4ff]">
          <div className="mosaic" aria-hidden>
            {tiles.map((c, i) => (
              <span key={i} style={{ background: c }} />
            ))}
          </div>
          <div className="absolute inset-0 flex items-center justify-center p-4 md:p-10">
            <SearchCard />
          </div>
        </div>
      </div>
    </section>
  );
}

function SearchCard() {
  return (
    <div className="w-full max-w-xl bg-white/70 backdrop-blur-md p-2 rounded-xl shadow-2xl shadow-blue-900/20 border border-white/60">
      <div className="bg-white rounded-lg border border-border p-4 md:p-5">
        <p className="text-[11px] text-muted">Ask Pinda about your library</p>
        <p className="mt-3 text-sm md:text-[15px] text-foreground min-h-[3.5rem]">
          What do the trials I saved say about early antibiotics in sepsis?
          <span className="inline-block w-[2px] h-4 bg-brand align-middle ml-0.5 animate-pulse" />
        </p>
        <div className="mt-3 flex items-center gap-2">
          <span className="text-[10px] px-2 py-1 rounded border border-border text-muted">Sepsis, 12 items</span>
          <span className="hidden sm:inline text-[10px] px-2 py-1 rounded border border-border text-muted">Detailed</span>
          <span className="ml-auto w-8 h-8 rounded-md bg-foreground text-background flex items-center justify-center">
            <Icon.arrow size={13} />
          </span>
        </div>
      </div>
    </div>
  );
}
