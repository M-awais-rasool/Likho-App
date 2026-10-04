"use client";

import { motion } from "framer-motion";

/** Fades and lifts its content in the first time it scrolls into view. */
export function Reveal({
  children,
  className,
  delay = 0,
  y = 28,
}: {
  children: React.ReactNode;
  className?: string;
  delay?: number;
  y?: number;
}) {
  return (
    <motion.div
      className={className}
      initial={{ opacity: 0, y }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "0px 0px -12% 0px" }}
      transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1], delay }}
    >
      {children}
    </motion.div>
  );
}

/** A section heading: a small coloured label, the title and an optional line. */
export function SectionTitle({
  label,
  title,
  children,
  center = true,
}: {
  label: string;
  title: React.ReactNode;
  children?: React.ReactNode;
  center?: boolean;
}) {
  return (
    <Reveal className={center ? "mx-auto max-w-2xl text-center" : "max-w-xl"}>
      <span className="inline-block rounded-full bg-white px-4 py-1.5 text-xs font-extrabold tracking-[0.14em] text-sky-deep uppercase shadow-sm">
        {label}
      </span>
      <h2 className="mt-4 font-display text-4xl leading-[1.05] font-extrabold text-ink sm:text-5xl">{title}</h2>
      {children && <p className="mt-4 text-lg leading-relaxed font-semibold text-ink-soft">{children}</p>}
    </Reveal>
  );
}
