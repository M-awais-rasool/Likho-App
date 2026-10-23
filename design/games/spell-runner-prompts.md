# Likho Games · "Spell Runner" · image prompts (Gemini)

Pencil rides a skateboard down a long country road. We see him **from
behind**, like every runner game. A picture shows the word to spell (🐱 cat).
Letter bubbles come down the 3 lanes; the child swipes to pick c, then a,
then t, and taps to jump over a puddle or a log. A whole word gives a boost,
and after a few words there is the finish line.

These are made the same way as Monster Defense (`monster-defense-prompts.md`):
one **master**, then a **pose sheet**, then backgrounds and things, all on a
plain white background. Backgrounds are phone-tall (9:16).

The app draws these itself, so **do not** ask Gemini for them: the letter
bubbles, the moving lane lines on the road, the word at the top, stars,
sparkles, speed lines, score and buttons.

## How to use (every time)

1. Open a **new Gemini chat** for each picture group.
2. **Attach two pictures of Pencil** as the style reference:
   - `design/mascot/Gemini_Generated_Image_ic1bzvic1bzvic1b.jpeg` (master pose)
   - `design/mascot/Gemini_Generated_Image_y5imh7y5imh7y5im.jpeg` (expression sheet)
3. Paste the prompt. If the style drifts, say: *"Match the attached Pencil
   style exactly: same outline thickness, same soft shading, same colours."*
4. For a pose sheet, stay in the **same chat** as its master and also
   attach the master you chose.
5. Save each picture with the **file name** given, in
   `design/games/spell-runner/` (jpeg is fine, the name is what matters).

Rules for every picture (they are in the prompts too):
- outlines closed and unbroken (the background is cut away from the outside)
- nothing touching the picture's edge, clear space between things
- no text, letters, numbers or watermark (the app writes the letters)

---

## The style (part of every prompt below)

> Style: match the attached Pencil mascot exactly. Cute 2D cartoon
> illustration for a children's learning app, clean vector look. Smooth,
> medium-thin outlines in a darker warm shade of each colour (never pure
> black), closed and unbroken. Soft warm colours with gentle gradient shading
> and one soft highlight, no texture. Rounded, friendly shapes. Not realistic,
> not 3D, not anime. No text, no letters, no numbers, no watermark.

---

## 1. Pencil on his skateboard, from behind

### 1a · Master → `pencil_skate_master.png`

```
Using the attached Pencil mascot (keep him exactly the same: yellow pencil
body, pink eraser on top with the grey metal band, the wooden cone and dark
pointed tip at the bottom, his short yellow arms and legs, same outline and
shading), draw him FROM BEHIND, riding a skateboard away from the viewer.

We see his back: the plain yellow back of the pencil (no face), the pink
eraser and grey band at the top, his arms slightly out to the sides for
balance, his two little legs standing on the skateboard, knees a bit bent.
The skateboard is bright sky-blue with a white stripe, four round orange
wheels, seen from behind and slightly above, so we see the back of the board
and the two back wheels best.

Pose: riding straight ahead, centred, calm and happy balance.

Style: match the attached Pencil mascot exactly. Cute 2D cartoon illustration
for a children's learning app, clean vector look. Smooth, medium-thin
outlines in a darker warm shade of each colour (never pure black), closed and
unbroken. Soft warm colours with gentle gradient shading and one soft
highlight, no texture. Rounded, friendly shapes. Not realistic, not 3D, not
anime. No text, no letters, no numbers, no watermark.

Composition: one character centred, plain pure white background, a soft
light-grey oval shadow under the skateboard, lots of empty space around him,
nothing touching the edges. 16:9 image.
```

### 1b · Pose sheet → `pencil_skate_sheet.png`

```
Using the attached Pencil on his skateboard seen from behind (keep him and
the board exactly the same: colours, shapes, outline style, size), make a
pose sheet: 6 poses in 2 rows of 3, all the same size, all seen FROM BEHIND,
evenly spaced with clear white space between them.

IMPORTANT: in every pose he rides AWAY from the viewer, down a road into the
distance. The skateboard points straight away from us: we see only its short
back end (the tail, foreshortened) and the two back wheels side by side under
it, never the long side of the board. No motion lines, no blur.

Top row, left to right:
1. ride: riding straight ahead, arms a little out for balance
2. lean left: the board and his body tilted to the left, turning left,
   left arm down, right arm up
3. lean right: the board and his body tilted to the right, turning right,
   right arm down, left arm up

Bottom row, left to right:
4. jump: the board high in the air under his feet (a skateboard jump),
   knees bent, both arms up, a gap and a small shadow far below
5. wobble: the board tipping, Pencil off balance, arms waving in circles,
   one leg up (funny, not hurt)
6. cheer: still riding, turning his head back over his shoulder so we see
   his happy face from the side, one arm up in a fist of joy

Style: match the attached Pencil mascot exactly, same outlines and soft
shading. Plain pure white background, a soft light-grey oval shadow under
each pose, nothing touching the edges. No text, no labels, no numbers.
16:9 image.
```

---

## 2. Backgrounds (phone-tall, no characters)

**Attach these 2 pictures** (only for the style and colours):
1. `design/mascot/Gemini_Generated_Image_ic1bzvic1bzvic1b.jpeg` (Pencil)
2. the chosen `pencil_skate_master.png`

The layout matters, because the game runs on top of it:
- **top 35%**: sky and far hills, with the end of the road at the horizon
  (the word to spell and the score go there)
- **bottom 65%**: one wide, straight road coming from the horizon to the
  bottom of the picture, getting wider towards the viewer (like a train
  track in a drawing). **No lines on the road**, the app draws moving lane
  lines on it. **Nothing on the road**
- grass on both sides of the road, mostly empty (the app adds trees and
  flowers that move past)

If the picture comes out square or wide, reply: *"Make it a tall vertical
9:16 phone picture, same scene."*

### 2a · Day → `bg_road_day.png`

```
The attached characters are ONLY a reference for the art style, outline and
colours. Do NOT draw them or any person, animal or vehicle in this picture.

Create a background scene for a children's game in the same art style as
the attached characters.

Scene: a sunny countryside seen from the middle of a straight road, looking
straight ahead. The road is smooth light-grey-blue with soft edges and a thin
creamy-white kerb on each side. It starts very narrow far away at the
horizon in the exact centre of the picture and becomes very wide at the
bottom, filling about three quarters of the bottom edge (one-point
perspective, perfectly straight and centred, no curves). On both sides of
the road: soft green grass going back to the horizon. Far away: gentle
rolling green hills, a few small round trees on the hills, and a tiny
cartoon town with colourful roofs right where the road ends. Sky: soft blue
with two fluffy white clouds, warm sunlight.

Keep the road completely empty: no lines, no markings, no cars, no objects
on it. Keep the grass beside the road mostly empty, close to the viewer.

Style: the same cartoon style as the attached characters: 2D illustration for
a children's learning app, clean vector look, smooth medium-thin outlines in a
darker warm shade of each colour (never pure black), soft gradient shading,
no texture, rounded friendly shapes. A little softer and lighter than the
characters so characters stand out in front of it. Gentle depth: things far
away are paler. Not realistic, not 3D. No text, no letters, no numbers, no
signs with writing, no watermark.

Composition: tall phone screen, 9:16 portrait. The horizon is at about one
third from the top.
```

### 2b · Sunset → `bg_road_sunset.png`

Stay in the **same chat** as 2a and attach the chosen `bg_road_day`:

```
Make exactly the same scene as the attached picture, with the same road,
the same horizon, the same hills and town in the same places, but at sunset:
a warm orange-pink sky, a low golden sun just above the town, longer soft
shadows, the town's windows glowing yellow, a few tiny yellow fireflies over
the grass. Keep the road empty with no lines. Same art style. No people,
animals or vehicles. No text. Tall phone screen, 9:16 portrait.
```

---

## 3. Things on the road (one sheet) → `props_road.png`

Attach the Pencil master and expression sheet.

```
Create a sheet of separate objects for a children's skateboard game, in the
same style as the attached Pencil mascot: 8 objects in 2 rows of 4, all
about the same size, evenly spaced with clear white space between them,
nothing overlapping. Every object is seen from the front and slightly above,
as if it is lying on a road in front of the viewer.

Top row, left to right:
1. a round brown mud puddle with a few small splashes, flat on the ground
2. a fallen wooden log lying across, with a cut end showing rings
3. a big round grey rock with a little green moss, friendly shape
4. a small square hay bale, golden yellow, with a string around it

Bottom row, left to right:
5. a small wooden jump ramp, seen from the front, sloping up away from the
   viewer, light wood with two red stripes
6. a shiny red-and-white traffic cone, short and round
7. a big yellow banana peel lying flat (funny, cartoon)
8. a finish line arch: two striped poles (red and white) with a wide blank
   cream banner between them at the top, no writing on the banner, and a
   chequered black-and-white line on the ground between the poles

Style: match the attached Pencil mascot exactly. Cute 2D cartoon
illustration, clean vector look, smooth medium-thin outlines in a darker
warm shade (never pure black), closed and unbroken, soft gradient shading
with one soft highlight, no texture. Not realistic, not 3D. No text, no
labels, no numbers, no watermark.

Composition: plain pure white background, nothing touching the edges.
16:9 image.
```

---

## 4. Things beside the road (one sheet) → `props_roadside.png`

Attach the Pencil master and expression sheet.

```
Create a sheet of separate objects that stand beside a country road in a
children's game, in the same style as the attached Pencil mascot: 10
objects in 2 rows of 5, all about the same size, evenly spaced with clear
white space between them, nothing overlapping. Each one stands upright,
seen from the front, with its bottom flat (it stands on the grass).

Top row, left to right:
1. a round leafy green tree with a short brown trunk
2. a tall dark-green pine tree
3. a round green bush with three small pink flowers
4. a patch of colourful flowers (red, yellow, purple) in grass
5. a tall sunflower

Bottom row, left to right:
6. a short white wooden fence section (three posts)
7. a cute old-style street lamp, dark green with a warm yellow light
8. a group of three red mushrooms with white spots
9. a wooden signpost with one blank arrow-shaped board, no writing
10. a small round tree with red apples

Style: match the attached Pencil mascot exactly. Cute 2D cartoon
illustration, clean vector look, smooth medium-thin outlines in a darker
warm shade (never pure black), closed and unbroken, soft gradient shading
with one soft highlight, no texture. Not realistic, not 3D. No text, no
labels, no numbers, no watermark.

Composition: plain pure white background, nothing touching the edges.
16:9 image.
```

---

## 5. Game cover (for the Games card) → `cover_spell_runner.png`

Attach the Pencil master and the chosen `pencil_skate_master`.

```
Using the attached Pencil mascot exactly as he is (same face, colours and
style), make one exciting, happy game cover: Pencil rides his sky-blue
skateboard towards the viewer down a straight country road, leaning into a
turn, arms out, big smile, speed lines behind him. Around him float three
big shiny soap bubbles (empty inside, no letters). The road goes back to a
small colourful town on the horizon; green grass, round trees and flowers
on both sides; soft blue sky with fluffy clouds.

Style: match the attached Pencil mascot exactly. Cute 2D cartoon
illustration for a children's learning app, clean vector look, smooth
medium-thin outlines in a darker warm shade (never pure black), soft warm
colours with gentle gradient shading, no texture. Not realistic, not 3D. No
text, no letters, no numbers, no watermark.

Composition: square 1:1 image, Pencil big in the front centre, fully
visible with his skateboard.
```

---

## Checklist: what to save in `design/games/spell-runner/`

| File | What |
|---|---|
| `pencil_skate_master.png` | Pencil on his skateboard, from behind |
| `pencil_skate_sheet.png` | 6 poses: ride, lean left, lean right, jump, wobble, cheer |
| `bg_road_day.png` | Straight road to the horizon, day (9:16) |
| `bg_road_sunset.png` | The same road at sunset (9:16) |
| `props_road.png` | Puddle, log, rock, hay bale, ramp, cone, banana peel, finish arch (8) |
| `props_roadside.png` | Trees, bush, flowers, sunflower, fence, lamp, mushrooms, signpost, apple tree (10) |
| `cover_spell_runner.png` | The Games card (1:1) |

7 pictures. Make Pencil first (he sets the look), then the backgrounds, the
things, and the cover last.
