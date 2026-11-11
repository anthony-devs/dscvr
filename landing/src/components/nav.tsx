"use client";

import { useState } from "react";
import Link from "next/link";
import { LOGIN_URL, SIGNUP_URL } from "@/lib/site";

const links = [
  ["Product", "/#features"],
  ["Pinda", "/#pinda"],
  ["Pricing", "/#pricing"],
  ["Blog", "/blog"],
];

export function Nav() {
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 bg-background/85 backdrop-blur-xl border-b border-border/60">
      <div className="max-w-6xl mx-auto px-6 md:px-10 h-16 flex items-center justify-between">
        <Link href="/" className="flex items-center gap-2" aria-label="DSCVR home">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/mark.svg" alt="" width={28} height={28} className="w-7 h-7" />
          <span className="font-semibold text-lg tracking-tight">DSCVR</span>
        </Link>

        <div className="hidden md:flex items-center gap-7">
          {links.map(([label, href]) => (
            <Link key={href} href={href} className="text-[13px] text-muted hover:text-foreground transition-colors">{label}</Link>
          ))}
        </div>

        <div className="hidden md:flex items-center gap-2">
          <a href={LOGIN_URL} className="px-3.5 py-2 text-[11px] font-semibold tracking-wide uppercase border border-border bg-white hover:bg-foreground/5 transition-colors">
            Sign in
          </a>
          <a href={SIGNUP_URL} className="px-3.5 py-2 text-[11px] font-semibold tracking-wide uppercase bg-foreground text-background hover:bg-foreground/90 transition-colors">
            Get started
          </a>
        </div>

        <button onClick={() => setMenuOpen(!menuOpen)} className="md:hidden p-2 text-foreground" aria-label="Menu" aria-expanded={menuOpen}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
            {menuOpen ? (<><path d="M18 6L6 18" /><path d="M6 6l12 12" /></>) : (<><path d="M3 12h18" /><path d="M3 6h18" /><path d="M3 18h18" /></>)}
          </svg>
        </button>
      </div>

      {menuOpen && (
        <div className="md:hidden border-t border-border bg-background px-6 py-4 space-y-4">
          {links.map(([label, href]) => (
            <Link key={href} href={href} className="block text-sm text-muted" onClick={() => setMenuOpen(false)}>{label}</Link>
          ))}
          <div className="flex gap-2 pt-1">
            <a href={LOGIN_URL} className="px-4 py-2.5 text-xs font-semibold uppercase border border-border bg-white">Sign in</a>
            <a href={SIGNUP_URL} className="px-4 py-2.5 text-xs font-semibold uppercase bg-foreground text-background">Get started</a>
          </div>
        </div>
      )}
    </nav>
  );
}
