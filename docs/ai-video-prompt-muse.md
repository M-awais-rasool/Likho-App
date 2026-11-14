# Likho · AI video — Muse / Sora / Veo / Kling prompt pack

Ek 30-second vertical video (Reel / Shorts / Play listing promo) banane ke liye poora prompt
pack. Har clip ka alag prompt, reference image, camera move, aur negative prompt — plus edit
karne ke steps.

> **Pehle yeh parho.** Koi bhi AI video tool aapki app ki **asli UI nahi bana sakta** — woh
> fake letters, ajeeb buttons aur pighla hua text banata hai. Isliye best video **hybrid** hai:
> Pencil (mascot) ke shots AI se, aur app ke andar ke 4 shots asli phone screen recording se.
> Step 1 mein dono ka taqseem hai.

---

## Step 0 — Tool ka faisla

| Kaam | Tool |
|---|---|
| Clip generate karna (5–10s) | Sora 2, Veo 3, Kling 2.5, Runway Gen-4, Pika |
| Mascot consistent rakhna | **image-to-video** mode (reference image lazmi upload karo) |
| Cutting, text, music | CapCut (free) ya Premiere |

Agar aap jo "Muse" use kar rahe hain woh sirf video **host/search** karta hai (muse.ai), to
generate upar wale kisi tool se karo aur Muse pe host karo. Prompts sab mein same chalte hain.

---

## Step 1 — AI ko kya kya dena hai (checklist)

Har clip ke liye tool ko yeh 6 cheezein chahiye:

1. **Reference image** — ready hain: `media/reel/ref/` mein 9 saaf poses, 1024x1024, cream
   background, shadow hata hua. Jo pose chahiye woh seedha upload kar do. Yeh sab se zaroori
   step hai — isi se Pencil har clip mein ek jaisa rehta hai.

   | Clip | Reference file |
   |---|---|
   | 2 — entry / wave | `pencil_wave.jpg` |
   | 3 — letter likhna | `pencil_thumb.jpg` |
   | 4 — map pe daud | `pencil_run.jpg` |
   | 5 — jeet / stars | `pencil_cheer.jpg` |
   | 6 — dress-up | `pencil_idle.jpg` ya `pencil_master.jpg` (sab se hi-res) |
   | 7 — parents card | `pencil_thumb.jpg` |
   | 8 — end card | `pencil_cheer.jpg` |
   | (spare) | `pencil_wow.jpg`, `pencil_shy.jpg`, `pencil_sleepy.jpg` |

   Transparent PNG versions (CapCut overlay ke liye) `media/reel/ref/transparent/` mein hain.
   Dobara banane ke liye: `python3 tools/reel/cutout.py && python3 tools/reel/deshadow.py`,
   phir `tools/reel/make_refs.py`.
2. **Style block** (Step 2) — har prompt ke shuru mein paste karo, kabhi mat badlo.
3. **Shot prompt** (Step 3) — sirf us clip ka action + camera.
4. **Negative prompt** (Step 4).
5. **Settings** — 9:16 vertical, 1080×1920, 30 fps, 5–8 seconds, motion/strength ~medium.
6. **Seed** — jo clip achha aaye uska seed note kar lo, agle clips mein wohi daalo (look same
   rehta hai).

**AI se mat banwao:** app ki screens, asli bachon ke chehre, koi bhi chhota text/letters.
Woh sab real recording ya CapCut text se aayega.

---

## Step 2 — Style block (har prompt ke saath paste karo)

```
STYLE
Flat 2D vector cartoon for a children's mobile app. Bold clean dark outlines of even
thickness, soft cel shading, rounded chunky shapes, no photorealism, no 3D render, no
gradients on faces. Cinematic soft lighting, gentle depth, subtle paper-grain texture.
Smooth easing, gentle squash-and-stretch, confetti and sparkle particles.
Palette strictly: cream #FFF8EC, brand yellow #FFC83D, sky blue #4D9DE0, success green
#3BB273, warm orange #FF8A5B, dark ink #2B2D42, eraser pink #FC999C.

CHARACTER (identical in every shot — see reference image)
"Pencil": a cute walking cartoon pencil. Yellow hexagonal barrel body (#FFC83D) with soft
orange side shading, a pink eraser cap worn like a hat (#FC999C) with a silver-grey metal
band (#CBD3DC), a sharpened wooden cone at the bottom (#ECB57D) with a dark graphite tip,
big round friendly eyes with white highlights, thin brown brows, small smiling mouth, round
peach blush cheeks, short stubby arms with mitten hands, two short legs with rounded feet.
Full body in frame, feet on the ground, never cropped at the knees. Friendly and playful,
never scary.

FORMAT
Vertical 9:16, 1080x1920, 30 fps. Keep the subject inside the middle 80% of the frame.
```

---

## Step 3 — Clip by clip prompts

Har row: reference image + style block + yeh text. Har clip alag generate karo.

### Clip 1 — Hook (3s) · AI
```
A child's hand holding a chunky pencil over a blank lined school notebook on a warm wooden
table, soft morning window light. The hand draws a wobbly capital A, stops, and the pencil
taps the page twice in hesitation. No face, no body — hand only, shallow depth of field,
warm cinematic tones. Camera: slow push-in. 3 seconds.
```

### Clip 2 — Pencil ki entry (4s) · AI
```
Pencil walks in from the left on a plain cream #FFF8EC background, stops in the centre,
waves one mitten hand at the camera and does a small happy hop that bounces his eraser cap.
Soft confetti pops behind him and drifts down. Full body, feet on the ground.
Camera: locked off, slight breathing motion. 4 seconds.
```

### Clip 3 — Likhna seekhna (5s) · AI
```
Pencil stands on cream beside a giant floating white writing card with blue guide lines. He
raises his arm and draws one single huge capital letter A in the air; the stroke glows and
fills with soft green light as he finishes, then three gold sparkles pop at the tip. He looks
at the camera and smiles proudly. Camera: slow push-in, slight tilt up. 5 seconds.
```
> Sirf **ek** letter — A. Jitne zyada letters maangoge, utna gibberish banega.

### Clip 4 — Duniya ka safar (6s) · AI
```
Aerial camera flying forward above a winding cream path across rolling soft green hills
dotted with round level buttons: finished ones green with gold stars, one glowing yellow in
the middle, locked grey ones ahead with padlocks. Pencil runs happily up the path, arms
swinging. The camera lifts to reveal more worlds ahead: jungle, beach, snowy bay, a floating
castle. Flat vector game-map style, soft clouds. Camera: smooth forward dolly + rise.
6 seconds.
```

### Clip 5 — Jeet (4s) · AI
```
Celebration: three big gold cartoon stars pop into the frame one by one with a burst of
colourful confetti, while Pencil below jumps with both arms up, eyes sparkling, huge smile.
Light rays behind him. Cream background, bouncy squash-and-stretch, slight camera shake on
each star. 4 seconds.
```

### Clip 6 — Dress-up (3s) · AI
```
Pencil standing centre on cream, changing hats in three quick beats: a striped party hat,
then a gold crown, then a purple wizard hat with stars. Each change has a small puff of
sparkle smoke and he grins wider. Camera: locked off. 3 seconds.
```

### Clip 7 — Parents (3s) · AI
```
Pencil stands next to a clean floating light dashboard card on cream, pointing at it with one
mitten hand and giving a thumbs-up to the camera. The card is simple: a neat grid of blank
rounded squares, some soft green, some orange, some grey, and two large blank stat panels.
No readable text on the card. Camera: slow push-in. 3 seconds.
```
> Card jaan-boojh kar khali — numbers aur A-Z grid CapCut mein upar lagana (screen recording
> ya text se), warna AI gibberish likhega.

### Clip 8 — End card (3s) · AI
```
Pencil centred on a clean cream background, waving with both arms, gentle confetti falling
around him, soft warm light. Generous empty space above his head and below his feet for a
logo and a button. Camera: locked off, very slow push-in. 3 seconds.
```

### Asli phone recordings (AI nahi) — 4 clips
Inhe app se record karo, yeh video ko "real" banate hain:

| # | Kya record karna hai | Length |
|---|---|---|
| R1 | Level 1, letter A — blue dot se le kar green "Done" tap tak | ~6s |
| R2 | Map scroll — locked + finished dono levels dikhen | ~4s |
| R3 | Level complete — teen stars + confetti | ~3s |
| R4 | Ek arcade game (Monster Defense ya Letter Slice) ka gameplay | ~4s |

iPhone: Control Centre → Screen Recording. Android: quick settings recorder. 60 fps pe karo.

---

## Step 4 — Negative prompt (har clip mein)

```
text, letters, words, numbers, captions, watermark, logo, UI chrome, app interface,
gibberish writing, misspelled letters, photorealistic human, real child face, extra fingers,
deformed hands, three arms, cropped legs, scary face, sharp teeth, red cross, red X, dark
mood, horror, gore, 3D render, clay render, plastic shine, lens flare spam, low contrast,
muddy colours, jpeg artifacts, duplicate character, two pencils, morphing body
```

---

## Step 5 — CapCut mein jorna (30s timeline)

| Time | Clip | Burned-in text (CapCut se) |
|---|---|---|
| 0.0–3.0 | Clip 1 | "Writing practice shouldn't be a fight." |
| 3.0–7.0 | Clip 2 | "Meet Pencil." |
| 7.0–11.0 | Clip 3 | "Trace it. Then write it alone." |
| 11.0–15.0 | **R1** (asli tracing) | — |
| 15.0–19.0 | Clip 4 + **R2** | "14 worlds. 210 levels." |
| 19.0–22.0 | Clip 5 + **R3** | "Stars, stickers and hats." |
| 22.0–24.0 | Clip 6 | — |
| 24.0–25.5 | **R4** (game) | "Games too." |
| 25.5–27.5 | Clip 7 | "Parents see every letter. No ads." |
| 27.5–30.0 | Clip 8 | "Likho" + "Likhna seekho, khel khel mein." + Google Play badge |

Rules: har text max 6 words, centre, chunky rounded bold font (Baloo 2), ink #2B2D42 ya white
on yellow, soft shadow. Top/bottom 10% khali chhodo (Instagram UI dhak leta hai).
Cuts: 0.3s snappy cuts rewards section mein, baqi smooth.

---

## Step 6 — Awaaz

**Music:** bright bouncy ukulele + marimba, 110 BPM, warm — frantic nahi.
**SFX:** soft pops, sparkle chimes, ek chhota cheer stars pe.
**Voice:** warm friendly adult female, clear English.

### English VO
```
0-3s   "Every parent knows this fight."
3-7s   "This is Pencil. He teaches your child to write."
7-15s  "Every letter, step by step: trace it, join the dots, then write it all alone."
15-19s "Capitals, small letters, phonics, words and sentences. Fourteen worlds, two hundred
        and ten levels."
19-24s "Stars, stickers, dress-up and arcade games."
24-27s "And you see exactly which letters your child has mastered. No ads, ever."
27-30s "Likho. Download it free on Google Play."
```

### Roman Urdu VO (Pakistan ads ke liye)
```
0-3s   "Har ghar mein yehi masla hai — bacha likhne se bhaagta hai."
3-7s   "Yeh hai Pencil. Woh aap ke bachay ko likhna sikhata hai."
7-15s  "Har harf, step by step: pehle trace, phir dots join, phir khud likho."
15-19s "Capital, small letters, phonics, alfaaz aur jumlay. Chaudah duniyaen, do sau das levels."
19-24s "Sitaray, stickers, aur Pencil ke liye naye hats."
24-27s "Aur aap ko pata chalta hai kaunsa harf bachay ko aata hai. Koi ads nahi."
27-30s "Likho. Google Play par free download karein."
```

---

## Step 7 — Agar poora video AI se hi banana hai (single prompt)

Agar tool ek hi baar mein 30s banata hai, to
[docs/instagram-reel-prompt.md](instagram-reel-prompt.md) ka **Prompt A** copy karo — woh poori
storyboard ek prompt mein hai. Caption, hashtags aur cover frame bhi wahin hain.

---

## Step 8 — Quality check (post karne se pehle)

- [ ] Pencil har clip mein same hai (rang, cap, aankhen)?
- [ ] Koi gibberish letter ya ulta text frame mein nahi?
- [ ] Pehle 1.5 second mein hook saaf hai?
- [ ] Muted dekho — kya bina awaaz samajh aata hai? (85% log muted dekhte hain)
- [ ] Top/bottom 10% mein koi text nahi?
- [ ] Koi asli bachay ka chehra nahi (Play policy + privacy)?
