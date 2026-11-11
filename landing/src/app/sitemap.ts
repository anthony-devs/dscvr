import type { MetadataRoute } from "next";
import { SITE_URL } from "@/lib/site";
import { allPosts } from "@/lib/blog";

export const revalidate = 300;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const now = new Date();
  const pages: MetadataRoute.Sitemap = [
    { url: SITE_URL, lastModified: now, changeFrequency: "weekly", priority: 1 },
    { url: `${SITE_URL}/blog`, lastModified: now, changeFrequency: "weekly", priority: 0.8 },
    { url: `${SITE_URL}/support`, lastModified: now, changeFrequency: "monthly", priority: 0.4 },
    { url: `${SITE_URL}/privacy`, lastModified: now, changeFrequency: "yearly", priority: 0.2 },
    { url: `${SITE_URL}/terms`, lastModified: now, changeFrequency: "yearly", priority: 0.2 },
  ];
  for (const p of await allPosts()) {
    pages.push({ url: `${SITE_URL}/blog/${p.slug}`, lastModified: new Date(p.updated ?? p.date), changeFrequency: "monthly", priority: 0.7 });
  }
  return pages;
}
