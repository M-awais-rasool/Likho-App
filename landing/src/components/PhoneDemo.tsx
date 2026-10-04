"use client";

import { AnimatePresence, motion } from "framer-motion";
import { Eraser, Check, House } from "lucide-react";
import Image from "next/image";
import { useState } from "react";
import { TracingPad, type TraceStep } from "./TracingPad";

/** Letters the demo writes, each with its picture (from the course). */
const words: Record<string, { word: string; picture: string }> = {
  a: { word: "apple", picture: "apple" },
  b: { word: "bee", picture: "bee" },
  c: { word: "cat", picture: "cat" },
  d: { word: "dog", picture: "dog" },
};
const letters = Object.keys(words);

/** A phone showing Likho's writing round: Pencil, the picture and the pad. */
export function PhoneDemo() {
  const [step, setStep] = useState<TraceStep>({ letter: "a", stroke: 0, strokes: 2, done: false });
  const w = words[step.letter] ?? words.a;
  const say = step.done ? "Great job!" : step.stroke === 0 ? "Start at the blue dot!" : "Now the next line!";

  return (
    <div className="relative mx-auto w-[300px] sm:w-[320px]">
      <div className="relative rounded-[48px] bg-ink p-[11px] shadow-[0_40px_80px_-30px_rgba(43,45,66,.55)]">
        <div className="relative flex aspect-[9/18.5] flex-col overflow-hidden rounded-[38px] bg-[#fdf2e4]">
          {/* status bar + notch */}
          <div className="relative flex items-center justify-between px-7 pt-3 text-[11px] font-extrabold text-ink">
            <span>9:41</span>
            <span className="absolute top-2 left-1/2 h-[22px] w-[92px] -translate-x-1/2 rounded-full bg-ink" />
            <span className="inline-block h-[10px] w-[20px] rounded-[3px] border border-ink/60 bg-leaf" />
          </div>

          {/* top bar: home + round progress */}
          <div className="flex items-center gap-3 px-4 pt-4">
            <span className="grid size-9 place-items-center rounded-full bg-white shadow-sm">
              <House className="size-4 text-ink" strokeWidth={2.6} />
            </span>
            <div className="flex flex-1 justify-center gap-1.5">
              {letters.map((l) => (
                <span
                  key={l}
                  className={`h-2.5 rounded-full transition-all duration-500 ${
                    l === step.letter ? "w-7 bg-sun" : letters.indexOf(l) < letters.indexOf(step.letter) ? "w-2.5 bg-leaf" : "w-2.5 bg-black/10"
                  }`}
                />
              ))}
            </div>
            <span className="size-9" />
          </div>

          {/* Pencil, what he says, and the picture */}
          <div className="flex items-start gap-2 px-4 pt-3">
            <motion.div animate={step.done ? { y: [0, -10, 0] } : { y: 0 }} transition={{ duration: 0.6 }} className="relative w-[58px] shrink-0">
              <Image src={step.done ? "/pencil/happy.webp" : "/pencil/talk.webp"} alt="" width={116} height={140} className="h-auto w-full" />
            </motion.div>
            <div className="min-w-0 flex-1">
              <AnimatePresence mode="wait">
                <motion.div
                  key={say}
                  initial={{ opacity: 0, y: 6, scale: 0.96 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -6 }}
                  transition={{ duration: 0.25 }}
                  className="inline-block rounded-2xl rounded-tl-sm bg-white px-3 py-1.5 font-display text-[13px] font-extrabold text-ink shadow-sm"
                >
                  {say}
                </motion.div>
              </AnimatePresence>
              <div className="mt-2 flex items-center gap-2 rounded-2xl bg-white p-2 shadow-sm">
                <AnimatePresence mode="wait">
                  <motion.div
                    key={w.picture}
                    initial={{ opacity: 0, scale: 0.6, rotate: -8 }}
                    animate={{ opacity: 1, scale: 1, rotate: 0 }}
                    exit={{ opacity: 0, scale: 0.6 }}
                    transition={{ type: "spring", stiffness: 260, damping: 18 }}
                  >
                    <Image src={`/pictures/${w.picture}.webp`} alt={w.word} width={80} height={80} className="size-11" />
                  </motion.div>
                </AnimatePresence>
                <p className="font-letter text-[15px] leading-tight text-ink">
                  <b className="text-sky-deep">{step.letter}</b> is for <b>{w.word}</b>
                </p>
              </div>
            </div>
          </div>

          {/* the writing pad */}
          <div className="relative mx-4 mt-3 flex-1 overflow-hidden rounded-[26px] bg-white shadow-[0_8px_0_rgba(43,45,66,.06)]">
            <TracingPad letters={letters} onStep={setStep} className="h-full w-full" />
            <AnimatePresence>
              {step.done && (
                <motion.span
                  initial={{ scale: 0, rotate: -30 }}
                  animate={{ scale: 1, rotate: 0 }}
                  exit={{ scale: 0, opacity: 0 }}
                  transition={{ type: "spring", stiffness: 320, damping: 16 }}
                  className="absolute top-3 right-3 grid size-9 place-items-center rounded-full bg-leaf text-white shadow-md"
                >
                  <Check className="size-5" strokeWidth={3.4} />
                </motion.span>
              )}
            </AnimatePresence>
          </div>

          {/* eraser + done */}
          <div className="flex items-center gap-3 px-4 pt-3 pb-5">
            <span className="grid size-12 place-items-center rounded-full bg-white shadow-sm">
              <Eraser className="size-5 text-eraser" strokeWidth={2.6} />
            </span>
            <span
              className="btn-3d flex flex-1 items-center justify-center gap-2 rounded-2xl bg-leaf py-3 font-display text-[15px] font-extrabold text-white"
              style={{ "--edge": "#268f58" } as React.CSSProperties}
            >
              <Check className="size-5" strokeWidth={3.2} /> Done
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
