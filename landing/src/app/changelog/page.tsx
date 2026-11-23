import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "What's new", description: "The latest changes to DSCVR.", alternates: { canonical: "/changelog" } };

export default function Page() {
  return <LegalPage file="changelog" title="What's new" intro="The latest changes to DSCVR." />;
}
