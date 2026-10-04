"use client";

import { AnimatePresence, motion } from "framer-motion";
import { HeartHandshake, Palette, Shirt, Volume2 } from "lucide-react";
import Image from "next/image";
import { useEffect, useState } from "react";
import { Reveal } from "./Reveal";

const lines = ["A is for apple!", "Start at the blue dot!", "Follow the arrow!", "Great job!", "Let's wake up the sleepy snail!"];

/** The six colours a child can pick for Pencil, as in the app. */
const colours = [
  { name: "Sunny yellow", swatch: "#ffc83d" },
  { name: "Sky blue", swatch: "#4d9de0" },
  { name: "Leaf green", swatch: "#3bb273" },
  { name: "Coral", swatch: "#ff8a5b" },
  { name: "Lavender", swatch: "#b79ced" },
  { name: "Pink", swatch: "#ff9eb5" },
];

const points = [
  { icon: Volume2, title: "Talks your child through it", text: "Every instruction is read out loud in a warm, clear voice." },
  { icon: HeartHandshake, title: "Cheers and helps", text: "Pencil celebrates every success and gently shows the way after a slip. Mistakes are never red." },
  { icon: Palette, title: "In your child's colour", text: "Each child picks Pencil's colour when their profile is made." },
  { icon: Shirt, title: "Ready to dress up", text: "Hats, glasses, a cape and more, bought with the stars your child earns." },
];

export function MeetPencil() {
  const [line, setLine] = useState(0);
  const [colour, setColour] = useState(0);
  useEffect(() => {
    const t = setInterval(() => setLine((l) => (l + 1) % lines.length), 2600);
    return () => clearInterval(t);
  }, []);

  return (
    <section id="pencil" className="relative px-5 py-24 sm:px-8 sm:py-28">
      <div className="mx-auto grid max-w-[1150px] items-center gap-14 lg:grid-cols-2">
        {/* Pencil, speaking, in the chosen colour */}
        <Reveal className="relative mx-auto w-full max-w-[460px]">
          <div className="absolute inset-6 rounded-full bg-[radial-gradient(circle,rgba(255,200,61,.35),rgba(255,200,61,0)_70%)]" />
          <div className="relative grid place-items-center pt-20">
            <AnimatePresence mode="wait">
              <motion.div
                key={line}
                initial={{ opacity: 0, y: 10, scale: 0.9 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, y: -8, scale: 0.95 }}
                transition={{ duration: 0.3 }}
                className="absolute top-0 left-1/2 -translate-x-1/2 rounded-3xl rounded-bl-md bg-white px-6 py-3.5 font-display text-[22px] font-extrabold whitespace-nowrap text-ink shadow-xl"
              >
                {lines[line]}
              </motion.div>
            </AnimatePresence>
            <AnimatePresence mode="wait">
              <motion.div
                key={colour}
                initial={{ opacity: 0, scale: 0.85, rotate: -6 }}
                animate={{ opacity: 1, scale: 1, rotate: 0 }}
                exit={{ opacity: 0, scale: 0.9 }}
                transition={{ type: "spring", stiffness: 240, damping: 18 }}
                className="w-[230px] sm:w-[260px]"
              >
                <Image
                  src={colour === 0 ? "/pencil/talk.webp" : `/pencil/colour-${colour}.webp`}
                  alt={`Pencil in ${colours[colour].name.toLowerCase()}`}
                  width={675}
                  height={819}
                  className="h-auto w-full animate-bob drop-shadow-xl"
                />
              </motion.div>
            </AnimatePresence>
            <div className="mt-6 h-4 w-40 rounded-full bg-ink/10 blur-md" />
          </div>
          <div className="mt-6 flex flex-wrap justify-center gap-3" role="radiogroup" aria-label="Pencil's colour">
            {colours.map((c, i) => (
              <button
                key={c.name}
                type="button"
                role="radio"
                aria-checked={colour === i}
                aria-label={c.name}
                onClick={() => setColour(i)}
                className={`size-10 rounded-full border-4 transition-transform hover:scale-110 ${colour === i ? "scale-110 border-ink" : "border-white shadow-md"}`}
                style={{ background: c.swatch }}
              />
            ))}
          </div>
          <p className="mt-3 text-center text-sm font-bold text-ink-soft">Tap a colour: every child picks their own Pencil.</p>
        </Reveal>

        <div>
          <Reveal>
            <span className="inline-block rounded-full bg-white px-4 py-1.5 text-xs font-extrabold tracking-[0.14em] text-sky-deep uppercase shadow-sm">Meet Pencil</span>
            <h2 className="mt-4 font-display text-4xl leading-[1.05] font-extrabold text-ink sm:text-5xl">Your child&apos;s favourite writing buddy</h2>
            <p className="mt-4 text-lg leading-relaxed font-semibold text-ink-soft">
              Pencil waves, talks, dances and cheers. He makes practice feel like play, so children want to come back for one more letter.
            </p>
          </Reveal>
          <div className="mt-8 grid gap-4 sm:grid-cols-2">
            {points.map((p, i) => (
              <Reveal key={p.title} delay={i * 0.07} className="rounded-3xl bg-white/70 p-5">
                <p.icon className="size-7 text-sun-deep" strokeWidth={2.4} />
                <h3 className="mt-3 font-display text-xl font-extrabold text-ink">{p.title}</h3>
                <p className="mt-1 text-[15px] leading-relaxed font-semibold text-ink-soft">{p.text}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
