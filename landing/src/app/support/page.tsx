import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "Support", description: "Get help with DSCVR: sign-in, plans, sharing, PDFs and your account.", alternates: { canonical: "/support" } };

export default function Support() {
  return <LegalPage file="support" title="Support" intro="Answers to common questions, and how to reach us." />;
}
