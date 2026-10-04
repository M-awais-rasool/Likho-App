import { BadgeCheck, ChartColumn, Lock, ShieldCheck, Sparkles, Timer, Users, WifiOff } from "lucide-react";
import Image from "next/image";
import { Reveal, SectionTitle } from "./Reveal";

const features = [
  { icon: BadgeCheck, title: "No ads, ever", text: "Nothing to distract your child, and no ads tracking them.", color: "#3bb273" },
  { icon: Lock, title: "Parent gate", text: "Settings and the parent area sit behind a quick grown-ups-only question.", color: "#2f7cc0" },
  { icon: Users, title: "Up to 4 children", text: "Each child gets their own profile, progress and Pencil colour.", color: "#9b7fe6" },
  { icon: ChartColumn, title: "Progress at a glance", text: "See how far each child has come through the course.", color: "#ff8a5b" },
  { icon: Timer, title: "Short, healthy sessions", text: "Choose about 5, 10 or 15 minutes. Then Pencil takes a nap and says goodnight.", color: "#e0a21a" },
  { icon: WifiOff, title: "Works offline", text: "Once the course is downloaded, practice carries on without internet.", color: "#4d9de0" },
  { icon: ShieldCheck, title: "Private by design", text: "No chat and no ad trackers. Only what's needed to save progress.", color: "#268f58" },
  { icon: Sparkles, title: "Try it first", text: "Play the warm-up and the first level before creating an account.", color: "#ff9eb5" },
];

export function Parents() {
  return (
    <section id="parents" className="relative px-5 py-24 sm:px-8 sm:py-28">
      <div className="mx-auto grid max-w-[1150px] items-start gap-12 lg:grid-cols-[.8fr_1.2fr]">
        <div className="lg:sticky lg:top-28">
          <SectionTitle label="For parents" center={false} title={<>Made for kids. Built with parents in mind.</>}>
            A calm, safe place to practise, with the controls you need and nothing you don&apos;t.
          </SectionTitle>
          <Reveal delay={0.1} className="mt-8 hidden lg:block">
            <Image src="/pencil/thumbs.webp" alt="Pencil giving a thumbs up" width={682} height={827} className="w-[240px] animate-bob drop-shadow-xl" />
          </Reveal>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          {features.map((f, i) => (
            <Reveal key={f.title} delay={(i % 2) * 0.08} className="card flex gap-4 p-5">
              <span className="grid size-12 shrink-0 place-items-center rounded-2xl" style={{ background: `${f.color}1f`, color: f.color }}>
                <f.icon className="size-6" strokeWidth={2.4} />
              </span>
              <div>
                <h3 className="font-display text-xl font-extrabold text-ink">{f.title}</h3>
                <p className="mt-1 text-[15px] leading-relaxed font-semibold text-ink-soft">{f.text}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
