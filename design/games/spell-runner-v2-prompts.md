# Likho Games · "Spell Runner" Phase 2 · image prompts (Gemini)

The new Pencil rider and the new things on the road. Phase 2 adds a **slide**:
the child swipes down and Pencil ducks flat on his board to pass **under** a
high bar. Low things are still jumped over. Some things block a whole lane, so
he has to change lane.

Made the same way as before (`spell-runner-prompts.md`): plain white
background, one sheet per chat, Pencil's style.

The app draws these itself, so **do not** ask Gemini for them: the letter
bubbles, the stars, lane lines, kerbs, speed lines, dust, trails, the word at
the top, score and buttons.

## How to use (every time)

1. Open a **new Gemini chat** for each sheet.
2. **Attach three pictures** as the style reference:
   - `design/mascot/Gemini_Generated_Image_ic1bzvic1bzvic1b.jpeg` (Pencil, master pose)
   - `design/mascot/Gemini_Generated_Image_y5imh7y5imh7y5im.jpeg` (Pencil, expression sheet)
   - `design/games/spell-runner/pencil_skate_master.jpeg` (Pencil on his board, from behind)
3. Paste the prompt. If the style drifts, say: *"Match the attached Pencil
   style exactly: same outline thickness, same soft shading, same colours."*
4. If the board turns sideways, say: *"The skateboard must point straight
   AWAY from us: we only see its short back end and the two back wheels side
   by side, never its long side."*
5. Save each picture with the **file name** given, in
   `design/games/spell-runner/v2/` (jpeg is fine, the name is what matters).

Rules for every picture (they are in the prompts too):
- outlines closed and unbroken (the app cuts the white away from the outside)
- nothing touching the picture's edge, clear white space between poses
- no text, letters, numbers or watermark
- no motion lines, no blur, no speed streaks

---

## The style (part of every prompt below)

> Style: match the attached Pencil mascot exactly. Cute 2D cartoon
> illustration for a children's learning app, clean vector look, premium
> mobile game quality. Smooth, medium-thin outlines in a darker warm shade of
> each colour (never pure black), closed and unbroken. Soft warm colours with
> gentle gradient shading and one soft highlight, no texture. Rounded,
> friendly shapes. Not realistic, not 3D, not anime. No text, no letters, no
> numbers, no watermark.

---

## 1. The rider, 8 moves → `rider_sheet.jpeg`

```
Using the attached Pencil on his skateboard seen from behind (keep him and
the board exactly the same: yellow pencil body, pink eraser with the grey
band on top, wooden cone and dark tip, short yellow arms and legs, the
sky-blue board with the white stripe and four orange wheels), make a pose
sheet: 8 poses in 2 rows of 4, all the same size, all seen FROM BEHIND,
evenly spaced with clear white space between them.

IMPORTANT: in every pose he rides AWAY from the viewer, down a road into the
distance. The skateboard points straight away from us: we see only its short
back end (the tail, foreshortened) and the two back wheels side by side under
it, never the long side of the board. The same size of Pencil in every pose.

Top row, left to right:
1. push: riding, his left foot on the board, his right foot down behind,
   kicking the road to push, arms a little out
2. ride: both feet on the board, knees a little bent, arms out for balance,
   relaxed and happy
3. carve left: the board and his whole body leaning into a turn to the
   left, the board's left edge down, knees bent, left arm low, right arm high
4. carve right: the same, leaning into a turn to the right

Bottom row, left to right:
5. crouch: about to jump, knees bent deep, body low, arms back, ready to
   spring up
6. jump: high in the air, the board stuck under his feet, knees pulled up,
   both arms up in joy, a gap below the wheels
7. slide: ducking as low as he can, lying almost flat forward along the
   board, arms tucked in, his eraser top pointing ahead, the board still
   pointing away from us (he has to pass under a low bar)
8. trick: in the air, one hand grabbing the side of the board, the board
   tilted a little, body twisted, very cool

Style: match the attached Pencil mascot exactly, same outlines and soft
shading. Plain pure white background, a soft light-grey oval shadow under
each pose (far below him in the jump and trick poses), nothing touching the
edges, nothing touching each other. No text, no labels, no numbers, no
motion lines. 16:9 image.
```

## 2. Bumps and cheers, 3 moves → `rider_sheet_b.jpeg`

Same chat as sheet 1. Attach the sheet you chose too.

```
Using the attached Pencil rider sheet (keep him and the board exactly the
same, seen FROM BEHIND, the board pointing straight away from us, the same
size), make 3 more poses in one row, evenly spaced:

1. stumble: he bumped into something: the board tipping to one side,
   Pencil off balance, arms waving, one leg up (funny, not hurt)
2. land: just landed from a jump, knees bent deep, body squashed low, arms
   out wide for balance
3. cheer: still riding, turning his head back over his shoulder so we see
   his happy face from the side, one arm up in a fist of joy

Style: match the attached Pencil mascot exactly, same outlines and soft
shading. Plain pure white background, a soft light-grey oval shadow under
each pose, nothing touching the edges. No text, no labels, no numbers, no
motion lines. 16:9 image.
```

---

## 3. New things on the road → `props_road_v2.jpeg`

A new chat. Attach only the two Pencil pictures (not the rider).

```
Create a sheet of 6 things that stand on a country road in a children's
skateboard game, in the same style as the attached Pencil mascot. Each
thing is seen from the FRONT, straight on, a little from above, as a rider
coming down the road sees it. Each one is as wide as one lane of a road.
6 things in 2 rows of 3, the same scale, evenly spaced with clear white
space between them.

Top row (HIGH things: the rider ducks under them, so there is an open gap
under each, as tall as half the thing):
1. barrier: a wooden bar with red and white stripes, held up on two short
   wooden posts, an open gap under the bar
2. banner: a bright cloth banner with bunting flags hanging from a rope
   between two thin poles, a big open gap under it (no words on it)
3. branch: a thick low tree branch with green leaves and two red apples,
   reaching across between two short tree stumps, an open gap under it

Bottom row:
4. cart: a big wooden farm cart full of hay, seen from the front, two big
   wheels, it fills the lane from the road to its top (the rider must go
   around it)
5. bench: a low wooden park bench, seen from the front (the rider jumps
   over it)
6. flower box: a long low wooden box of red and yellow flowers (the rider
   jumps over it)

Style: match the attached Pencil mascot exactly. Cute 2D cartoon
illustration for a children's learning app, clean vector look. Smooth,
medium-thin outlines in a darker warm shade of each colour (never pure
black), closed and unbroken. Soft warm colours with gentle gradient shading
and one soft highlight, no texture. Rounded, friendly shapes. Not realistic,
not 3D, not anime. No text, no letters, no numbers, no watermark.

Composition: plain pure white background, a soft light-grey shadow under
each thing, nothing touching the edges or each other. 16:9 image.
```

---

## 4. Gloop chasing Pencil, from behind → `gloop_chase.jpeg`

Phase 3: when Pencil bumps into something, Gloop (the green jelly monster
from Monster Defense) comes bouncing after him from behind, and falls back
when he rides well. The camera is behind both of them, so we see Gloop
**from behind** too. A new chat. Attach the two Pencil pictures and
`design/games/monster-defense/gloop_master.jpeg`.

```
Using the attached Gloop monster (keep it exactly the same: the green jelly
body, its antenna, its colours, the outline style), draw it FROM BEHIND,
chasing someone down a road away from the viewer: we see its round green
back, the back of its antenna, its little arms. No face (it looks away from
us). 3 poses in one row, the same size, evenly spaced:

1. bounce up: in the air in a big hop forward, body stretched tall, arms up
2. land: squashed wide as it lands, arms out
3. reach: leaning forward, both arms stretched out ahead as if to grab
   something in front of it (funny, not scary)

Style: match the attached Pencil mascot exactly. Cute 2D cartoon
illustration for a children's learning app, clean vector look. Smooth,
medium-thin outlines in a darker warm shade of each colour (never pure
black), closed and unbroken. Soft warm colours with gentle gradient shading
and one soft highlight, no texture. Not realistic, not 3D, not anime. No
text, no letters, no numbers, no watermark, no motion lines.

Composition: plain pure white background, a soft light-grey oval shadow
under each pose, nothing touching the edges or each other. 16:9 image.
```

---

## Checklist: what to save in `design/games/spell-runner/v2/`

- [ ] `rider_sheet` (8 poses: push, ride, carve left, carve right, crouch, jump, slide, trick)
- [ ] `rider_sheet_b` (3 poses: stumble, land, cheer)
- [ ] `props_road_v2` (barrier, banner, branch, cart, bench, flower box)
- [ ] `gloop_chase` (3 poses from behind: bounce up, land, reach)

Until these come, the game already has the slide and the high bar, drawn by
the app as stand-ins; the pictures replace them.
