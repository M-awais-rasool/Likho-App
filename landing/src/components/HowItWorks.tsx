import { BookOpen, MoveRight, PenLine, Volume2 } from "lucide-react";
import { DrawnLetter } from "./DrawnLetter";
import { Reveal, SectionTitle } from "./Reveal";

const steps = [
  {
    icon: MoveRight,
    color: "bg-sky",
    title: "Pencil shows the way",
    text: "A numbered dot shows where each stroke starts, and the line shows which way to go.",
  },
  {
    icon: PenLine,
    color: "bg-leaf",
    title: "Trace stroke by stroke",
    text: "Ink appears only while the finger follows the line, in the right order and direction, so every letter comes out right.",
  },
  {
    icon: Volume2,
    color: "bg-coral",
    title: "Hear every instruction",
    text: "Pencil reads everything out loud, so children who can't read yet can play on their own.",
  },
  {
    icon: BookOpen,
    color: "bg-grape",
    title: "Grow from letters to stories",
    text: "Letters lead to phonics, words, sentences and short stories, one small step at a time.",
  },
];

const families = [
  { name: "Straight lines first", letters: ["L", "T", "E", "F", "H"], color: "#e0a21a" },
  { name: "Then curves", letters: ["C", "O", "S", "U", "J"], color: "#2f7cc0" },
  { name: "The magic c letters", letters: ["c", "a", "d", "o", "g"], color: "#268f58" },
];

export function HowItWorks() {
  return (
    <section id="how" className="relative px-5 py-24 sm:px-8 sm:py-28">
      <SectionTitle label="How it works" title={<>Writing that sticks, one stroke at a time</>}>
        Likho teaches handwriting the way teachers do: where to start, which way to go, and lots of happy practice.
      </SectionTitle>

      <div className="mx-auto mt-14 grid max-w-[1100px] gap-5 sm:grid-cols-2 lg:grid-cols-4">
        {steps.map((s, i) => (
          <Reveal key={s.title} delay={i * 0.08} className="card relative p-6 pt-7">
            <span className="absolute top-5 right-5 font-display text-4xl font-extrabold text-ink/[.07]">{i + 1}</span>
            <span className={`grid size-12 place-items-center rounded-2xl ${s.color} text-white shadow-md`}>
              <s.icon className="size-6" strokeWidth={2.6} />
            </span>
            <h3 className="mt-5 font-display text-[22px] leading-tight font-extrabold text-ink">{s.title}</h3>
            <p className="mt-2 text-[15.5px] leading-relaxed font-semibold text-ink-soft">{s.text}</p>
          </Reveal>
        ))}
      </div>

      <Reveal className="mx-auto mt-20 max-w-[1100px] text-center">
        <h3 className="font-display text-3xl font-extrabold text-ink sm:text-4xl">Letters learned in families</h3>
        <p className="mx-auto mt-3 max-w-xl text-[17px] font-semibold text-ink-soft">
          Letters with the same shapes come together, so each one makes the next one easier.
        </p>
      </Reveal>
      <div className="mx-auto mt-10 grid max-w-[860px] gap-5">
        {families.map((f, fi) => (
          <Reveal key={f.name} delay={fi * 0.1} className="card p-5">
            <p className="font-display text-lg font-extrabold" style={{ color: f.color }}>
              {f.name}
            </p>
            <div className="mt-3 grid grid-cols-5 gap-2 sm:gap-3">
              {f.letters.map((l, i) => (
                <div key={l} className="rounded-xl bg-cream/70 p-1">
                  <DrawnLetter letter={l} delay={fi * 0.3 + i * 0.35} className="h-auto w-full" />
                </div>
              ))}
            </div>
          </Reveal>
        ))}
      </div>
    </section>
  );
}
