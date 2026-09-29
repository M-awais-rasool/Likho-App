# Pencil mascot tracing

How `assets/mascot/*.svg` and `assets/reference/*.png` were made from the
master art in `design/mascot/` (repo root) (Gemini_Generated_Image_*.jpeg). Pure Python + Pillow.

Artboard: 500 x 680 units = master image pixels, origin at master (454, 36).

Run from this folder, in order (about 6 minutes in total):

| step | script | what it does |
|---|---|---|
| 0 | `prepare.py` | JPEG -> PNG in `.work/` |
| 1 | `classify_master.py` | labels every master pixel with its nearest measured colour |
| 2 | `extract_master.py` | traces eraser+band, cone+graphite, legs, brows, cheeks, mouth |
| 3 | `fit_arms2.py` | fits the noodle-arm curves (quadratic Bézier + width) to the arm edges |
| 4 | `extract_master2.py` | body (straight-edged), rest hands, shadow, eye geometry -> `rig.json` |
| 5 | `fit_eyes.py` | grid-search of eye radii (numbers are copied into step 4 / `pencil_rig.dart`) |
| 6 | `trace_sheets.py` | mouths (mouth sheet) and hand poses (hand sheet), scaled to the master |
| 7 | `trace_accessories.py` | the 10 accessories (placements marked "placeholder" in `rig.json`) |
| 8 | `trace_fx.py` | the three "z" letters from the sleepy cell |
| 9 | `export_assets.py` | writes the SVG parts + aligned reference overlays |

`compose.py` renders the idle pose with rsvg-convert and diffs it with the master
(useful when editing parts). Rig numbers used by the app live in
`lib/mascot/rig/pencil_rig.dart`.
