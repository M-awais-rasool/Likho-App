# Likho Games · "Letter Slice" · image prompts (Gemini)

Fruit Ninja style, played upright (portrait). Fruits with happy faces fly
up from the bottom; each wears a letter (the app writes it). Pencil asks
"Slice B!" and the child swipes through the fruits with that letter: the
fruit splits in two and its juice splashes. The game runs today on
stand-in pictures (`tools/games/make_slice_placeholders.py`); these
prompts make the real ones.

The app draws these itself, so **do not** ask Gemini for them: the
letters, the blade's white trail, juice drops and splats, scores, combo
words and buttons.

## How to use

Same as Monster Smash: a new Gemini chat per picture, attach Pencil's
master and expression sheet (`design/mascot/Gemini_Generated_Image_ic1bzvic1bzvic1b.jpeg`,
`design/mascot/Gemini_Generated_Image_y5imh7y5imh7y5im.jpeg`), paste the
prompt, save the picture in `design/games/letter-slice/` with the file
name given.

Rules for every picture: outlines closed and unbroken, nothing touching
the edge, clear white space between things, no text, letters or numbers.

## The style (part of every prompt)

> Style: match the attached Pencil mascot exactly. Cute 2D cartoon
> illustration for a children's learning app, clean vector look. Smooth,
> medium-thin outlines in a darker warm shade of each colour (never pure
> black), closed and unbroken. Soft warm colours with gentle gradient shading
> and one soft highlight, no texture. Rounded, friendly shapes. Not
> realistic, not 3D, not anime. No text, no letters, no numbers, no watermark.

## 1. The fruits, whole → `fruits_whole.png`

```
Create a sheet of 8 separate cute fruits for a children's fruit-slicing
game, in the same style as the attached Pencil mascot: 2 rows of 4, all
about the same size (round fruits the same width), evenly spaced with
clear white space between them, nothing overlapping.

Top row: a red apple with a little leaf, an orange with a leaf, a round
green watermelon with dark stripes, a yellow lemon.
Bottom row: a purple plum with a leaf, a brown fuzzy kiwi, a pink peach
with a leaf, a round blue ice berry with frosty sparkles.

Every fruit has a happy little face in the middle of its front: two
small round eyes with a white shine, a small smile, pink cheeks. The
middle of the belly stays plain (a letter goes there later).

[the style]

Composition: plain pure white background, nothing touching the edges.
16:9 image.
```

## 2. The fruits, cut in half → `fruits_cut.png`

```
Using the attached fruit sheet (same fruits, same order, same size and
style), draw each fruit CUT IN HALF, seen straight from the front: we
see the juicy inside of the cut face (apple: cream flesh and two seeds;
orange and lemon: juicy segments; watermelon: red flesh, white rim, black
seeds; plum and peach: yellow flesh and a stone; kiwi: green flesh,
black seeds in a ring; ice berry: icy blue inside). Round, the same size
as the whole fruit, 2 rows of 4 in the same order. No faces.

[the style]

Composition: plain pure white background, nothing touching the edges.
16:9 image.
```

## 3. Specials → `specials.png`

```
Create 3 separate special fruits for a children's fruit-slicing game, in
the same style as the attached Pencil mascot, in one row with clear
white space between them:
1. a golden star fruit shaped like a five-pointed star, glowing softly,
   with a happy face
2. a curved yellow banana with a happy face
3. the same golden star fruit cut in half, its juicy inside

[the style]

Composition: plain pure white background, nothing touching the edges.
16:9 image.
```

## 4. Pencil the fruit ninja → `pencil_ninja_sheet.png`

```
Using the attached Pencil mascot (keep him exactly the same), make a pose
sheet: 6 poses in 2 rows of 3, all the same size, evenly spaced, wearing
a red ninja headband tied round his eraser with the ends flying.
Top row: 1. ready, holding a small wooden play sword (no blade, a toy)
2. swinging the toy sword in a swish, happy 3. cheering, both arms up.
Bottom row: 4. oops, hands on his cheeks 5. pointing up, excited
6. a thumbs up with a wink.

[the style]

Composition: plain pure white background, a soft grey oval shadow under
each pose, nothing touching the edges. 16:9 image.
```

## 5. The board → `bg_board.png`

```
A background for a children's fruit-slicing game: a warm wooden kitchen
board seen straight from above, wide planks running up and down, soft
wood grain, slightly darker towards the edges. Nothing on it. Same
cartoon style as the attached Pencil mascot, softer and lighter than
him. No text. Tall 9:16 portrait picture.
```

## 6. Cover → `cover_letter_slice.png`

```
Using the attached Pencil mascot (keep him exactly the same) with a red
ninja headband, make a happy game cover: Pencil leaping and swinging a
toy wooden sword through the air, a cute apple and an orange with happy
faces flying and splitting in half with juice splashing, a watermelon
flying too, on a warm wooden board background.

[the style]

Composition: square 1:1 image, everyone fully visible.
```

## Checklist: what to save in `design/games/letter-slice/`

| File | What |
|---|---|
| `fruits_whole.png` | 8 fruits with faces (apple, orange, watermelon, lemon, plum, kiwi, peach, ice berry) |
| `fruits_cut.png` | the same 8 cut in half |
| `specials.png` | golden star fruit, banana, the star cut |
| `pencil_ninja_sheet.png` | 6 ninja poses |
| `bg_board.png` | the wooden board, 9:16 |
| `cover_letter_slice.png` | the Games card (1:1) |
