# Monster Smash — Crystal Sky gameplay

The gameplay now shares the level map's Crystal Sky world: lavender skies, floating islands, warm gold surfaces and turquoise details. The three Stationery Squad heroes and four monsters use new transparent atlases. Body pivots and per-character scales keep poses aligned during aiming, flight, powers and impacts. Native canvas blocks and the launcher follow the existing physics shapes and anchors.

## Saved artwork

Generated with the built-in imagegen tool, with transparent backgrounds. The original PNG alpha is preserved.

- `app/assets/games/smash/crystal_rubby.png` — 1536×1024, six Rubby poses.
- `app/assets/games/smash/crystal_inky.png` — 1536×1024, six Inky poses.
- `app/assets/games/smash/crystal_crayo.png` — 1536×1024, six Crayo poses.
- `app/assets/games/smash/crystal_monsters.png` — 1448×1086, four monsters with three expressions each.
- Reused `app/assets/games/smash/map_crystal_sky.webp` from the Crystal Sky level-map artwork.

Hero sheets: three columns, two rows; idle, aim, flight, power, bonked, happy. Monster sheet: four columns (Gloop, Fuzz, Bonk, Boo), three rows (idle, surprised, happy). Measured alpha bounds and body pivots live in `ms_crystal_art.dart`. No generated text is used in the interface.

## UI and rendering

- Cream and lilac panels, gold selected hero card, named hero portraits, a clear letter/audio prompt and a labelled Smash meter.
- Matching responsive start and pause cards.
- Fewer queued characters on the launch island, with spacing based on the new art.
- Flight art follows the trajectory; Crayo's horizontal flight/power pose points along his movement.
- Existing engine rules, level definitions, collision radii, trajectory calculation, scoring and progression are unchanged.
- The sprite loader decodes only the six active assets, avoiding retention of the legacy image set.

## Verification

Run from `app/`:

```sh
flutter analyze --no-pub lib/screens/games/monster_smash tool/smash_play_preview/render_smash.dart
flutter test --no-pub test/monster_smash_test.dart tool/smash_play_preview/render_smash.dart
```

The preview harness captures the real Flutter screen on a 932×430 phone, a 740×360 compact phone with 1.3× text, and an 1180×820 tablet. Each includes start, ready, aim, flight, power and pause states with safe-area insets. It also renders every hero pose and monster expression through the production renderers in `character-poses.png`, and verifies all active assets decode. Screenshots are written to `app/build/smash-play-preview/`. Tests cover dragging to launch, powers, pause/resume, the level map, completing a level, progression and a complete three-room game. Final verification: all 22 tests passed; the scoped analyzer reported no issues. Device GPU/FPS performance has not been profiled.

## Exact imagegen prompts

### Rubby

```text
Use case: stylized-concept. Production transparent character sprite atlas for a beautiful children's slingshot mobile game, Monster Smash.
REFERENCE: attached character is Rubby, preserve its exact identity: round coral pink eraser, curled tuft, tiny rounded arms and feet, turquoise lower sleeve with cream stripe, golden aviator goggles resting above eyes, blue scarf. Premium softly shaded rounded 3D game art, cheerful expressive large navy eyes, crisp silhouette, warm light from upper left. No black outlines.
Create SIX Rubby poses in an EXACT EVEN 3 COLUMN by 2 ROW grid, landscape 1536x1024, each cell 512x512. Same body size and colors in every cell, all body centres at centre of each cell, each full figure contained inside cell with 12% transparent padding. All characters look toward screen RIGHT in a three-quarter SIDE view, with both eyes visible so we can read the face. The hero launches left to right.
Top row: 1 upright waiting, relaxed excited smile and both feet down. 2 aiming, leaning back a little, focused eyebrows, arms tucked, determined but cute. 3 flying horizontally to the RIGHT, body only gently tilted 15 degrees clockwise, arms trailing left, open joyful mouth.
Bottom row: 4 power activated, wide springy squash in body, fists out, happy determined grin. 5 just bumped, wobbly dazed expression with uneven eyes, funny and unharmed, same intact body. 6 victory cheer upright, both arms lifted, happy open smile.
Crisp game sprites, consistent proportions across frames, do not stretch scarf across cells. No ground shadows, scenery, glows, text, motion streaks, grid lines, labels or extra characters. Genuine transparent background.
```

### Inky

```text
Use case: stylized-concept. Transparent production sprite atlas for Monster Smash. Image 1 is identity reference: use ONLY the blue ink-drop character INKY in its middle. Image 2 is the polished rounded 3D material and lighting style reference. Do not copy Rubby's costume onto Inky.
INKY: compact cobalt blue ink-drop body with one curled droplet tuft, two small rounded blue feet, tiny arms, expressive navy eyes with white catchlights, playful eyebrows, a confident mischievous smile. Rich blue body with turquoise highlights, glossy soft rubber/jelly shading. No clothing, no goggles, no scarf, no labels.
Create EXACTLY SIX poses in a perfectly even 3 columns x 2 rows grid, landscape 1536x1024. Each cell512x512, same body proportions and scale, full character inside each cell with 12% transparent margin, body centred in cell. All look toward screen RIGHT in three-quarter SIDE view showing both eyes.
Top row: 1 upright idle happy; 2 aiming, focused friendly brows, arms tucked; 3 airborne flying RIGHT with body gently tilted and arms trailing, joyful open mouth.
Bottom row: 4 power, surprised excited expression with arms stretched out and body slightly wider, ONLY ONE character (game creates copies); 5 bonked, dizzy funny uneven eyes, unharmed; 6 victory, both arms up laughing.
Beautiful high-end 3D mobile game render, warm upper-left illumination, smooth glossy materials, expressive crisp silhouette. No outlines, motion streaks, glow, scene, ground shadow, text, grid, letters, extra figures. Actual transparent background.
```

### Crayo

```text
Use case: stylized-concept. Production transparent character sprite atlas for children's slingshot game Monster Smash.
Image 1 identity reference: ONLY the orange crayon character CRAYO at right. Preserve orange wax crayon with pointed tip at top, coral orange wrapper bands and pale peach middle label, friendly expressive navy eyes, little orange arms and feet. Image 2 style reference: same gorgeous polished rounded 3D mobile game material, warm upper-left lighting, clear readable eyes, glossy highlights. No goggles or scarf on Crayo.
EXACTLY SIX poses in perfectly even 3 columns by 2 rows grid, landscape 1536x1024, cell512x512. Same body size every pose, body centres in cell centres, at least10% transparent margin, entire character contained in each cell. Standing poses are a SHORT CHUNKY crayon, height about1.8 times body width, not a tall thin pencil. Face looks screen RIGHT in three-quarter view and both eyes visible.
Top row: 1 upright idle smile; 2 upright ready aiming with focused brows, tiny arms tucked; 3 flying horizontally to the RIGHT with the pointed crayon tip pointing directly right, face on broad side visible to viewer, happy open mouth, feet trailing LEFT.
Bottom row: 4 power dash horizontally RIGHT, point right, focused determined grin, body intact, no trails; 5 bonked upright tilted a little, dazed funny expression, unharmed; 6 upright victory both arms up joyful.
Premium toy-like 3D render, soft smooth orange wax, charming facial expressions. No scenery, no ground plane, NO cast shadows, NO glow or background colors, no text, motion lines, gridlines, labels or extra figures. True transparent background.
```

### Monsters

```text
Use case: stylized-concept. Production MONSTER sprite atlas for a children's slingshot game, premium rounded 3D toy-like render with warm light, clean vibrant materials and NO outlines. Preserve the four attached monsters' identities and colors while making them beautiful dimensional 3D.
EXACT EVEN GRID: 4 columns by 3 rows, landscape 2048x1536, each cell512x512. Each entire monster fits in its cell with generous clear padding, bottoms of feet at 88% cell height, total standing heights approximately75% cell height. Isolated on true TRANSPARENT background with no shadows or effects.
The FOUR COLUMNS, left to right:
1 Gloop: lime green soft jelly cyclops, ONE big glossy eye, curled antenna with round tip, tiny arms, stubby legs, friendly single little tooth.
2 Fuzz: round lavender fluffy monster, TWO eyes, two tiny pale pink horns, two small cute teeth, short arms and rounded purple feet.
3 Bonk: chunky rounded slate blue stone golem, two eyes, moss-green tuft on top, little stone legs and arms, friendly grumpy brow. Cute not threatening.
4 Boo: soft pearl-white blue-tinted ghost, TWO eyes, tiny wing-like arms, rounded scalloped lower hem, cheerful mouth and rosy cheeks.
TOP ROW: all four neutral friendly idle, front/three-quarter view, facing slightly LEFT towards incoming player.
MIDDLE ROW: exact same four creatures surprised with wide eyes and O mouth, arms out, still standing, humorous not scary.
BOTTOM ROW: exact same four creatures happy/laughing, arms raised cheering, same body proportions.
Every character must be fully visible and separate in its cell. Consistent lighting and scale. No lettering, gridlines, motion lines, ground, glow, backdrop, UI, watermark or extra figures. Actual alpha transparency.
```

