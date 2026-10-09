"use client";

import { motion, useScroll, useSpring } from "framer-motion";
import { BookOpen, Bus, CaseLower, CaseUpper, Cloud, Ear, Footprints, MessageCircleQuestionMark, Moon, Mountain, Rocket, Shell, Sprout } from "lucide-react";
import Image from "next/image";
import { useLayoutEffect, useRef, useState } from "react";
import { site } from "@/lib/site";
import { Reveal, SectionTitle } from "./Reveal";

// The course's worlds in order, worded as in the store listing (docs/google-play-listing.md).
const worlds = [
  { name: "Letter Land", skill: "Capital letters A to Z", color: "#ffc83d", deep: "#e0a21a", picture: "apple", boss: "Sleepy Snail", icon: CaseUpper },
  { name: "Small Letter Cove", skill: "Small letters a to z and their sounds", color: "#4d9de0", deep: "#2f7cc0", picture: "fish", boss: "Sleepy Fish", icon: CaseLower },
  { name: "Phonics Forest", skill: "Words like cat, hen, pig, dog and bus", color: "#3bb273", deep: "#268f58", picture: "owl", boss: "Sleepy Bear", icon: Ear },
  { name: "Word Town", skill: "Colours, numbers, animals, family and food", color: "#ff8a5b", deep: "#e2683a", picture: "bus", boss: "Robot-Bus", icon: Bus },
  { name: "Sound Mountain", skill: "sh, ch, th, ee, oo and more letter pairs", color: "#8a6fd1", deep: "#6a51b0", picture: "tree", boss: "Sleepy Goat", icon: Mountain },
  { name: "Blend Beach", skill: "star, frog, flag and other blends", color: "#ee9a32", deep: "#c27a1a", picture: "star", boss: "Sleepy Crab", icon: Shell },
  { name: "Sight Word Garden", skill: "the, said, was, they and other words to know by sight", color: "#dd5e8c", deep: "#b4436d", picture: "flower", boss: "Sleepy Ladybug", icon: Sprout },
  { name: "Sentence Sky", skill: "Capital letters, full stops and sentences such as “I see a cat.”", color: "#9b7fe6", deep: "#6a48dd", picture: "rainbow", boss: "Sleepy Cloud", icon: Cloud },
  { name: "Action Jungle", skill: "Doing words, describing words and in, on, under", color: "#86a321", deep: "#657d14", picture: "lion", boss: "Sleepy Monkey", icon: Footprints },
  { name: "Question Island", skill: "Who, what, where, and talking with friendly aliens", color: "#d4a20a", deep: "#a67c00", picture: "robot", boss: "Sleepy Turtle", icon: MessageCircleQuestionMark },
  { name: "Reading River", skill: "Read sentences and little stories, then answer questions", color: "#1897b9", deep: "#0f7591", picture: "storybook", boss: "Sleepy Frog", icon: BookOpen },
  { name: "Story Space", skill: "Put stories in order and write about me, my family and my day", color: "#2b2d42", deep: "#14152a", picture: "planet", boss: "Sleepy Moon", icon: Rocket },
];

/** A winding road from the top of the box, through every stop, to the bottom. Each bend swings to the other side. */
function roadThrough(stops: { x: number; y: number }[], height: number) {
  if (!stops.length) return "";
  const points = [{ x: stops[0].x, y: 0 }, ...stops, { x: stops[stops.length - 1].x, y: height }];
  let d = `M${points[0].x} 0`;
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1];
    const b = points[i];
    const swing = (i % 2 ? 1 : -1) * Math.min(44, Math.max(10, a.x - 6));
    const third = (b.y - a.y) / 3;
    d += ` C${a.x + swing} ${a.y + third}, ${b.x + swing} ${b.y - third}, ${b.x} ${b.y}`;
  }
  return d;
}

export function Worlds() {
  const ref = useRef<HTMLDivElement>(null);
  const stopRefs = useRef<(HTMLSpanElement | null)[]>([]);
  const [road, setRoad] = useState<{ width: number; height: number; d: string } | null>(null);

  // The stops move with the layout (phone vs desktop, text wrapping), so the road is measured from them.
  useLayoutEffect(() => {
    const box = ref.current;
    if (!box) return;
    const measure = () => {
      const r = box.getBoundingClientRect();
      const stops = stopRefs.current.flatMap((el) => {
        if (!el) return [];
        const s = el.getBoundingClientRect();
        return [{ x: Math.round(s.left + s.width / 2 - r.left), y: Math.round(s.top + s.height / 2 - r.top) }];
      });
      setRoad({ width: r.width, height: r.height, d: roadThrough(stops, r.height) });
    };
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(box);
    return () => observer.disconnect();
  }, []);

  const { scrollYProgress } = useScroll({ target: ref, offset: ["start 75%", "end 55%"] });
  const progress = useSpring(scrollYProgress, { stiffness: 90, damping: 24 });

  return (
    <section id="worlds" className="relative overflow-hidden bg-[linear-gradient(180deg,#fff8ec_0%,#fff2d9_50%,#fff8ec_100%)] px-5 py-24 sm:px-8 sm:py-28">
      <SectionTitle label="The journey" title={<>{site.course.worlds} worlds. {site.course.levels} levels. One big adventure.</>}>
        Every world ends with a sleepy boss that your child wakes up by finishing the level. Each level is a handful of short, playful rounds.
      </SectionTitle>

      <div ref={ref} className="relative mx-auto mt-16 max-w-[1000px]">
        {/* the road between the worlds, drawn as you scroll */}
        {road && (
          <svg className="pointer-events-none absolute inset-0 overflow-visible" width={road.width} height={road.height} viewBox={`0 0 ${road.width} ${road.height}`} aria-hidden>
            <path d={road.d} fill="none" stroke="#e9dcc3" strokeWidth="6" strokeDasharray="14 14" />
            <motion.path d={road.d} fill="none" stroke="#ffc83d" strokeWidth="6" strokeLinecap="round" style={{ pathLength: progress }} />
          </svg>
        )}

        {/* on wide screens each right-hand card tucks up beside the left-hand one, so 12 worlds stay a short scroll */}
        <ol className="relative space-y-10 md:space-y-4">
          {worlds.map((w, i) => {
            const right = i % 2 === 1;
            return (
              <li key={w.name} className={`relative pl-14 sm:pl-16 md:flex md:pl-0 ${right ? "md:-mt-20 md:justify-end" : ""}`}>
                {/* the stop on the road */}
                <span
                  ref={(el) => {
                    stopRefs.current[i] = el;
                  }}
                  className="absolute top-7 left-5 z-10 grid size-10 -translate-x-1/2 place-items-center rounded-full font-display text-lg font-extrabold text-white shadow-lg md:top-1/2 md:left-1/2 md:size-12 md:-translate-y-1/2 md:text-xl"
                  style={{ background: w.color, boxShadow: `0 5px 0 ${w.deep}` }}
                >
                  {i + 1}
                </span>
                <Reveal y={24} className="md:w-[calc(50%-56px)]">
                  <div className="card group relative overflow-hidden p-5 transition-transform duration-300 hover:-translate-y-1 sm:p-6">
                    <div className="absolute -top-10 -right-10 size-40 rounded-full opacity-15" style={{ background: w.color }} />
                    <div className="relative flex items-start gap-3 sm:gap-4">
                      <div className="min-w-0 flex-1">
                        <span className="inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-extrabold text-white" style={{ background: w.deep }}>
                          <w.icon className="size-3.5" strokeWidth={3} /> World {i + 1}
                        </span>
                        <h3 className="mt-3 font-display text-[26px] leading-tight font-extrabold text-ink">{w.name}</h3>
                        <p className="mt-1.5 text-[15.5px] leading-relaxed font-semibold text-ink-soft">{w.skill}</p>
                        <p className="mt-3 inline-flex items-center gap-1.5 text-[13px] font-extrabold text-ink">
                          <Moon className="size-4 text-grape" strokeWidth={2.6} /> Wake up the {w.boss}!
                        </p>
                      </div>
                      <Image
                        src={`/pictures/${w.picture}.webp`}
                        alt=""
                        width={96}
                        height={96}
                        className="size-14 shrink-0 transition-transform duration-500 group-hover:scale-110 group-hover:-rotate-6 sm:size-20"
                      />
                    </div>
                  </div>
                </Reveal>
              </li>
            );
          })}
        </ol>
      </div>
    </section>
  );
}
