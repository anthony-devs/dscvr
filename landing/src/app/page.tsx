import { Nav } from "@/components/nav";
import { Hero } from "@/components/hero";
import { Features } from "@/components/features";
import { HowItWorks } from "@/components/how-it-works";
import { Pinda } from "@/components/pinda";
import { CTA } from "@/components/cta";
import { Footer } from "@/components/footer";

export default function Home() {
  return (
    <main className="min-h-screen bg-background">
      <Nav />
      <Hero />
      <Features />
      <HowItWorks />
      <Pinda />
      <CTA />
      <Footer />
    </main>
  );
}
