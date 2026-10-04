"use client";

import { motion } from "framer-motion";
import { glyphs } from "@/lib/glyphs";

/** A letter that writes itself, stroke by stroke, when it scrolls into view. */
export function DrawnLetter({ letter, delay = 0, color = "#2b2d42", className }: { letter: string; delay?: number; color?: string; className?: string }) {
  const strokes = glyphs[letter] ?? [];
  return (
    <motion.svg
      viewBox="12 14 76 62"
      className={className}
      initial="hidden"
      whileInView="shown"
      viewport={{ once: true, margin: "-8% 0px" }}
      role="img"
      aria-label={letter}
    >
      <line x1="0" x2="100" y1="20" y2="20" stroke="#bfd8f0" strokeWidth="0.8" />
      <line x1="0" x2="100" y1="45" y2="45" stroke="#bfd8f0" strokeWidth="0.8" strokeDasharray="2.4 2.4" />
      <line x1="0" x2="100" y1="70" y2="70" stroke="#7fb3e0" strokeWidth="1" />
      {strokes.map((d, i) => (
        <path key={`lane-${i}`} d={d} fill="none" stroke="#ffeab0" strokeWidth="11" strokeLinecap="round" strokeLinejoin="round" />
      ))}
      {strokes.map((d, i) => (
        <motion.path
          key={`ink-${i}`}
          d={d}
          fill="none"
          stroke={color}
          strokeWidth="5.6"
          strokeLinecap="round"
          strokeLinejoin="round"
          variants={{ hidden: { pathLength: 0, opacity: 0 }, shown: { pathLength: 1, opacity: 1 } }}
          transition={{ pathLength: { duration: 0.55, ease: "easeInOut", delay: delay + i * 0.55 }, opacity: { duration: 0.01, delay: delay + i * 0.55 } }}
        />
      ))}
    </motion.svg>
  );
}
