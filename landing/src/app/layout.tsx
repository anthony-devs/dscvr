import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "DSCVR: research, answered",
  description:
    "Search papers, clinical guidelines and case law from every free source at once, read PDFs with Pinda beside you, and turn what you learn into flashcards, case briefs and reports. Free for students and researchers.",
  openGraph: {
    title: "DSCVR: research, answered",
    description:
      "Find it, read it with Pinda, and write it up. For students, researchers, doctors, nurses and lawyers. Free to start.",
    type: "website",
    images: ["/pinda.svg"],
  },
};

export const viewport: Viewport = { themeColor: "#F3F4F6" };

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
