import type { ReactNode } from "react";
import { Nav } from "./nav";
import { Footer } from "./footer";

/** Nav and footer around a narrow column, for blog posts and legal pages. */
export function PageShell({ children }: { children: ReactNode }) {
  return (
    <main className="min-h-screen bg-background">
      <Nav />
      <div className="pt-28 md:pt-36 pb-24">{children}</div>
      <Footer />
    </main>
  );
}
