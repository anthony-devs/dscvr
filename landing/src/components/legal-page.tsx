import fs from "node:fs";
import path from "node:path";
import { PageShell } from "./page-shell";
import { renderMarkdown } from "@/lib/markdown";

export function LegalPage({ file, title, intro }: { file: string; title: string; intro?: string }) {
  const md = fs.readFileSync(path.join(process.cwd(), "content", "legal", `${file}.md`), "utf8");
  return (
    <PageShell>
      <article className="max-w-[720px] mx-auto px-6">
        <h1 className="font-serif text-4xl md:text-5xl font-semibold tracking-tight">{title}</h1>
        {intro && <p className="mt-4 text-lg text-muted">{intro}</p>}
        <hr className="my-10 border-border" />
        <div className="prose" dangerouslySetInnerHTML={{ __html: renderMarkdown(md) }} />
      </article>
    </PageShell>
  );
}
