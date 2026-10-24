"use client";

import { useState } from "react";
import Link from "next/link";

export function Nav() {
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 bg-background/80 backdrop-blur-xl border-b border-border/50">
      <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
        {/* Logo */}
        <Link href="/" className="flex items-center gap-2">
          <div className="w-8 h-8 bg-foreground rounded-lg flex items-center justify-center">
            <span className="text-background font-bold text-sm">D</span>
          </div>
          <span className="font-semibold text-lg tracking-tight">DSCVR</span>
        </Link>

        {/* Desktop nav */}
        <div className="hidden md:flex items-center gap-8">
          <a href="#features" className="text-sm text-muted hover:text-foreground transition-colors">
            Features
          </a>
          <a href="#how-it-works" className="text-sm text-muted hover:text-foreground transition-colors">
            How it works
          </a>
          <a href="#pinda" className="text-sm text-muted hover:text-foreground transition-colors">
            Pinda AI
          </a>
        </div>

        {/* CTA */}
        <div className="hidden md:flex items-center gap-3">
          <a
            href="https://dscvr-9d362.web.app/?demo=true"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-5 py-2.5 bg-foreground text-background text-sm font-medium rounded-full hover:bg-foreground/90 transition-colors"
          >
            Try the demo
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M7 17L17 7M17 7H7M17 7v10" />
            </svg>
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
          <a href="#features" className="block text-sm text-muted" onClick={() => setMenuOpen(false)}>Features</a>
          <a href="#how-it-works" className="block text-sm text-muted" onClick={() => setMenuOpen(false)}>How it works</a>
          <a href="#pinda" className="block text-sm text-muted" onClick={() => setMenuOpen(false)}>Pinda AI</a>
          <a
            href="https://dscvr-9d362.web.app/?demo=true"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-5 py-2.5 bg-foreground text-background text-sm font-medium rounded-full"
          >
            Try the demo
          </a>
        </div>
      )}
    </nav>
  );
}
