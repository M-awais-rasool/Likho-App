"use client";

import { animate, useInView, useReducedMotion } from "framer-motion";
import { useEffect, useRef, useState } from "react";
import { glyphs } from "@/lib/glyphs";

export type TraceStep = { letter: string; stroke: number; strokes: number; done: boolean };

const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * The app's writing pad: ruled lines, the letter's lane, a numbered start
 * dot, and ink that writes each stroke in order with a pen tip moving along
 * it. When the letter is written it turns green, then the next one starts.
 * Letters are the course's own strokes (100 x 100 box, baseline y = 70).
 */
export function TracingPad({
  letters,
  onStep,
  className,
  loop = true,
}: {
  letters: string[];
  onStep?: (s: TraceStep) => void;
  className?: string;
  loop?: boolean;
}) {
  const [index, setIndex] = useState(0);
  const [stroke, setStroke] = useState(0);
  const [done, setDone] = useState(false);
  const [drawing, setDrawing] = useState(false);
  const ink = useRef<(SVGPathElement | null)[]>([]);
  const pen = useRef<SVGCircleElement>(null);
  const svg = useRef<SVGSVGElement>(null);
  const inView = useInView(svg, { margin: "-8% 0px" });
  const reduce = useReducedMotion();
  const report = useRef(onStep);
  useEffect(() => {
    report.current = onStep;
  });

  const letter = letters[index % letters.length];
  const strokes = glyphs[letter] ?? [];

  useEffect(() => {
    if (!inView) return;
    let cancelled = false;
    const running: { stop: () => void }[] = [];
    const paths = ink.current.slice(0, strokes.length);
    const tell = (s: number, d: boolean) => report.current?.({ letter, stroke: s, strokes: strokes.length, done: d });

    for (const p of paths) {
      if (!p) continue;
      const len = p.getTotalLength();
      p.style.strokeDasharray = `${len}`;
      p.style.strokeDashoffset = reduce ? "0" : `${len}`;
    }

    (async () => {
      await wait(reduce ? 0 : 450);
      if (cancelled) return;
      if (reduce) {
        setStroke(strokes.length);
        setDone(true);
        tell(strokes.length, true);
        return;
      }
      setDone(false);
      for (let i = 0; i < paths.length; i++) {
        const p = paths[i];
        if (cancelled || !p) return;
        setStroke(i);
        tell(i, false);
        const len = p.getTotalLength();
        const start = p.getPointAtLength(0);
        pen.current?.setAttribute("cx", `${start.x}`);
        pen.current?.setAttribute("cy", `${start.y}`);
        await wait(380);
        if (cancelled) return;
        setDrawing(true);
        await new Promise<void>((resolve) => {
          running.push(
            animate(0, 1, {
              duration: Math.max(0.5, len / 48),
              ease: [0.45, 0, 0.35, 1],
              onUpdate: (v) => {
                p.style.strokeDashoffset = `${len * (1 - v)}`;
                const at = p.getPointAtLength(len * v);
                pen.current?.setAttribute("cx", `${at.x}`);
                pen.current?.setAttribute("cy", `${at.y}`);
              },
              onComplete: () => resolve(),
            }),
          );
        });
        setDrawing(false);
      }
      if (cancelled) return;
      setStroke(strokes.length);
      setDone(true);
      tell(strokes.length, true);
      if (!loop && index + 1 >= letters.length) return;
      await wait(1600);
      if (cancelled) return;
      setStroke(0);
      setDone(false);
      setIndex((n) => n + 1);
    })();

    return () => {
      cancelled = true;
      running.forEach((r) => r.stop());
    };
    // a new letter (index) or coming into view starts the writing again
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [index, inView, reduce]);

  const current = strokes[stroke];
  const startAt = current ? firstPoint(current) : null;

  return (
    <svg ref={svg} viewBox="10 10 80 86" className={className} role="img" aria-label={`Writing the letter ${letter}`}>
      {/* ruled lines, as in the app */}
      <line x1="0" x2="100" y1="20" y2="20" stroke="#bfd8f0" strokeWidth="0.7" />
      <line x1="0" x2="100" y1="45" y2="45" stroke="#bfd8f0" strokeWidth="0.7" strokeDasharray="2.4 2.4" />
      <line x1="0" x2="100" y1="70" y2="70" stroke="#7fb3e0" strokeWidth="0.9" />
      <line x1="0" x2="100" y1="90" y2="90" stroke="#e7dccb" strokeWidth="0.7" strokeDasharray="0.8 2" />

      {/* the lane: where the finger goes; finished strokes turn green */}
      {strokes.map((d, i) => (
        <path
          key={`lane-${letter}-${i}`}
          d={d}
          fill="none"
          stroke={i < stroke || done ? "#c9ecd8" : "#ffeab0"}
          strokeWidth="12"
          strokeLinecap="round"
          strokeLinejoin="round"
          style={{ transition: "stroke 0.4s ease" }}
        />
      ))}
      {/* the stroke being written: a dashed guide */}
      {current && !done && <path d={current} fill="none" stroke="#9aa6c8" strokeWidth="1.3" strokeDasharray="2 2.2" strokeLinecap="round" />}

      {/* ink */}
      {strokes.map((d, i) => (
        <path
          key={`ink-${letter}-${i}`}
          ref={(el) => {
            ink.current[i] = el;
          }}
          d={d}
          fill="none"
          stroke={done ? "#3bb273" : "#2b2d42"}
          strokeWidth="5.6"
          strokeLinecap="round"
          strokeLinejoin="round"
          style={{
            transition: "stroke 0.35s ease",
            filter: done ? "drop-shadow(0 0 2.5px rgba(59,178,115,.55))" : undefined,
          }}
        />
      ))}

      {/* where to start, and the pen */}
      {startAt && !done && !drawing && (
        <g key={`start-${letter}-${stroke}`}>
          <circle cx={startAt[0]} cy={startAt[1]} r="5.2" fill="#4d9de0" opacity="0.25">
            <animate attributeName="r" values="4.2;7;4.2" dur="1.4s" repeatCount="indefinite" />
            <animate attributeName="opacity" values=".35;0;.35" dur="1.4s" repeatCount="indefinite" />
          </circle>
          <circle cx={startAt[0]} cy={startAt[1]} r="4.2" fill="#4d9de0" />
          <text x={startAt[0]} y={startAt[1] + 1.6} textAnchor="middle" fontSize="4.6" fontWeight="800" fill="#fff" style={{ fontFamily: "var(--font-baloo)" }}>
            {stroke + 1}
          </text>
        </g>
      )}
      <circle ref={pen} r={done ? 0 : 2.2} fill="#ffc83d" stroke="#e0a21a" strokeWidth="0.8" cx="-10" cy="-10" />
    </svg>
  );
}

/** The first point of an SVG path ("M x y ..."). */
function firstPoint(d: string): [number, number] {
  const m = /M\s*([\d.]+)[\s,]+([\d.]+)/.exec(d);
  return m ? [Number(m[1]), Number(m[2])] : [50, 50];
}
