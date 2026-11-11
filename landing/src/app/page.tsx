import { Nav } from "@/components/nav";
import { Hero } from "@/components/hero";
import { Sources } from "@/components/sources";
import { Problem } from "@/components/problem";
import { Features } from "@/components/features";
import { HowItWorks } from "@/components/how-it-works";
import { Pinda } from "@/components/pinda";
import { Editions } from "@/components/editions";
import { Pricing } from "@/components/pricing";
import { CTA } from "@/components/cta";
import { Footer } from "@/components/footer";
import { JsonLd } from "@/components/json-ld";
import { APP_URL, DESCRIPTION, SITE_URL } from "@/lib/site";

const appSchema = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "DSCVR",
  alternateName: "Ask Pinda",
  applicationCategory: "EducationalApplication",
  operatingSystem: "Web",
  url: SITE_URL,
  installUrl: APP_URL,
  description: DESCRIPTION,
  offers: [
    { "@type": "Offer", name: "Free", price: "0", priceCurrency: "USD" },
    { "@type": "Offer", name: "Student Plus", price: "4.99", priceCurrency: "USD" },
    { "@type": "Offer", name: "Research Plus", price: "9.99", priceCurrency: "USD" },
    { "@type": "Offer", name: "DSCVR Max", price: "24.99", priceCurrency: "USD" },
  ],
};

const orgSchema = {
  "@context": "https://schema.org",
  "@type": "Organization",
  name: "DSCVR",
  url: SITE_URL,
  logo: `${SITE_URL}/mark.svg`,
};

export default function Home() {
  return (
    <main className="min-h-screen bg-background">
      <JsonLd data={appSchema} />
      <JsonLd data={orgSchema} />
      <Nav />
      <Hero />
      <Sources />
      <Problem />
      <Features />
      <HowItWorks />
      <Pinda />
      <Editions />
      <Pricing />
      <CTA />
      <Footer />
    </main>
  );
}
