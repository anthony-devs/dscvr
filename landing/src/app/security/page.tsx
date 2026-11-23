import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "Security", description: "How DSCVR protects your account and library, and how to report a vulnerability.", alternates: { canonical: "/security" } };

export default function Page() {
  return <LegalPage file="security" title="Security" intro="How we protect your account and your library." />;
}
