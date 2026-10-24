export function Footer() {
  return (
    <footer className="border-t border-border py-12 md:py-16">
      <div className="max-w-6xl mx-auto px-6">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-8">
          {/* Brand */}
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-foreground rounded-lg flex items-center justify-center">
              <span className="text-background font-bold text-sm">D</span>
            </div>
            <div>
              <span className="font-semibold tracking-tight">DSCVR</span>
              <p className="text-xs text-muted">Your research desk, everywhere.</p>
            </div>
          </div>

          {/* Links */}
          <div className="flex gap-8 text-sm text-muted">
            <a href="#features" className="hover:text-foreground transition-colors">Features</a>
            <a href="#how-it-works" className="hover:text-foreground transition-colors">How it works</a>
            <a href="#pinda" className="hover:text-foreground transition-colors">Pinda</a>
          </div>

          {/* Built by */}
          <p className="text-xs text-muted">
            Built by{" "}
            <a
              href="https://github.com/anthony-devs"
              target="_blank"
              rel="noopener noreferrer"
              className="underline underline-offset-2 hover:text-foreground transition-colors"
            >
              Anthony Ude
            </a>
          </p>
        </div>
      </div>
    </footer>
  );
}
