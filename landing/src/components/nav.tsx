"use client";

import { useState } from "react";
import Link from "next/link";
import { DEMO_URL, SIGNUP_URL } from "@/lib/site";

const links = [
  ["Features", "#features"],
  ["Editions", "#editions"],
  ["Pinda", "#pinda"],
  ["Pricing", "#pricing"],
];

export function Nav() {
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 bg-background/80 backdrop-blur-xl border-b border-border/50">
      <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
        {/* Logo */}
        <Link href="/" className="flex items-center gap-2">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/mark.svg" alt="" width={32} height={32} className="w-8 h-8" />
          <span className="font-semibold text-lg tracking-tight">DSCVR</span>
        </Link>

        {/* Desktop nav */}
        <div className="hidden md:flex items-center gap-8">
          {links.map(([label, href]) => (
            <a key={href} href={href} className="text-sm text-muted hover:text-foreground transition-colors">{label}</a>
          ))}
        </div>

        {/* CTA */}
        <div className="hidden md:flex items-center gap-5">
          <a href={DEMO_URL} target="_blank" rel="noopener noreferrer" className="text-sm text-muted hover:text-foreground transition-colors">
            Demo
          </a>
          <a
            href={SIGNUP_URL}
            className="inline-flex items-center gap-2 px-5 py-2.5 bg-foreground text-background text-sm font-medium rounded-full hover:bg-foreground/90 transition-colors"
          >
            Start free
          </a>
        </div>

        {/* Mobile menu button */}
        <button
          onClick={() => setMenuOpen(!menuOpen)}
          className="md:hidden p-2 text-foreground"
          aria-label="Menu"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
            {menuOpen ? (
              <>
                <path d="M18 6L6 18" />
                <path d="M6 6l12 12" />
              </>
            ) : (
              <>
                <path d="M3 12h18" />
                <path d="M3 6h18" />
                <path d="M3 18h18" />
              </>
            )}
          </svg>
        </button>
      </div>

      {/* Mobile menu */}
      {menuOpen && (
        <div className="md:hidden border-t border-border bg-background px-6 py-4 space-y-4">
          {links.map(([label, href]) => (
            <a key={href} href={href} className="block text-sm text-muted" onClick={() => setMenuOpen(false)}>{label}</a>
          ))}
          <a href={SIGNUP_URL} className="inline-flex items-center gap-2 px-5 py-2.5 bg-foreground text-background text-sm font-medium rounded-full">
            Start free
          </a>
        </div>
      )}
    </nav>
  );
}
