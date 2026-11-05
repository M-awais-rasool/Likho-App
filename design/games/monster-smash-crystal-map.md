# Crystal Sky — Monster Smash level map

The landscape level-selection screen uses a floating crystal-island theme. Gameplay scenery, level data and saved progress keep their existing behavior. Map illustration and guide are bundled separately from gameplay art.

## Production assets

- `app/assets/games/smash/map_crystal_sky.webp`: background, 1536 × 1024, 100 KB.
- `app/assets/games/smash/map_rubby_aviator.webp`: transparent guide, 1254 × 1254, 182 KB; alpha preserved.

Generated with the built-in **image_gen** tool, then encoded as WebP for the app. The road, islands, medals, labels and controls are Flutter widgets and canvas drawing; no text is baked into the artwork.

## Final prompts

### Background

Use case: stylized-concept. Asset type: production background illustration for a children's landscape mobile game level-selection map, no UI baked in. Primary request: Create an exceptionally beautiful polished whimsical CRYSTAL SKY adventure world, entirely different from a woodland. Wide panoramic 1536x1024 composition. Dreamy lavender-to-periwinkle sky with a luminous peach sun near upper right, sweeping silky ivory pink clouds along the bottom, a few tiny glints. Small floating islands made from faceted lavender stone and turquoise crystal clusters, concentrated toward far left and far right edges and very bottom corners. A small distant ornate golden celestial gateway on a floating island in the far upper right. Subtle distant islands in atmospheric haze. Upper and middle 65 percent is spacious uncluttered softly colored sky with low contrast so a scrolling level path can be drawn on top. Professional premium casual mobile game art, lovingly painted dimensional forms, soft glowing edges and very refined color harmony, magical and welcoming for ages 5-8. Bottom foreground clouds are luscious and dimensional with pale lilac shadows and warm light. NO trees, grass, forest, leaves, characters, lettering, numbers, text, paths, buttons, logos, watermark. Full bleed landscape illustration. Render largest landscape resolution.

### Guide

Use case: stylized-concept. Asset type: isolated transparent PNG character sprite for the next-level marker of a premium children's mobile game. Create a lovable polished rounded coral-pink eraser creature named Rubby, balloon-like soft body, tiny curl tuft on top, two small rounded feet, two tiny arms, large expressive dark navy eyes with glossy catchlights, rosy cheeks, joyful confident open smile. A turquoise blue paper sleeve wraps the bottom third of his body with one slim ivory stripe. Small blue aviator scarf flowing right and small warm gold flight goggles resting above the forehead, NOT covering the eyes. Character faces camera in a slight three-quarter turn to the right, one little arm waving, gently floating. Beautiful dimensional hand-painted casual game illustration, rounded rubbery shapes, subtle textured brush shading, luminous peach rim light, crisp silhouette, polished professional production quality. The entire character must fit comfortably inside square canvas, fill 85 percent of canvas height. Absolutely no scenery, cloud, platform, drop shadow outside the character, text, numbers, border, logo, watermark. Truly transparent background. One character only.

## Visual verification

Run from `app/`:

```sh
flutter test --no-pub tool/smash_map_preview/render_map.dart
```

This renders the actual screen with local preview fonts into `app/build/smash-map-preview/`: fresh progress, mid-game progress, compact landscape, larger text, tablet, portrait during rotation and completed world. Reduced-motion mode stops the guide and glints. Safe areas are included in the phone captures.

