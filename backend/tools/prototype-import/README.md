# Prototype import

One-time import of the level data in the design prototype
(`design/prototype/Likho-Prototype.html`, extracted into `prototype_data.js`) into
`content/courses/english-handwriting/`, one file per world and per level.

```bash
node backend/tools/prototype-import/import.js
cd backend && make content    # check the result
```

It **replaces** the course folder. Once levels have been edited by hand, edit the JSON in
`content/` instead of running this again. `picture_keys.txt` lists every picture the content uses
(for the illustrators).
