"use client";

import { AnimatePresence, motion, useMotionValueEvent, useScroll } from "framer-motion";
import { Menu, X } from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { useState } from "react";
import { nav } from "@/lib/site";

export function Logo({ size = 38 }: { size?: number }) {
  return (
    <span className="flex items-center gap-2.5">
      <Image src="/brand/icon.webp" alt="" width={size} height={size} className="rounded-[11px] shadow-sm" preload />
      <span className="font-display text-[26px] leading-none font-extrabold tracking-tight text-ink">Likho</span>
    </span>
  );
}

export function Navbar() {
  const { scrollY } = useScroll();
  const [solid, setSolid] = useState(false);
  const [open, setOpen] = useState(false);
  useMotionValueEvent(scrollY, "change", (y) => setSolid(y > 12));

  return (
    <header
      className={`fixed inset-x-0 top-0 z-50 transition-all duration-300 ${
        solid || open ? "bg-cream/85 shadow-[0_8px_30px_-18px_rgba(43,45,66,.35)] backdrop-blur-xl" : ""
      }`}
    >
      <nav className="mx-auto flex h-[76px] max-w-[1200px] items-center justify-between px-5 sm:px-8">
        <Link href="/" aria-label="Likho home" onClick={() => setOpen(false)}>
          <Logo />
        </Link>
        <ul className="hidden items-center gap-1 lg:flex">
          {nav.map((n) => (
            <li key={n.href}>
              <Link href={n.href} className="rounded-full px-3.5 py-2 text-[15px] font-bold text-ink-soft transition hover:bg-white hover:text-ink">
                {n.label}
              </Link>
            </li>
          ))}
        </ul>
        <div className="flex items-center gap-2">
          <Link
            href="/#download"
            className="btn-3d hidden rounded-2xl bg-sun px-5 py-2.5 font-display text-[16px] font-extrabold text-ink sm:inline-block"
          >
            Get the app
          </Link>
          <button
            type="button"
            onClick={() => setOpen((o) => !o)}
            className="grid size-11 place-items-center rounded-2xl bg-white text-ink shadow-sm lg:hidden"
            aria-label={open ? "Close menu" : "Open menu"}
            aria-expanded={open}
          >
            {open ? <X className="size-5" /> : <Menu className="size-5" />}
          </button>
        </div>
      </nav>
      <AnimatePresence>
        {open && (
          <motion.ul
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            className="mx-4 mb-4 grid gap-1 rounded-3xl bg-white p-3 shadow-xl lg:hidden"
          >
            {nav.map((n) => (
              <li key={n.href}>
                <Link href={n.href} onClick={() => setOpen(false)} className="block rounded-2xl px-4 py-3 font-bold text-ink hover:bg-cream">
                  {n.label}
                </Link>
              </li>
            ))}
            <li>
              <Link
                href="/#download"
                onClick={() => setOpen(false)}
                className="btn-3d mt-1 block rounded-2xl bg-sun px-4 py-3 text-center font-display font-extrabold text-ink"
              >
                Get the app
              </Link>
            </li>
          </motion.ul>
        )}
      </AnimatePresence>
    </header>
  );
}
