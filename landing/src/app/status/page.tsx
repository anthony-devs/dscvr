import type { Metadata } from "next";
import { PageShell } from "@/components/page-shell";
import { APP_URL, SUPPORT_EMAIL } from "@/lib/site";

export const metadata: Metadata = { title: "Status", description: "Is DSCVR working? Live status of the app, the API and search.", alternates: { canonical: "/status" } };
export const revalidate = 60;

const API = process.env.NEXT_PUBLIC_API_URL || "https://api.askpinda.com";

async function probe(url: string, init?: RequestInit): Promise<{ ok: boolean; ms: number; body?: Record<string, unknown> }> {
  const t = Date.now();
  try {
    const res = await fetch(url, { ...init, signal: AbortSignal.timeout(6000), next: { revalidate: 60 } });
    let body: Record<string, unknown> | undefined;
    try { body = await res.json(); } catch { /* not JSON */ }
    return { ok: res.ok, ms: Date.now() - t, body };
  } catch {
    return { ok: false, ms: Date.now() - t };
  }
}

export default async function Status() {
  const [app, api] = await Promise.all([probe(APP_URL, { method: "HEAD" }), probe(`${API}/health`)]);
  const search = await probe(`${API}/discover?source=wikibooks&q=database&limit=1`).catch(() => ({ ok: false, ms: 0 }));
  const rows: [string, boolean, string][] = [
    ["Web app", app.ok, "app.askpinda.com"],
    ["API and sign-in", api.ok, "api.askpinda.com"],
    ["Search", search.ok, "Discover across papers, textbooks and archives"],
    ["Pinda (AI)", api.ok && api.body?.ai === true, "Answers from your library"],
    ["Email", api.ok && api.body?.alertsEmail === true, "Verification, welcome and password reset"],
  ];
  const all = rows.every((r) => r[1]);
  return (
    <PageShell>
      <article className="max-w-[720px] mx-auto px-6">
        <h1 className="font-serif text-4xl md:text-5xl font-semibold tracking-tight">Status</h1>
        <p className={`mt-4 text-lg ${all ? "text-emerald-600" : "text-amber-600"}`}>
          {all ? "All systems working." : "Something is not working as it should. We are looking into it."}
        </p>
        <ul className="mt-8 divide-y divide-border border border-border rounded-xl">
          {rows.map(([name, ok, note]) => (
            <li key={name} className="flex items-center justify-between gap-4 px-5 py-4">
              <div>
                <p className="font-medium">{name}</p>
                <p className="text-sm text-muted">{note}</p>
              </div>
              <span className={`inline-flex items-center gap-2 text-sm font-medium ${ok ? "text-emerald-600" : "text-amber-600"}`}>
                <span className={`w-2 h-2 rounded-full ${ok ? "bg-emerald-500" : "bg-amber-500"}`} />
                {ok ? "Working" : "Problem"}
              </span>
            </li>
          ))}
        </ul>
        <p className="mt-6 text-sm text-muted">Checked just now and refreshed every minute. Seeing something different? Write to <a className="underline underline-offset-4" href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.</p>
      </article>
    </PageShell>
  );
}
