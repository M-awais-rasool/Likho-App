# Likho Games · "Monster Smash" levels · background layers (Gemini)

Monster Smash's levels now have a camera: it zooms on the towers, follows
the hero in the air, and the whole room walks sideways to the next room. So
the background is **four separate layers**, not one picture. Each layer
moves at its own speed (the far hills slowly, the ground with the game),
which gives the meadow its depth.

Letter Land's four layers are in the game. After saving new ones, run
`python3 tools/games/cut_smash_layers.py`: it cuts the white away, takes
the windmill off the far hills (the app draws it with turning sails),
writes `app/assets/games/smash/<world>_*.webp` and measures where each
picture's hill tops run (`ms_layer_lines.dart`). The pictures do not need
to join at their ends: the app draws every other one mirrored.

## How to use (every time)

1. Open a **new Gemini chat** for each world.
2. **Attach two pictures** (only for the style and colours):
   - `design/mascot/Gemini_Generated_Image_ic1bzvic1bzvic1b.jpeg` (Pencil)
   - `design/games/monster-defense/gloop_master.jpeg` (a monster)
3. Make the layers **in order** (sky, far, near, ground) in the **same
   chat**, so the colours match. Paste each prompt.
4. If a picture comes out square or tall, reply: *"Make it a very wide 3:1
   landscape picture, same scene."*
5. If the left and right edges do not match, reply: *"The left edge and the
   right edge must continue into each other seamlessly, so the picture can
   repeat side by side."*
6. Save each picture with its **file name** in
   `design/games/monster-smash/layers/` (jpeg is fine, the name is what
   matters).

Rules for every layer (they are in the prompts too):
- **very wide 3:1**, and **seamless left to right** (it repeats)
- no characters, no people, no animals, no monsters, no text
- the layers 2, 3 and 4 sit on a **plain pure white** background (the app
  cuts the white away), with clean unbroken outlines

---

## The style (part of every prompt below)

> Style: the same cartoon style as the attached characters: cute 2D
> illustration for a children's learning app, clean vector look, smooth
> medium-thin outlines in a darker warm shade of each colour (never pure
> black), soft gradient shading with one soft highlight, no texture,
> rounded friendly shapes. A little softer and lighter than the characters,
> so the characters stand out in front of it. Not realistic, not 3D. No
> text, no letters, no numbers, no watermark.

---

## Letter Land (the meadow), the first world

### 1 · Sky → `meadow_sky.png`

```
The attached characters are ONLY a reference for the art style and colours.
Do NOT draw them or any person, animal or monster.

Create a very wide 3:1 sky for a children's game, in the same art style as
the attached characters: a soft sunny sky, light blue at the top fading to
a warm pale cream near the bottom, a few small soft clouds far away, gentle
warm light. No sun (the app draws it), no ground, no hills, no birds.

The left edge and the right edge continue into each other seamlessly, so
the picture can repeat side by side.

Style: the same cartoon style as the attached characters, soft and light,
clean vector look, no texture. No text, no letters, no numbers, no
watermark. Very wide 3:1 landscape.
```

### 2 · Far hills → `meadow_far.png`

```
Same rules: the attached characters are ONLY a style reference, do NOT draw
any person, animal or monster.

Create a very wide 3:1 strip of FAR AWAY rolling hills for the same game:
pale, soft green hills seen from far away, a few tiny round trees on them
and one small windmill on a hilltop (no sails turning, just the windmill).
The hills fill the bottom half of the picture; the top half is plain pure
white (it will be cut away). The hills reach the very bottom edge.

Pale and soft, a little blue-green (far away), outlines in a slightly
darker shade of green, closed and unbroken along the top of the hills.

The left edge and the right edge continue into each other seamlessly.

Same cartoon style as the attached characters, softer and lighter, clean
vector look, no texture. No text, no watermark. Very wide 3:1 landscape.
```

### 3 · Near hills and trees → `meadow_near.png`

```
Same rules: the attached characters are ONLY a style reference, do NOT draw
any person, animal or monster.

Create a very wide 3:1 strip of NEAR rolling hills for the same game:
brighter green gentle hills, closer than the far ones, with 6 to 8 round,
friendly trees (round fluffy crowns, short brown trunks) and a few bushes
standing on them, spread out with space between them. The hills fill the
bottom 40% of the picture; everything above is plain pure white (it will be
cut away). The hills reach the very bottom edge.

Clear outlines in a darker green, closed and unbroken around the hills and
every tree. Soft light band on the top-left of each round shape.

The left edge and the right edge continue into each other seamlessly.

Same cartoon style as the attached characters, clean vector look, no
texture. No text, no watermark. Very wide 3:1 landscape.
```

### 4 · The ground → `meadow_ground.png`

```
Same rules: the attached characters are ONLY a style reference, do NOT draw
any person, animal or monster.

Create a very wide 3:1 strip of the GROUND the game stands on, seen from the
side: a band of bright green grass with a wavy top edge, little grass tufts
and a few small flowers (pink, yellow, white) along the top, and under it
soft brown earth with a few smooth pebbles. The grass top edge is at 30%
from the top of the picture and runs perfectly level across the whole
picture (only small wavy bumps); above it is plain pure white (it will be
cut away). Grass and earth reach the left, right and bottom edges.

Outlines in a darker green along the grass top, closed and unbroken.

The left edge and the right edge continue into each other seamlessly.

Same cartoon style as the attached characters, clean vector look, no
texture. No text, no watermark. Very wide 3:1 landscape.
```

---

## Checklist: what to save in `design/games/monster-smash/layers/`

| File | What |
|---|---|
| `meadow_sky.png` | Sky, 3:1, seamless |
| `meadow_far.png` | Far hills + windmill on white, 3:1, seamless |
| `meadow_near.png` | Near hills + trees on white, 3:1, seamless |
| `meadow_ground.png` | Grass + earth on white, 3:1, seamless |

4 pictures for the first world. The sun, the drifting clouds, the turning
windmill sails, swaying grass, butterflies and birds stay drawn by the app
on top of them, so they keep moving. The next worlds (Alphabet Jungle,
Small Letter Beach, Letter Forest …) use the same four prompts with their
own scene; send them when Letter Land looks right in the game.
