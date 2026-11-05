type P = { size?: number; className?: string };
const base = (size = 22) => ({
  width: size,
  height: size,
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.6,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
});

export const Icon = {
  arrow: ({ size = 16, className }: P) => (
    <svg {...base(size)} strokeWidth={2.4} className={className}><path d="M5 12h14M12 5l7 7-7 7" /></svg>
  ),
  check: ({ size = 14, className }: P) => (
    <svg {...base(size)} strokeWidth={2.6} className={className}><path d="M20 6L9 17l-5-5" /></svg>
  ),
  paper: ({ size, className }: P) => (
    <svg {...base(size)} className={className}><path d="M14 3H7a2 2 0 00-2 2v14a2 2 0 002 2h10a2 2 0 002-2V8z" /><path d="M14 3v5h5M9 13h6M9 17h4" /></svg>
  ),
  graph: ({ size, className }: P) => (
    <svg {...base(size)} className={className}><circle cx="6" cy="6" r="2.5" /><circle cx="18" cy="8" r="2.5" /><circle cx="9" cy="18" r="2.5" /><path d="M8.3 7.2l7.4 0.6M7 8.4l1.4 7.2M16.4 10l-5.6 6.4" /></svg>
  ),
  spark: ({ size, className }: P) => (
    <svg {...base(size)} className={className}><path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z" /><path d="M19 16l.7 2.3L22 19l-2.3.7L19 22l-.7-2.3L16 19l2.3-.7z" /></svg>
  ),
  report: ({ size, className }: P) => (
    <svg {...base(size)} className={className}><rect x="4" y="3" width="16" height="18" rx="2" /><path d="M8 8h8M8 12h8M8 16h5" /></svg>
  ),
  star: ({ size, className }: P) => (
    <svg {...base(size)} className={className}><path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z" /></svg>
  ),
  mic: ({ size, className }: P) => (
    <svg {...base(size)} className={className}><rect x="9" y="3" width="6" height="11" rx="3" /><path d="M5 11a7 7 0 0014 0M12 18v3" /></svg>
  ),
  timer: ({ size, className }: P) => (
    <svg {...base(size)} className={className}><circle cx="12" cy="13" r="8" /><path d="M12 9v4l2.5 2.5M9 2h6" /></svg>
  ),
  users: ({ size, className }: P) => (
    <svg {...base(size)} className={className}><circle cx="9" cy="8" r="3.5" /><path d="M2.5 20a6.5 6.5 0 0113 0" /><circle cx="17.5" cy="9" r="2.5" /><path d="M16 14.2a5 5 0 016 4.8" /></svg>
  ),
  scale: ({ size, className }: P) => (
    <svg {...base(size)} className={className}><path d="M12 3v18M7 21h10M5 7h14M5 7l-3 7a3.5 3.5 0 006 0zM19 7l-3 7a3.5 3.5 0 006 0z" /></svg>
  ),
  devices: ({ size, className }: P) => (
    <svg {...base(size)} className={className}><rect x="2" y="4" width="14" height="10" rx="1.5" /><path d="M6 18h6" /><rect x="17" y="8" width="5" height="12" rx="1.2" /></svg>
  ),
  cap: ({ size, className }: P) => (
    <svg {...base(size)} className={className}><path d="M2 9l10-5 10 5-10 5z" /><path d="M6 11v5c3 2.5 9 2.5 12 0v-5M22 9v6" /></svg>
  ),
  flask: ({ size, className }: P) => (
    <svg {...base(size)} className={className}><path d="M9 3h6M10 3v6L4.5 18.5A1.7 1.7 0 006 21h12a1.7 1.7 0 001.5-2.5L14 9V3" /><path d="M7 15h10" /></svg>
  ),
  building: ({ size, className }: P) => (
    <svg {...base(size)} className={className}><rect x="4" y="3" width="11" height="18" rx="1" /><path d="M15 9h5v12h-5M8 7h3M8 11h3M8 15h3" /></svg>
  ),
  pinda: ({ size, className }: P) => (
    <svg {...base(size)} className={className}><path d="M12 2a7 7 0 017 7c0 3-2 5-3.5 6.5L12 19l-3.5-3.5C7 14 5 12 5 9a7 7 0 017-7z" /><circle cx="12" cy="9" r="2" /></svg>
  ),
};
