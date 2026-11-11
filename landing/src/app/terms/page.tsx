import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "Terms of service", description: "The terms for using DSCVR and Pinda.", alternates: { canonical: "/terms" } };

export default function Terms() {
  return <LegalPage file="terms" title="Terms of service" />;
}
