import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "Privacy policy", description: "What DSCVR collects, why, who it's shared with and the choices you have.", alternates: { canonical: "/privacy" } };

export default function Privacy() {
  return <LegalPage file="privacy" title="Privacy policy" />;
}
