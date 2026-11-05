import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "DSCVR: research, answered",
  description:
    "Pull papers from arXiv, ask Pinda (powered by Claude) about them, and turn what you learn into reports. Free for students and researchers, usage-based for teams.",
  openGraph: {
    title: "DSCVR: research, answered",
    description:
      "Pull papers from arXiv, ask an AI that has read them, and write it up. Free for students and researchers.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="font-sans antialiased">{children}</body>
    </html>
  );
}
