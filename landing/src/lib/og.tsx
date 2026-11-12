import fs from "node:fs";
import path from "node:path";

/** Shared pieces for the link-preview images (Open Graph / X cards). */
export const OG_SIZE = { width: 1200, height: 630 };

const dir = path.join(process.cwd(), "assets", "og");
const read = (f: string) => fs.readFileSync(path.join(dir, f));

export function ogFonts() {
  return [
    { name: "Inter", data: read("inter-latin-500-normal.woff"), weight: 500 as const, style: "normal" as const },
    { name: "Inter", data: read("inter-latin-800-normal.woff"), weight: 800 as const, style: "normal" as const },
    { name: "Caveat", data: read("caveat-latin-700-normal.woff"), weight: 700 as const, style: "normal" as const },
    { name: "Serif", data: read("source-serif-4-latin-700-normal.woff"), weight: 700 as const, style: "normal" as const },
  ];
}

function dataUri(file: string) {
  const svg = fs.readFileSync(path.join(process.cwd(), "public", file), "utf8");
  return `data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}`;
}

export const MARK = () => dataUri("mark.svg");
export const PINDA = () => dataUri("pinda.svg");

export const INK = "#111111";
export const MUTED = "#8A8F98";
export const BRAND = "#4F5BFF";
export const PINK = "#E0356B";
export const PAPER = "#FBFBF9";

/** The DSCVR mark and name, top left of every card. */
export function Brand({ trail }: { trail: string }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={MARK()} width={44} height={44} alt="" />
      <div style={{ display: "flex", fontSize: 30, fontWeight: 800, color: INK, letterSpacing: -0.5 }}>DSCVR</div>
      <div style={{ display: "flex", fontSize: 26, color: MUTED, fontWeight: 500 }}>/ {trail}</div>
    </div>
  );
}

/** A row of blue squares, the same mosaic as the website hero. */
export function MosaicStrip({ count = 36 }: { count?: number }) {
  return (
    <div style={{ display: "flex", gap: 0, height: 22 }}>
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} style={{ flex: 1, background: BRAND, opacity: 0.18 + (((i * 37) % 61) / 100) }} />
      ))}
    </div>
  );
}

/** The home page / app card: crossed-out problems, then the answer. */
export function HomeCard({ footer }: { footer: string }) {
  const struck = (text: string, width: number) => (
    <div style={{ display: "flex", position: "relative", color: "#B9BCC3", fontSize: 86, fontWeight: 800, letterSpacing: -3, lineHeight: 1.02 }}>
      {text}
      <div style={{ position: "absolute", left: -6, top: 50, width, height: 9, background: PINK, borderRadius: 4, transform: "rotate(-1.5deg)" }} />
    </div>
  );
  return (
    <div style={{ width: "100%", height: "100%", display: "flex", flexDirection: "column", background: PAPER, fontFamily: "Inter" }}>
      <div style={{ display: "flex", flexDirection: "column", flex: 1, padding: "52px 64px 0" }}>
        <Brand trail="research, answered" />
        <div style={{ display: "flex", marginTop: 34 }}>
          <div style={{ display: "flex", flexDirection: "column" }}>
            {struck("Twelve tabs.", 530)}
            {struck("Lost PDFs.", 440)}
            {struck("Made-up citations.", 760)}
            <div style={{ display: "flex", flexDirection: "column", marginTop: 4 }}>
              <div style={{ display: "flex", color: INK, fontSize: 104, fontWeight: 800, letterSpacing: -4, lineHeight: 1 }}>Answered.</div>
              <div style={{ display: "flex", width: 500, height: 10, background: BRAND, borderRadius: 5, marginTop: 6 }} />
            </div>
          </div>
        </div>
        <div style={{ position: "absolute", right: 56, top: 318, display: "flex", flexDirection: "column", alignItems: "flex-start", width: 300 }}>
          <div style={{ display: "flex", fontFamily: "Caveat", fontSize: 44, color: BRAND, lineHeight: 1.05, transform: "rotate(-4deg)" }}>
            Pinda answers from the papers you saved.
          </div>
          <svg width="230" height="110" viewBox="0 0 230 110" style={{ marginTop: 6, marginLeft: -40 }}>
            <path d="M200 8 C 190 70, 120 96, 30 92" fill="none" stroke={BRAND} strokeWidth="5" strokeLinecap="round" />
            <path d="M48 74 L 26 92 L 50 106" fill="none" stroke={BRAND} strokeWidth="5" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </div>
      </div>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "0 64px 22px", fontSize: 24, color: MUTED, fontWeight: 500 }}>
        <div style={{ display: "flex" }}>Search papers, read with AI, write it up. Free to start.</div>
        <div style={{ display: "flex", color: INK, fontWeight: 800 }}>{footer}</div>
      </div>
      <MosaicStrip />
    </div>
  );
}
