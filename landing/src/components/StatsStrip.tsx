"use client";

import { animate, useInView, useReducedMotion } from "framer-motion";
import { useEffect, useRef, useState } from "react";
import { site } from "@/lib/site";

function Count({ from, to }: { from: number; to: number }) {
  const ref = useRef<HTMLSpanElement>(null);
  const inView = useInView(ref, { once: true, margin: "-10% 0px" });
  const reduce = useReducedMotion();
  const [n, setN] = useState(from);
  useEffect(() => {
    if (!inView || reduce) return;
    const c = animate(from, to, { duration: 1.6, ease: [0.22, 1, 0.36, 1], onUpdate: (v) => setN(Math.round(v)) });
    return () => c.stop();
  }, [inView, reduce, from, to]);
  return <span ref={ref}>{reduce ? to : n}</span>;
}

const stats = [
  { from: 0, to: site.course.worlds, label: "worlds to explore", color: "text-sun-deep" },
  { from: 0, to: site.course.levels, label: "levels", color: "text-sky" },
  { from: 0, to: site.course.activities, label: "fun activities", color: "text-leaf" },
  { from: 9, to: 0, label: "ads, ever", color: "text-coral" },
];

export function StatsStrip() {
  return (
    <section className="relative px-5 sm:px-8">
      <div className="card mx-auto grid max-w-[1100px] grid-cols-2 gap-y-8 px-6 py-9 sm:px-10 md:grid-cols-4">
        {stats.map((s) => (
          <div key={s.label} className="text-center">
            <p className={`font-display text-5xl leading-none font-extrabold sm:text-6xl ${s.color}`}>
              <Count from={s.from} to={s.to} />
            </p>
            <p className="mt-2 text-[15px] font-extrabold text-ink-soft">{s.label}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
