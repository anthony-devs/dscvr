import { Icon } from "./icons";

const problems = [
  {
    icon: Icon.graph,
    title: "Twelve tabs for one question",
    body: "PubMed in one tab, Google Scholar in another, a law report site in a third. Every source has its own search box and none of them talk to each other.",
  },
  {
    icon: Icon.paper,
    title: "PDFs scattered everywhere",
    body: "Downloads folder, email, a reference manager you stopped updating. When it is time to write, you can't find the paper you know you read.",
  },
  {
    icon: Icon.pinda,
    title: "AI that makes things up",
    body: "General chatbots answer from the whole internet and sometimes invent citations. You need answers from the sources you chose, with the source named.",
  },
];

export function Problem() {
  return (
    <section className="bg-foreground text-background">
      <div className="rails rails-dark max-w-6xl mx-auto px-6 md:px-10 py-24 md:py-32">
        <p className="flex items-center justify-center gap-2 text-[11px] font-semibold tracking-widest uppercase text-background/60">
          <span className="w-3 h-1.5 bg-brand rounded-sm" />
          The problem
        </p>
        <h2 className="mt-5 text-center font-serif text-3xl md:text-5xl font-semibold tracking-tight leading-tight max-w-3xl mx-auto">
          Research is still done with scattered tabs, <span className="text-background/45">lost PDFs and chatbots you can&apos;t trust.</span>
        </h2>

        <div className="mt-16 grid md:grid-cols-3 border border-white/10">
          {problems.map((p, i) => (
            <div key={p.title} className={`p-7 md:p-8 min-h-[260px] flex flex-col ${i > 0 ? "border-t md:border-t-0 md:border-l border-white/10" : ""}`}>
              <span className="w-11 h-11 rounded-lg bg-brand/20 text-[#9aa4ff] flex items-center justify-center">
                <p.icon size={22} />
              </span>
              <h3 className="mt-auto pt-10 font-serif text-xl font-semibold">{p.title}</h3>
              <p className="mt-3 text-sm text-background/55 leading-relaxed">{p.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
