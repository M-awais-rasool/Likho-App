# Likho · Instagram Reel — complete AI prompt pack

Everything an AI video tool (Sora, Veo, Kling, Runway, Pika, InVideo, Canva AI…) needs to make a
30-second Instagram Reel for Likho. Copy **Prompt A** for a single-shot generator, or use
**Prompt B** (shot by shot) if the tool makes one clip at a time.

> **Read this first.** No AI video tool can redraw the real app UI correctly — it will invent
> fake letters, wrong buttons and melted text. The reel that converts is a **hybrid**:
> screen recordings from the real app (map, tracing, boss, games) + AI-made intro/outro and
> b-roll of Pencil. Section 7 says exactly which 4 clips to record on the phone.

---

## 0. The reel that is already built

`media/reel/likho-reel-30s.mp4` — 30 s, 1080x1920, H.264 + AAC, built from this storyboard by
[tools/reel](../tools/reel/README.md) out of the real app screenshots, Pencil's master art and
the app's own design tokens. Music, sound effects and voice-over are synthesised in
`tools/reel/audio.py`, so nothing in it is licensed from anyone else.

Two things to know before posting it:

- **The voice-over is macOS `say` (Samantha)** — right words, robotic delivery. Record the script
  yourself or buy one read and drop it in; `tools/reel/README.md` says where.
- **The app footage is still screenshots with camera moves**, not live play. Section 7's four
  screen recordings are what turn it into the real thing.

Rebuild it with the commands in `tools/reel/README.md`.

---

## 1. The brand pack (paste into every prompt)

**Product:** Likho — "Likho: ABC Writing for Kids", an English handwriting app for children aged
5 to 8 (KG to Class 3). "Likho" means "write!" in Urdu. Tagline: *Likhna seekho, khel khel mein.*
Live on Google Play: `com.likho.abcwriting`.

**Mascot — "Pencil":**
A cheerful cartoon pencil who walks and talks. Body is a warm yellow hexagonal pencil barrel
(#FFC83D) with soft orange shading on the sides, a **pink eraser cap** like a hat (#FC999C) with
a grey-silver metal band under it (#CBD3DC), a sharpened wooden cone at the bottom (#ECB57D) with
a dark graphite tip (#323447). Big round friendly eyes with white highlights, thin brown brows,
a small smiling mouth, two round peach-orange blush cheeks (#F78A5C). Short stubby yellow arms
with mitten hands and two short legs with rounded feet. Style: **flat vector cartoon, bold clean
dark outline of even thickness, soft cel shading, no gradients on skin, no 3D render, no realism,
Pixar-lite 2D children's app illustration**. Always friendly, never scary.

**Colour palette (do not drift):**

| Role | Hex |
|---|---|
| Cream background | `#FFF8EC` |
| Brand yellow | `#FFC83D` |
| Sky blue | `#4D9DE0` |
| Success green | `#3BB273` |
| Hint orange (never red) | `#FF8A5B` |
| Ink / text | `#2B2D42` |
| Eraser pink | `#FC999C` |

**Type:** rounded chunky headlines (Baloo 2), friendly body text (Nunito). Big, bold, high
contrast, heavy rounded weights. Never thin serif fonts.

**Tone:** warm, playful, encouraging, calm. Made for Pakistani and South Asian parents, in
English. Nothing scary, nothing competitive, no red crosses, no "wrong" buzzers.

**Format:** 9:16 vertical, 1080×1920, 30 fps, 30 seconds, mobile-first, safe margins 10% top and
bottom (Instagram hides those with UI).

---

## 2. Prompt A — one-shot master prompt (copy-paste)

```
Create a 30-second vertical 9:16 (1080x1920, 30fps) Instagram Reel advertising "Likho:
ABC Writing for Kids", an English handwriting learning app for children aged 5 to 8.

ART DIRECTION
Flat 2D vector cartoon in a children's mobile-app style: bold clean dark outlines of even
thickness, soft cel shading, rounded shapes, no photorealism, no 3D render, no gradients
on faces. Palette strictly: cream #FFF8EC backgrounds, brand yellow #FFC83D, sky blue
#4D9DE0, success green #3BB273, warm orange #FF8A5B, dark ink #2B2D42, eraser pink
#FC999C. Soft rounded chunky sans-serif typography (Baloo 2 style), very large and bold.
Cheerful, calm, warm. Smooth easing on every motion, gentle squash-and-stretch, confetti
and sparkle particles for celebrations.

MASCOT (must stay identical in every shot)
"Pencil": a cute walking cartoon pencil. Yellow hexagonal barrel body (#FFC83D), pink
eraser cap worn like a hat (#FC999C) with a silver-grey metal band (#CBD3DC), sharpened
wooden cone at the bottom (#ECB57D) with a dark graphite tip, big round friendly eyes with
white highlights, small smile, round peach blush cheeks, short stubby arms with mitten
hands, two short legs. Full body visible, standing on the ground, never cropped at the
knees. Friendly and silly, never scary.

STORYBOARD (30 seconds)

0.0-3.0s  HOOK. Close on a child's hand holding a real pencil over a blank school
notebook; the letter A is drawn shakily and the child sighs. Fast whip-pan transition
into the app's cream world. Big bold text slams in: "Writing practice shouldn't be a
fight."

3.0-7.0s  MEET PENCIL. Pencil walks in from the left on a cream background, waves at the
camera and hops. Text under him: "Meet Pencil." Confetti pop on the wave.

7.0-13.0s  TRACING. A phone mock-up (rounded corners, no brand logo) fills the frame
showing a huge capital letter A on a lined writing pad: a blue start dot, blue direction
arrows, a glowing path, and a finger drawing the stroke so the path fills in green. A
small apple picture and a speaker button sit above it. Green "Done" button pulses. Text:
"Trace it. Then write it alone."

13.0-18.0s  WORLDS. Zoom out to a winding path over soft green hills, dotted with round
level buttons: finished ones green with stars, the current one glowing yellow, locked ones
grey with a padlock. Pencil runs up the path. The camera flies past themed worlds: grass,
jungle, beach, forest, island, castle, mountain, snowy bay, space. Text: "14 worlds.
210 levels."

18.0-23.0s  REWARDS. Rapid cuts: three gold stars pop in with confetti and Pencil
cheering with arms up; a sticker book page filling with stickers; Pencil wearing a party
hat, then a crown, then a wizard hat. Text: "Stars, stickers and hats."

23.0-27.0s  PARENTS. A clean light dashboard card on cream: a grid of letters A-Z in
green, orange and grey, and two numbers "42 min this week" and "7 levels". Text: "Parents
see every letter. No ads."

27.0-30.0s  END CARD. Pencil centred on cream, waving with both arms, confetti. Big
headline "Likho" with the line "Likhna seekho, khel khel mein." and a Google Play badge
shape at the bottom. Text: "Free to start."

CAMERA & EDITING
Mostly locked-off or slow push-in. One whip pan at 3s, one zoom-out at 13s, snappy
0.3-second cuts in the rewards section, everything else smooth. Light motion blur on the
fast cuts only.

AUDIO
Bright, bouncy, kid-friendly ukulele and marimba track, 110 BPM, warm and not frantic.
Soft pops, sparkle chimes and a short cheer on the star moment. Warm friendly adult
female voice-over, clear neutral-to-Indian-English accent, speaking to a parent.

VOICE-OVER SCRIPT (timed)
0-3s   "Every parent knows this fight."
3-7s   "This is Pencil. He teaches your child to write."
7-13s  "Every letter, step by step: trace it, join the dots, then write it all alone."
13-18s "Capitals, small letters, phonics, words and sentences. Fourteen worlds, two
        hundred and ten levels."
18-23s "Stars, stickers and a whole wardrobe for Pencil."
23-27s "And you see exactly which letters your child has mastered. No ads, ever."
27-30s "Likho. Download it free on Google Play."

ON-SCREEN TEXT RULES
Maximum six words per card, centred, chunky rounded bold font, dark ink #2B2D42 on cream
or white on yellow, with a soft shadow. Keep all text inside the middle 80% of the frame.
Spell every word correctly; no invented letters anywhere in the frame.

HARD CONSTRAINTS
No real children's faces. No photorealistic humans. No scary monsters. No red "wrong"
marks. No text other than the words given above. No watermark, no logos other than
Likho's own, no UI chrome from TikTok or Instagram. No gibberish letterforms: every letter
drawn must be a correct, readable English letter.
```

---

## 3. Prompt B — shot by shot (for 5-8s clip generators)

Give the **art direction + mascot block** from section 1 with every one of these, then add the
shot. Generate each at 1080×1920, then cut them together in CapCut.

| # | Len | Prompt to add |
|---|---|---|
| 1 | 3s | "Close-up, soft daylight: a child's hand holding a chunky pencil over a blank lined school notebook, drawing a wobbly capital A, then stopping. No face visible. Shallow depth of field, warm tones. Slow push-in." |
| 2 | 4s | "Pencil (the mascot) walks in from the left on a plain cream #FFF8EC background, stops centre, waves one mitten hand at the camera and does a small happy hop. Confetti pops behind him. Full body in frame, feet on the ground. Locked-off camera." |
| 3 | 6s | "A hand-held phone mock-up fills the vertical frame, screen showing a children's writing app: a huge dark capital letter A on a white pad with blue guide lines, a blue start dot, blue arrows, and the stroke filling in soft green as an invisible finger traces it. A small red apple illustration and a blue round speaker button above, a green 'Done' button below. Clean flat UI, cream background. Slow push-in." |
| 4 | 5s | "Top-down camera flying along a winding cream path across rolling soft green hills with round level buttons on it: green buttons with gold stars behind, one glowing yellow button in the middle, grey padlocked buttons ahead. The Pencil mascot runs up the path. Flat vector game-map style, cream #FFF8EC sky. Smooth forward camera move." |
| 5 | 5s | "Celebration: three gold cartoon stars pop into the frame one by one with a burst of colourful confetti, while the Pencil mascot below jumps with both arms up and a huge smile. Cream background, flat vector style, bouncy squash-and-stretch." |
| 6 | 3s | "The Pencil mascot standing centre on cream, changing hats in three quick cuts: a striped party hat, then a gold crown, then a purple wizard hat with stars. He grins wider each time. Flat vector style." |
| 7 | 3s | "A clean light app dashboard card on cream: a neat grid of the letters A to Z in rounded squares, some filled soft green, some orange, some grey, and two big stat numbers above. Flat UI illustration, no clutter, gentle fade-in of the squares." |
| 8 | 3s | "End card: the Pencil mascot centred on cream, waving with both arms, gentle confetti falling. Empty clean space above and below him for a logo and a button. Flat vector style, locked-off camera." |

---

## 4. Voice-over — alternative Urdu / Roman Urdu read

Use this if the reel is aimed at Pakistani parents on a Pakistan-targeted ad set. Keep the app
name and "Google Play" in English.

```
0-3s   "Har ghar mein yehi masla hai — bacha likhne se bhaagta hai."
3-7s   "Yeh hai Pencil. Woh aap ke bachay ko likhna sikhata hai."
7-13s  "Har harf, step by step: pehle trace, phir dots join, phir khud likho."
13-18s "Capital, small letters, phonics, alfaaz aur jumlay. Chaudah duniyaen, do sau das levels."
18-23s "Sitaray, stickers, aur Pencil ke liye naye hats."
23-27s "Aur aap ko pata chalta hai kaunsa harf bachay ko aata hai. Koi ads nahi."
27-30s "Likho. Google Play par free download karein."
```

---

## 5. Caption, hashtags and cover

**Caption**

```
Writing practice without the daily fight. ✏️

Likho teaches 5 to 8 year olds to write English, one letter at a time — trace it, join the
dots, then write it alone. Pencil reads every instruction out loud, so kids who can't read
yet can play on their own.

• All 26 capital + 26 small letters
• Phonics, words and sentences
• 14 worlds, 210 levels
• Stars, stickers and dress-up
• No ads. Parent lock. Works offline.

Free to start — link in bio. 🎒
```

**Hashtags (put in the first comment)**

```
#Likho #handwritingforkids #learntowrite #abcforkids #kidslearningapp #phonics
#preschoolathome #montessoriathome #earlyyears #kglearning #parentingpakistan
#pakistanimoms #desimoms #edtech #kidsapp #alphabetlearning #tracingletters
#homeschoolingkids #classroomtech #screentimethatcounts
```

**Cover frame:** Pencil waving on cream with the headline "Writing, without the fight" —
keep the text in the upper third so the Instagram grid crop doesn't cut it.

---

## 6. What to change per platform

- **Reels / TikTok:** keep 30s, hook in the first 1.5s, captions burned in (85% watch muted).
- **Story / ad:** cut to 15s — shots 1, 3, 5, 8 only.
- **YouTube Shorts:** add 2s to the end card so the subscribe prompt fits.

---

## 7. The hybrid version (recommended)

Record these four clips on a real phone with the app, and use AI only for shots 1, 2, 5, 6 and 8:

1. **Tracing** — level 1, letter A, from the blue dot to the green "Done" tap. (≈6s)
2. **World map** — scroll the path so locked and finished levels both show. (≈4s)
3. **Level complete** — the three stars and confetti landing. (≈3s)
4. **One arcade game** — Monster Defense or Letter Slice, 4 seconds of play.

On iOS, Control Centre → Screen Recording; on Android, the quick-settings recorder. Record at
60 fps if the phone allows, then slow the map scroll to 0.8× in the edit. This is the part no
AI tool can fake, and it is what makes a parent believe the app is real.
