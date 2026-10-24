import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "DSCVR — Your research desk, everywhere.",
  description:
    "Save papers, highlight what matters, and let AI find answers grounded in your own library. Built for researchers who think deeply.",
  openGraph: {
    title: "DSCVR — Your research desk, everywhere.",
    description:
      "Save papers, highlight what matters, and let AI find answers grounded in your own library.",
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
