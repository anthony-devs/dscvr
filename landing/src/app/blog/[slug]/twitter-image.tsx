import { ImageResponse } from "next/og";
import { getPost } from "@/lib/blog";
import { BRAND, Brand, INK, MUTED, MosaicStrip, OG_SIZE, PAPER, PINDA, ogFonts } from "@/lib/og";

export const alt = "A DSCVR guide";
export const size = OG_SIZE;
export const contentType = "image/png";
export const revalidate = 300;

/** Each blog post's link preview: the title, big, with the DSCVR frame around it. */
export default async function PostTwitterImage({ params }: { params: { slug: string } }) {
  const post = await getPost(params.slug);
  const title = post?.title ?? "The DSCVR blog";
  // Split "Main title: subtitle" so the main part can be large.
  const [main, sub] = title.includes(":") ? [title.slice(0, title.indexOf(":")), title.slice(title.indexOf(":") + 1).trim()] : [title, ""];
  const fontSize = main.length > 60 ? 58 : main.length > 40 ? 70 : 84;
  const tag = (post?.tags?.[0] ?? "guide").toLowerCase();
  return new ImageResponse(
    (
      <div style={{ width: "100%", height: "100%", display: "flex", flexDirection: "column", background: PAPER, fontFamily: "Inter" }}>
        <div style={{ display: "flex", flexDirection: "column", flex: 1, padding: "52px 64px 0", position: "relative" }}>
          <Brand trail={`blog / ${tag}`} />
          <div style={{ display: "flex", flexDirection: "column", marginTop: 46, width: 900 }}>
            <div style={{ display: "flex", fontFamily: "Serif", fontSize, fontWeight: 700, color: INK, lineHeight: 1.06, letterSpacing: -1.5 }}>{main}</div>
            {sub && <div style={{ display: "flex", fontSize: 34, color: MUTED, fontWeight: 500, marginTop: 20, lineHeight: 1.25 }}>{sub}</div>}
          </div>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={PINDA()} width={170} height={170} alt="" style={{ position: "absolute", right: 56, bottom: 8 }} />
          <div style={{ position: "absolute", right: 236, bottom: 96, display: "flex", fontFamily: "Caveat", fontSize: 40, color: BRAND, transform: "rotate(-4deg)" }}>
            free guide
          </div>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", padding: "0 64px 22px", fontSize: 24, color: MUTED, fontWeight: 500 }}>
          <div style={{ display: "flex" }}>{post ? `${post.readingMinutes} min read` : "Guides for students and researchers"}</div>
          <div style={{ display: "flex", color: INK, fontWeight: 800 }}>askpinda.com/blog</div>
        </div>
        <MosaicStrip />
      </div>
    ),
    { ...OG_SIZE, fonts: ogFonts() },
  );
}
