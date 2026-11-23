import Link from "next/link";
import { PageShell } from "@/components/page-shell";

export default function NotFound() {
  return (
    <PageShell>
      <div className="max-w-[560px] mx-auto px-6 text-center">
        <p className="text-sm font-semibold tracking-widest uppercase text-muted">404</p>
        <h1 className="mt-3 font-serif text-4xl md:text-5xl font-semibold tracking-tight">That page isn&apos;t here</h1>
        <p className="mt-4 text-lg text-muted">It may have moved, or the link has a typo. Try one of these instead.</p>
        <div className="mt-8 flex flex-wrap gap-3 justify-center">
          <Link href="/" className="rounded-full bg-foreground text-background px-5 py-2.5 text-sm font-medium">Home</Link>
          <Link href="/blog" className="rounded-full border border-border px-5 py-2.5 text-sm font-medium">Blog</Link>
          <Link href="/support" className="rounded-full border border-border px-5 py-2.5 text-sm font-medium">Support</Link>
        </div>
      </div>
    </PageShell>
  );
}
