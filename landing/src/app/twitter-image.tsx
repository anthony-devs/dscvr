import { ImageResponse } from "next/og";

export const alt = "DSCVR: research, answered";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function TwitterImage() {
  return new ImageResponse(
    (
      <div style={{ width: "100%", height: "100%", display: "flex", flexDirection: "column", justifyContent: "space-between", padding: 72, background: "#FAFAFA", color: "#111" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 16, fontSize: 34, fontWeight: 700 }}>
          <div style={{ width: 48, height: 48, borderRadius: 24, background: "#4F5BFF" }} />
          DSCVR
        </div>
        <div style={{ display: "flex", flexDirection: "column" }}>
          <div style={{ fontSize: 76, fontWeight: 700, lineHeight: 1.05, letterSpacing: -2 }}>Find the research.</div>
          <div style={{ fontSize: 76, fontWeight: 700, lineHeight: 1.05, letterSpacing: -2 }}>Read it with Pinda.</div>
          <div style={{ fontSize: 76, fontWeight: 700, lineHeight: 1.05, letterSpacing: -2, color: "#9CA3AF" }}>Write it up.</div>
        </div>
        <div style={{ display: "flex", height: 18, gap: 6 }}>
          {Array.from({ length: 40 }).map((_, i) => (
            <div key={i} style={{ flex: 1, background: "#4F5BFF", opacity: 0.25 + ((i * 37) % 70) / 100 }} />
          ))}
        </div>
      </div>
    ),
    size,
  );
}
