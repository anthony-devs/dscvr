import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { PageShell } from "@/components/page-shell";
import { JsonLd } from "@/components/json-ld";
import { TryCta } from "@/components/try-cta";
import { allPosts, formatDate, getPost } from "@/lib/blog";
import { renderMarkdown } from "@/lib/markdown";
import { SITE_URL } from "@/lib/site";

export const revalidate = 300;
export const dynamicParams = true;

export async function generateStaticParams() {
  return (await allPosts()).map((p) => ({ slug: p.slug }));
}

export async function generateMetadata({ params }: { params: { slug: string } }): Promise<Metadata> {
  const post = await getPost(params.slug);
  if (!post) return {};
  return {
    title: post.title,
    description: post.description,
    alternates: { canonical: `/blog/${post.slug}` },
    openGraph: { type: "article", title: post.title, description: post.description, publishedTime: post.date, authors: [post.author] },
    twitter: { card: "summary_large_image", title: post.title, description: post.description },
  };
}

export default async function PostPage({ params }: { params: { slug: string } }) {
  const post = await getPost(params.slug);
  if (!post) notFound();
  // The CTA goes where the post says <!-- cta -->, or at the end.
  const [before, after] = post.body.split("<!-- cta -->");
  const others = (await allPosts()).filter((p) => p.slug !== post.slug).slice(0, 3);
  const schema = {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    headline: post.title,
    description: post.description,
    datePublished: post.date,
    dateModified: post.updated ?? post.date,
    author: { "@type": "Person", name: post.author },
    publisher: { "@type": "Organization", name: "DSCVR", logo: { "@type": "ImageObject", url: `${SITE_URL}/mark.svg` } },
    mainEntityOfPage: `${SITE_URL}/blog/${post.slug}`,
    keywords: post.tags.join(", "),
  };
  return (
    <PageShell>
      <JsonLd data={schema} />
      <article className="max-w-[720px] mx-auto px-6">
        <Link href="/blog" className="text-sm text-muted hover:text-foreground">← All guides</Link>
        <h1 className="mt-6 font-serif text-[2.2rem] md:text-5xl font-semibold tracking-tight leading-[1.1]">{post.title}</h1>
        <p className="mt-5 text-lg text-muted leading-relaxed">{post.description}</p>
        <p className="mt-6 text-sm text-muted">
          {post.author} · {formatDate(post.date)} · {post.readingMinutes} min read
        </p>
        <hr className="my-10 border-border" />
        <div className="prose" dangerouslySetInnerHTML={{ __html: renderMarkdown(before) }} />
        <TryCta />
        {after && <div className="prose" dangerouslySetInnerHTML={{ __html: renderMarkdown(after) }} />}
      </article>

      {others.length > 0 && (
        <div className="max-w-4xl mx-auto px-6 mt-20">
          <p className="text-[11px] font-semibold tracking-widest uppercase text-muted">Keep reading</p>
          <div className="mt-5 grid md:grid-cols-3 gap-4">
            {others.map((p) => (
              <Link key={p.slug} href={`/blog/${p.slug}`} className="block rounded-xl border border-border bg-white p-5 hover:shadow-md transition-shadow">
                <p className="font-semibold leading-snug">{p.title}</p>
                <p className="mt-2 text-xs text-muted">{p.readingMinutes} min read</p>
              </Link>
            ))}
          </div>
        </div>
      )}
    </PageShell>
  );
}
