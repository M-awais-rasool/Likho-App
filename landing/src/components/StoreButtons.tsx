import { site } from "@/lib/site";

function PlayGlyph() {
  return (
    <svg viewBox="0 0 24 24" className="size-6" aria-hidden>
      <path d="M4 3.5v17l9.4-8.5L4 3.5z" fill="#34d399" />
      <path d="M4 3.5l12.6 7-3.2 1.5L4 3.5z" fill="#60a5fa" />
      <path d="M4 20.5l12.6-7-3.2-1.5L4 20.5z" fill="#f87171" />
      <path d="M16.6 10.5l3.4 1.5-3.4 1.5-3.2-1.5 3.2-1.5z" fill="#fbbf24" />
    </svg>
  );
}

function AppleGlyph() {
  return (
    <svg viewBox="0 0 24 24" className="size-6 fill-current" aria-hidden>
      <path d="M16.4 12.6c0-2.4 2-3.6 2.1-3.6-1.1-1.7-2.9-1.9-3.5-1.9-1.5-.2-2.9.9-3.7.9-.8 0-1.9-.9-3.2-.8-1.6 0-3.1 1-4 2.4-1.7 3-.4 7.3 1.2 9.7.8 1.2 1.8 2.5 3.1 2.4 1.2 0 1.7-.8 3.2-.8s1.9.8 3.2.8c1.3 0 2.2-1.2 3-2.4.9-1.3 1.3-2.7 1.3-2.8 0 0-2.6-1-2.7-3.9zM14 5.5c.7-.8 1.1-1.9 1-3-1 0-2.1.7-2.8 1.5-.6.7-1.2 1.8-1 2.9 1.1.1 2.1-.6 2.8-1.4z" />
    </svg>
  );
}

/** Store badges: links when the app is live, "Coming soon" until then. */
export function StoreButtons({ dark = true, className = "" }: { dark?: boolean; className?: string }) {
  const stores = [
    { name: "Google Play", url: site.playStoreUrl, glyph: <PlayGlyph /> },
    { name: "App Store", url: site.appStoreUrl, glyph: <AppleGlyph /> },
  ];
  const base = dark ? "bg-ink text-white hover:bg-[#1f2032]" : "bg-white text-ink hover:bg-cream";
  return (
    <div className={`flex flex-wrap gap-3 ${className}`}>
      {stores.map((s) => {
        const inner = (
          <>
            {s.glyph}
            <span className="text-left leading-tight">
              <span className="block text-[10px] font-bold tracking-wide uppercase opacity-70">{s.url ? "Get it on" : "Coming soon on"}</span>
              <span className="block font-display text-[17px] font-extrabold">{s.name}</span>
            </span>
          </>
        );
        const cls = `inline-flex items-center gap-3 rounded-2xl px-5 py-2.5 shadow-lg transition ${base}`;
        return s.url ? (
          <a key={s.name} href={s.url} className={cls} target="_blank" rel="noopener noreferrer">
            {inner}
          </a>
        ) : (
          <span key={s.name} className={`${cls} cursor-default`} aria-label={`${s.name}: coming soon`}>
            {inner}
          </span>
        );
      })}
    </div>
  );
}
