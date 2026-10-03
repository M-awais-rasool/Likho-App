# Design

Reference material the app is built from. Nothing here ships in the app.

| folder | what |
|---|---|
| `prototype/` | The clickable HTML prototype (`Likho-Prototype.html`, open it in a browser) with screen and level captures in `screens/` and `levels/`. Screens, colours, copy and level data come from here. Older code comments call it `export/`. |
| `mascot/` | Pencil the mascot: the master art sheets (Gemini images) the app's mascot rig and accessories were traced from. Older code comments call it `mascot's/`. |

Where it is used:

* `app/tool/mascot_trace/` turns `mascot/` into the app's mascot assets (`app/assets/mascot/`).
* The first course (`backend/content/courses/english-handwriting/`) was imported once from the
  prototype's level data; since then its JSON is edited by hand.
* `app/assets/reference/` holds screen captures for the app's debug reference overlay.
