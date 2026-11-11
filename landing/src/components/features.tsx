import type { ReactNode } from "react";
import { Icon } from "./icons";

function Card({ eyebrow, title, body, children, wide }: { eyebrow: string; title: string; body: string; children: ReactNode; wide?: boolean }) {
  return (
    <div className={`min-w-0 bg-white border border-border rounded-2xl p-6 md:p-7 flex flex-col ${wide ? "md:col-span-2" : ""}`}>
      <p className="text-[11px] font-semibold tracking-widest uppercase text-brand">{eyebrow}</p>
      <h3 className="mt-2 text-xl font-semibold tracking-tight">{title}</h3>
      <p className="mt-2 text-sm text-muted leading-relaxed max-w-md">{body}</p>
      <div className="mt-6 flex-1 rounded-xl border border-border bg-[#fafbff] p-4 overflow-hidden">{children}</div>
    </div>
  );
}

function DiscoverMock() {
  const rows = [
    ["Early goal-directed therapy for septic shock", "PubMed", "2001"],
    ["Timing of antibiotics in sepsis: a cohort study", "Europe PMC", "2017"],
    ["Surviving Sepsis Campaign guidelines", "Guideline", "2021"],
  ];
  return (
    <div className="space-y-2">
      <div className="flex items-center gap-2 bg-white border border-border rounded-lg px-3 py-2 text-xs text-muted">
        <Icon.graph size={14} /> <span className="truncate">sepsis antibiotic timing</span>
        <span className="ml-auto text-[10px] px-1.5 py-0.5 rounded bg-brand-soft text-brand font-medium">Free PDF only</span>
      </div>
      {rows.map(([t, s, y]) => (
        <div key={t} className="bg-white border border-border rounded-lg px-3 py-2.5 flex items-center gap-3">
          <div className="min-w-0 flex-1">
            <p className="text-[12.5px] font-medium truncate">{t}</p>
            <p className="text-[10.5px] text-muted">{s} · {y}</p>
          </div>
          <span className="text-[10px] px-2 py-1 rounded-md border border-border">Save</span>
        </div>
      ))}
    </div>
  );
}

function PindaMock() {
  return (
    <div className="space-y-2.5 text-[12px]">
      <div className="ml-auto max-w-[80%] bg-foreground text-background rounded-xl rounded-br-sm px-3 py-2">
        Compare the methods in these three papers.
      </div>
      <div className="max-w-[92%] bg-white border border-border rounded-xl rounded-bl-sm px-3 py-2.5 leading-relaxed">
        <span className="font-semibold">Rivers 2001</span> was a single-centre randomised trial, while <span className="font-semibold">ProCESS</span> and{" "}
        <span className="font-semibold">ARISE</span> were multicentre. Neither later trial found a mortality benefit...
      </div>
      <div className="flex gap-1.5 flex-wrap">
        {["Summarize", "Explain simply", "Quiz me", "Fact-check"].map((a) => (
          <span key={a} className="text-[10px] px-2 py-1 rounded-full border border-border bg-white">{a}</span>
        ))}
      </div>
    </div>
  );
}

function StudyMock() {
  return (
    <div className="grid grid-cols-2 gap-2.5">
      <div className="col-span-2 bg-white border border-border rounded-lg p-4 text-center">
        <p className="text-[10px] uppercase tracking-wider text-muted">Flashcard 3 of 12</p>
        <p className="mt-2 text-[13px] font-medium">What is the ratio decidendi of Donoghue v Stevenson?</p>
      </div>
      {["Flashcards", "Practice questions", "Case brief", "Evidence summary"].map((x) => (
        <div key={x} className="bg-white border border-border rounded-lg px-3 py-2 text-[11.5px] flex items-center gap-2">
          <Icon.check size={11} className="text-brand" /> {x}
        </div>
      ))}
    </div>
  );
}

function ParliamentMock() {
  const votes = [
    ["Advocate", "Supported", 82, "bg-emerald-500"],
    ["Skeptic", "Partly supported", 64, "bg-amber-500"],
    ["Analyst", "Supported", 71, "bg-emerald-500"],
  ] as const;
  return (
    <div className="space-y-2.5">
      <p className="text-[12px] italic text-muted">&ldquo;Early antibiotics reduce sepsis mortality.&rdquo;</p>
      {votes.map(([who, v, pct, c]) => (
        <div key={who} className="bg-white border border-border rounded-lg px-3 py-2">
          <div className="flex items-center justify-between text-[11.5px]">
            <span className="font-medium">{who}</span>
            <span className="text-muted">{v} · {pct}%</span>
          </div>
          <div className="mt-1.5 h-1.5 rounded-full bg-gray-100">
            <div className={`h-full rounded-full ${c}`} style={{ width: `${pct}%` }} />
          </div>
        </div>
      ))}
    </div>
  );
}

function ReportMock() {
  return (
    <div className="bg-white border border-border rounded-lg p-4">
      <p className="text-[10px] uppercase tracking-wider text-muted">Literature review · 8 sources</p>
      <p className="mt-2 font-serif text-[15px] font-semibold">Fluid resuscitation in septic shock</p>
      <p className="mt-2 text-[11.5px] text-muted leading-relaxed">
        Three multicentre trials found no survival benefit from protocolised care [2][3][4], in contrast with the earlier single-centre result [1]...
      </p>
      <div className="mt-3 flex gap-1.5">
        <span className="text-[10px] px-2 py-1 rounded border border-border">Edit</span>
        <span className="text-[10px] px-2 py-1 rounded border border-border">Export Markdown</span>
      </div>
    </div>
  );
}

function SessionMock() {
  return (
    <div className="grid grid-cols-[auto_1fr] gap-3 items-center">
      <div className="w-20 h-20 rounded-full border-[5px] border-brand/80 border-r-brand/15 flex items-center justify-center">
        <span className="text-[15px] font-semibold tabular-nums">18:42</span>
      </div>
      <div className="bg-white border border-border rounded-lg p-3">
        <p className="text-[10px] uppercase tracking-wider text-muted">Recap by Pinda</p>
        <ul className="mt-1.5 space-y-1 text-[11.5px]">
          <li>Covered: renal physiology, chapters 3 to 4</li>
          <li>Next: practise acid-base questions</li>
        </ul>
      </div>
    </div>
  );
}

const more = [
  [Icon.mic, "Voice", "Dictate notes and ask Pinda out loud. Hear the answer read back."],
  [Icon.spark, "Cite anything", "APA, Harvard, Vancouver, MLA, Chicago and OSCOLA. Export BibTeX or RIS."],
  [Icon.star, "Ratings", "Rate what you read and see how other readers rated a paper."],
  [Icon.users, "Study rooms", "Live rooms with chat, a shared timer and shared papers."],
  [Icon.timer, "Subject alerts", "New papers, guidelines and judgments in the subjects you follow."],
  [Icon.devices, "Offline and accessible", "Read offline, low-data mode, high contrast, adjustable text and read-aloud."],
] as const;

export function Features() {
  return (
    <section id="features" className="border-t border-border/70">
      <div className="rails max-w-6xl mx-auto px-6 md:px-10 py-24 md:py-32">
        <p className="flex items-center justify-center gap-2 text-[11px] font-semibold tracking-widest uppercase text-muted">
          <span className="w-3 h-1.5 bg-brand rounded-sm" />
          The solution
        </p>
        <h2 className="mt-5 text-center font-serif text-3xl md:text-5xl font-semibold tracking-tight leading-tight max-w-3xl mx-auto">
          One research desk, from the first search to the final draft
        </h2>
        <p className="mt-5 text-center text-muted max-w-2xl mx-auto">
          Everything you save becomes something Pinda can read, so the answers, study tools and reports come from your own sources.
        </p>

        <div className="mt-16 grid md:grid-cols-3 gap-5">
          <Card wide eyebrow="Discover" title="Every free source, one search" body="Papers, preprints, clinical guidelines and UK judgments, labelled by source. Filter to free PDFs and save in one tap.">
            <DiscoverMock />
          </Card>
          <Card eyebrow="Pinda" title="Answers from your library" body="Ask across your whole library, one topic or one paper. Pinda reads the full PDFs and names its sources.">
            <PindaMock />
          </Card>
          <Card eyebrow="Study" title="Revise from any reading" body="Flashcards, exam-style questions, case briefs and evidence summaries from one paper or judgment.">
            <StudyMock />
          </Card>
          <Card eyebrow="Parliament" title="Fact-check a claim" body="Three AI readers vote on a claim with their reasoning, then a summary shows where they agree.">
            <ParliamentMock />
          </Card>
          <Card eyebrow="Reports" title="Drafts with citations" body="Literature reviews, summaries, study notes and comparisons from up to 40 sources you pick.">
            <ReportMock />
          </Card>
          <Card wide eyebrow="Sessions" title="Focus, then get a recap" body="Run a timed focus session with notes, or study live with others. Pinda writes what you covered and what to do next.">
            <SessionMock />
          </Card>
        </div>

        <div className="mt-5 grid sm:grid-cols-2 lg:grid-cols-3 border border-border rounded-2xl bg-white overflow-hidden">
          {more.map(([I, t, b], i) => (
            <div key={t} className={`p-6 flex gap-4 ${i % 3 !== 0 ? "lg:border-l" : ""} ${i >= 3 ? "lg:border-t" : ""} border-border ${i > 0 ? "border-t lg:border-t-0" : ""} ${i >= 3 ? "lg:!border-t" : ""}`}>
              <span className="w-9 h-9 shrink-0 rounded-lg bg-brand-soft text-brand flex items-center justify-center">
                <I size={18} />
              </span>
              <div>
                <h3 className="font-semibold text-[15px]">{t}</h3>
                <p className="mt-1 text-sm text-muted leading-relaxed">{b}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
