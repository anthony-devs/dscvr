import { revalidatePath, revalidateTag } from "next/cache";
import { NextResponse } from "next/server";

/** The admin console calls this after saving a post, so the blog updates right away. */
export async function POST(req: Request) {
  const secret = process.env.REVALIDATE_SECRET;
  const body = (await req.json().catch(() => ({}))) as { secret?: string };
  if (!secret || body.secret !== secret) return NextResponse.json({ ok: false }, { status: 401 });
  revalidateTag("blog");
  revalidatePath("/blog", "layout");
  revalidatePath("/sitemap.xml");
  return NextResponse.json({ ok: true });
}
