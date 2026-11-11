import Link from "next/link";
import { SUPPORT_EMAIL } from "@/lib/site";

const columns: [string, [string, string][]][] = [
  ["Product", [["Features", "/#features"], ["Pinda", "/#pinda"], ["Pricing", "/#pricing"], ["Editions", "/#editions"]]],
  ["Learn", [["Blog", "/blog"], ["Support", "/support"]]],
  ["Legal", [["Privacy", "/privacy"], ["Terms", "/terms"]]],
];

export function Footer() {
  return (
    <footer className="border-t border-border">
      <div className="max-w-6xl mx-auto px-6 md:px-10 py-14 grid gap-10 md:grid-cols-[1.4fr_repeat(3,1fr)]">
        <div>
          <Link href="/" className="flex items-center gap-2">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/mark.svg" alt="" width={28} height={28} className="w-7 h-7" />
            <span className="font-semibold tracking-tight">DSCVR</span>
          </Link>
          <p className="mt-3 text-sm text-muted max-w-xs">Research, answered. Search, read and write with Pinda.</p>
          <a href={`mailto:${SUPPORT_EMAIL}`} className="mt-4 inline-block text-sm text-muted underline underline-offset-4 hover:text-foreground">{SUPPORT_EMAIL}</a>
        </div>
        {columns.map(([title, items]) => (
          <div key={title}>
            <p className="text-[11px] font-semibold tracking-widest uppercase text-muted">{title}</p>
            <ul className="mt-4 space-y-2.5 text-sm">
              {items.map(([label, href]) => (
                <li key={href}><Link href={href} className="text-foreground/80 hover:text-foreground">{label}</Link></li>
              ))}
            </ul>
          </div>
        ))}
      </div>
      <div className="border-t border-border">
        <div className="max-w-6xl mx-auto px-6 md:px-10 py-6 flex flex-col sm:flex-row gap-2 justify-between text-xs text-muted">
          <p>© {new Date().getFullYear()} DSCVR. All rights reserved.</p>
          <p>
            Built by{" "}
            <a href="https://github.com/anthony-devs" target="_blank" rel="noopener noreferrer" className="underline underline-offset-2 hover:text-foreground">Anthony Ude</a>
          </p>
        </div>
      </div>
    </footer>
  );
}
