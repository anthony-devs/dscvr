import { Icon } from "./icons";
import { SIGNUP_URL } from "@/lib/site";

/** The DSCVR pitch at the end of a blog post. */
export function TryCta({ title, body }: { title?: string; body?: string }) {
  return (
    <aside className="my-12 rounded-2xl bg-foreground text-background p-7 md:p-9 relative overflow-hidden">
      <div className="absolute -right-16 -top-16 w-56 h-56 rounded-full bg-brand/30 blur-2xl" aria-hidden />
      <p className="text-[11px] font-semibold tracking-widest uppercase text-background/60">Try DSCVR</p>
      <h2 className="mt-2 font-serif text-2xl md:text-3xl font-semibold tracking-tight">{title ?? "Do this in one place, with Pinda beside you"}</h2>
      <p className="mt-3 text-background/70 max-w-xl text-[15px] leading-relaxed">
        {body ??
          "Search papers, guidelines and case law at once, save them to one library, and ask Pinda questions that are answered from your own sources. Free for students and researchers."}
      </p>
      <a href={SIGNUP_URL} className="mt-6 inline-flex items-center gap-2 px-5 py-3 bg-background text-foreground text-xs font-semibold uppercase tracking-wide hover:bg-background/90">
        Start for free <Icon.arrow size={14} />
      </a>
    </aside>
  );
}
