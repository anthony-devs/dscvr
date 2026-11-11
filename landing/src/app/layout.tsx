import type { Metadata, Viewport } from "next";
import "./globals.css";
import { DESCRIPTION, SITE_URL } from "@/lib/site";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: "Ask Pinda by DSCVR: AI Research Assistant for Papers, PDFs and Study",
    template: "%s | DSCVR",
  },
  description: DESCRIPTION,
  applicationName: "DSCVR",
  keywords: [
    "AI research assistant",
    "academic paper search",
    "literature review tool",
    "PDF reader with AI",
    "AI study tools",
    "flashcards from PDF",
    "case brief generator",
    "medical student study app",
    "law student study app",
    "free research tool",
  ],
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    url: SITE_URL,
    siteName: "DSCVR",
    title: "Ask Pinda by DSCVR: research, answered",
    description: "Find the research, read it with Pinda, and write it up. For students, researchers, clinicians and lawyers. Free to start.",
  },
  twitter: {
    card: "summary_large_image",
    title: "DSCVR: research, answered",
    description: "Find the research, read it with Pinda, and write it up. Free to start.",
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = { themeColor: "#FAFAFA" };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className="font-sans antialiased">{children}</body>
    </html>
  );
}
