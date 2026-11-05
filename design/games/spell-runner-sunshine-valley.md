# Spell Runner · Sunshine Valley

Created 6 November 2026 with the built-in `image_gen` tool. All selected assets are copied into `app/assets/games/runner/`; the game does not depend on the generation cache. Original art is retained.

## Integration

- `sr_atlas.dart` reads transparent pose/prop atlases directly, using measured source rectangles and rear-wheel anchors. Standing poses share a 420 px reference height. Slide is a physically foreshortened pose, not a vertically compressed standing sprite.
- `sr_scene.dart` projects the track from the measured vanishing point (0.5, 0.412), matching the generated road. Zone lighting and the existing rules remain in place.
- `sr_painter.dart` draws moving paving, limestone kerbs, collectibles and atlas props with the same projection as the rider. High-bar clearance fits the new sliding silhouette.
- `sr_ui.dart` supplies the start screen and matching pause/result cards. Six-letter cards scale to fit narrow screens, including letter-flight destinations.
- `tool/spell_runner_preview/render_runner.dart` captures the actual Flutter screen at 390×844, 320×640 (1.3× text) and 768×1024. Output: `app/build/spell-runner-preview/`.

## Assets and exact prompts

### Start background

Saved asset: `app/assets/games/runner/valley_day.png`

```text
Use case: stylized-concept. Asset type: production portrait background for a children's endless skateboard runner called Spell Runner. Create an exceptionally beautiful premium 2.5D mobile game environment, rich polished rounded toy-like forms, soft ambient occlusion, sunlit gradients, charming saturated turquoise, mint green, buttery yellow and peach palette. Portrait 1080 x 1920 composition.
A joyful sunny valley park with distant pastel little town and cream arched viaduct, layered turquoise mountains, sculpted fluffy clouds, a tiny hot air balloon, warm sunshine. A STRAIGHT empty wide pale mint paved boulevard runs from the vanishing point at EXACTLY 50% image width and 40% image height down to both bottom corners. Symmetrical single-point perspective, no curve or bend. No lane markings: these will be rendered by the game. On either side grassy rolling gardens with round lush trees, blossoms and small stylized houses concentrated around the horizon and outside the boulevard. Foreground roadway must be entirely empty and quiet, no characters, no obstacles, no collectibles. The upper 25% is mostly clear cyan sky to leave room for the game UI. Make depth clear with warm sunlight from upper left and airy atmosphere at the horizon. Beautiful crafted game art, clean smooth render, detailed but readable, no black outlines, no grain, no photorealism, no text, no letters, no logos or watermark. This is the actual game background asset, NOT a phone mockup or screenshot.
```

### Mascot hero

Saved asset: `app/assets/games/runner/pencil_hero.png`

```text
Use case: stylized-concept. Production game character cutout for Spell Runner. Use the attached Pencil mascot ONLY as an identity reference: yellow chunky pencil body, pink eraser, silver metal collar, warm wooden sharpened cone and graphite tip at bottom, short yellow arms and legs. Create a beautiful premium 3D animated mobile game version of this same friendly pencil, smooth rounded yellow lacquer, charming large expressive brown eyes with highlights, joyful open smile, peach cheeks, soft pink eraser. Dynamic 3/4 FRONT view doing a happy skateboard ollie: bent knees, left arm stretched for balance, right hand raised, body leaning slightly, BOTH feet attached to the turquoise skateboard with white center stripe and four orange wheels, board pointing diagonally from bottom left to upper right. Believable coherent anatomy, no detached limbs, no duplicated feet. Entire character and board visible with generous transparent padding. Gorgeous warm studio lighting and soft ambient occlusion, tactile glossy materials, friendly rounded silhouette, no dark cartoon outlines, high-end stylized 3D render, child-friendly, energetic confident expression. NO backdrop, NO ground plane, NO text, NO motion streaks, NO extra objects. Actual transparent background.
```

### Six rider poses

Saved asset: `app/assets/games/runner/pencil_moves.png`

```text
Use case: stylized-concept. Asset type: production animation sprite atlas for a children's 3-lane skateboard runner.
Use attached mascot image as exact character identity and 3D material reference. Yellow pencil, pink eraser, silver collar, wooden cone, graphite tip, yellow short limbs, turquoise skateboard with white center stripe and orange wheels. Beautiful polished rounded 3D mobile game render with bright warm soft illumination and consistent proportions.
Create SIX separate sprites in an EXACT EVEN 3 COLUMN by 2 ROW grid on transparent background, landscape 1536x1024. Each cell 512x512. Each sprite centered horizontally in its own cell. Skateboard rear wheels at 90% of each cell height. Character standing height at most 78% of cell height. Clear padding between cells. No labels, gridlines or text. No cast ground shadows. No sparkles or streaks. All sprites must be fully inside their individual cells.
CAMERA: all six are viewed from DIRECTLY BEHIND, a little above, riding AWAY from viewer towards the top of the image. Board points into distance, we see its narrow rounded tail and two back wheels, NOT the long sideways skateboard. NO FACE on any rear-view sprite.
TOP ROW:
1. cruise, gently bent knees, both feet planted on board, arms out low for balance.
2. turn LEFT, knees bent, whole body and board bank left naturally, left hand low right arm up, all parts attached.
3. turn RIGHT, mirrored bank pose, whole body leaning right, right hand low left arm up.
BOTTOM ROW:
4. jump, knees tucked, arms extended upward, board held firmly under both feet; entire figure including wheels still anchored at 90% cell height because game controls airborne translation.
5. slide, deep crouch low on board, pencil body tilts forwards into the distance to nearly horizontal, pink eraser facing forward, foreshortened body, bent knees tucked alongside, arms low; top of eraser no higher than 50% cell height and wheels at 90%.
6. celebration, body upright slightly twisting, one arm raised with fist, both feet stay on board.
Maintain EXACT same character body dimensions/materials/board size across all six sprites except natural foreshortening. No clothing or accessories. Transparent background.
```

### Gameplay background

Saved asset: `app/assets/games/runner/valley_track.png`

```text
Use case: style-transfer. Production portrait endless runner background. Image 1 is the EXACT COMPOSITION and perspective to preserve. Image 2 is the desired polished 3D ART STYLE, palette and garden/town details.
Repaint IMAGE 1 in IMAGE 2's gorgeous premium mobile game 3D style. Crucially KEEP THE EXACT ROAD GEOMETRY of image 1: very distant road vanishing point at x=50%, y=38% of image. STRAIGHT road edges go from this point directly to bottom left and bottom right corners. Road triangle is narrow through the middle of the image and widens only at the bottom. This road silhouette, horizon height, and large amount of grass visible at left and right must be EXACTLY preserved from image 1. Do not make road wider or bring horizon down.
Road surface is smooth dusty turquoise blue, entirely empty with NO baked-in paving pattern, seams, stripes, lane lines, shadows of trees or obstacles: the live game draws moving details.
Surround it with lush rounded green grassy banks, a few rounded flowering trees at the far sides, tiny sunlit pastel village roofs, a tiny cream viaduct at the horizon, layered teal mountains. Keep all trees behind the middle-distance road edges, and most foreground grass plain so game can draw moving scenery. Warm light from upper left, rich soft 3D shading and ambient occlusion, smooth chunky toy-like silhouettes, luminous blue sky fading to cream near the horizon, few beautifully sculpted clouds and tiny coral balloon. Upper 22% mostly clear sky for interface. Cheerful cinematic beautiful game world. No outlines, no grain, no text, no characters, no collectibles, no UI. Portrait 1080x1920.
```

### Scenery and obstacles

Saved asset: `app/assets/games/runner/valley_props.png`

```text
Use case: stylized-concept. Production SPRITE ATLAS for a beautiful 3D children's skateboard runner. Match the attached environment and Pencil character's polished rounded 3D game style, warm sunshine, bright turquoise green peach coral yellow palette, glossy toy-like materials, no black outlines.
EXACTLY 9 separate isolated objects in an evenly spaced 3 COLUMN by 3 ROW square grid, each centered in its own square cell, with at least 10% padding on every side. Entire objects visible, no overlap. TRUE TRANSPARENT BACKGROUND, no ground, no ground shadows, no glow, no text, no grid lines.
Top row:
1. a beautiful rounded green topiary tree with chunky short wooden trunk, 3 fluffy sculpted crowns, a few red apples.
2. a beautiful rounded flowering tree with deep mint green sculpted fluffy foliage, peach pink blossoms, chunky short wooden trunk.
3. a small rounded teal planter box with bushy green foliage and pink yellow daisy flowers.
Middle row:
4. a friendly bright coral orange traffic cone with two cream stripes, square rounded foot, glossy rounded shape.
5. a coral and cream striped hurdle bar across two turquoise posts, viewed directly from front, OPEN TRANSPARENT GAP below bar occupying bottom 55% height, two posts on either side, jump game obstacle.
6. a rounded honey brown fallen wood log lying horizontally, circular end rings visible on right, low obstacle seen from front and slightly above.
Bottom row:
7. a chunky small wooden cart filled with rounded golden hay bales, two big turquoise wheels, seen front on, blocks a whole lane.
8. a low turquoise skateboard launch ramp, peach side trim, seen from front slightly above, slope going up AWAY from viewer.
9. a stylized conical pine tree with rounded layered emerald foliage and small warm wooden trunk.
Every object lit from upper left with beautiful ambient occlusion and soft highlights. All viewed front-on slightly from above, same camera angle. Objects all centered in their individual cells. No mascot.
```

### Game library cover

Saved asset: `app/assets/games/runner/valley_cover.png`

```text
Use case: stylized-concept. Game cover artwork, landscape 3:2 composition. Combine the attached joyful yellow Pencil skateboard mascot (identity reference image 1: preserve yellow pencil body, pink eraser, metal band, big friendly eyes, graphite tip, yellow limbs, turquoise skateboard with white stripe and orange wheels) with the beautiful sunshine valley park environment (style and setting reference image 2). Premium polished 3D mobile game illustration. Pencil in a dynamic airborne skateboard ollie occupies the central 60% of the frame, happily smiling towards the viewer, all limbs and the complete board visible, no cropping. Bright turquoise sky, pastel village rooftops and rounded flowering trees receding along a mint path behind him, a few golden star collectibles floating over the path on each side. Warm sunshine, rich soft 3D shading, saturated but harmonious colors, energetic charming image for children. The yellow character must pop against the turquoise background. No title, no words, no letters, no logo, no border, no UI. Exact landscape 3:2.
```

