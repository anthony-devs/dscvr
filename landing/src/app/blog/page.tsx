import type { Metadata } from "next";
import Link from "next/link";
import { PageShell } from "@/components/page-shell";
import { allPosts, formatDate } from "@/lib/blog";

export const metadata: Metadata = {
  title: "Blog: guides for students and researchers",
  description: "Practical guides on finding papers, reading research, writing literature reviews, revising for exams and using AI for study without getting things wrong.",
  alternates: { canonical: "/blog" },
};

export default function BlogIndex() {
  const posts = allPosts();
  return (
    <PageShell>
      <div className="max-w-4xl mx-auto px-6">
        <p className="text-[11px] font-semibold tracking-widest uppercase text-brand">The DSCVR blog</p>
        <h1 className="mt-3 font-serif text-4xl md:text-6xl font-semibold tracking-tight">Guides for people who read for a living</h1>
        <p className="mt-5 text-lg text-muted max-w-2xl">Finding papers, reading them faster, writing them up, and using AI without trusting it blindly.</p>

        <ul className="mt-14 divide-y divide-border border-y border-border">
          {posts.map((p) => (
            <li key={p.slug}>
              <Link href={`/blog/${p.slug}`} className="group block py-8">
                <p className="text-xs text-muted">{formatDate(p.date)} · {p.readingMinutes} min read</p>
                <h2 className="mt-2 font-serif text-2xl md:text-3xl font-semibold tracking-tight group-hover:text-brand transition-colors">{p.title}</h2>
                <p className="mt-2 text-muted leading-relaxed">{p.description}</p>
              </Link>
            </li>
          ))}
        </ul>
      </div>
    </PageShell>
  );
}
