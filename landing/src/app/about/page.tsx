import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "About", description: "About AskPinda and DSCVR: who builds it and how we work.", alternates: { canonical: "/about" } };

export default function Page() {
  return <LegalPage file="about" title="About" intro="AskPinda builds tools for serious reading. DSCVR is our first." />;
}
