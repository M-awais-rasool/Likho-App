import Link from "next/link";
import { nav, site } from "@/lib/site";
import { Logo } from "./Navbar";

export function Footer() {
  return (
    <footer className="mt-10 border-t border-ink/5 bg-white/60">
      <div className="mx-auto grid max-w-[1150px] gap-10 px-5 py-14 sm:px-8 md:grid-cols-[1.4fr_1fr_1fr_1fr]">
        <div>
          <Logo />
          <p className="mt-4 max-w-xs font-semibold text-ink-soft">Handwriting practice that feels like play, for children aged {site.course.ages}.</p>
        </div>
        <div>
          <h3 className="font-display text-lg font-extrabold text-ink">Explore</h3>
          <ul className="mt-3 space-y-2 font-semibold text-ink-soft">
            {nav.slice(0, 4).map((n) => (
              <li key={n.href}>
                <Link href={n.href} className="hover:text-ink">
                  {n.label}
                </Link>
              </li>
            ))}
          </ul>
        </div>
        <div>
          <h3 className="font-display text-lg font-extrabold text-ink">Legal</h3>
          <ul className="mt-3 space-y-2 font-semibold text-ink-soft">
            <li>
              <Link href="/privacy" className="hover:text-ink">
                Privacy policy
              </Link>
            </li>
            <li>
              <Link href="/terms" className="hover:text-ink">
                Terms of use
              </Link>
            </li>
            <li>
              <Link href="/delete-account" className="hover:text-ink">
                Delete your account
              </Link>
            </li>
          </ul>
        </div>
        <div>
          <h3 className="font-display text-lg font-extrabold text-ink">Contact</h3>
          <a href={`mailto:${site.email}`} className="mt-3 block font-semibold break-words text-ink-soft hover:text-ink">
            {site.email}
          </a>
        </div>
      </div>
      <div className="border-t border-ink/5">
        <div className="mx-auto flex max-w-[1150px] flex-col gap-2 px-5 py-6 text-sm font-semibold text-ink-soft sm:flex-row sm:items-center sm:justify-between sm:px-8">
          <p>
            © {new Date().getFullYear()} {site.developer}. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
  );
}
