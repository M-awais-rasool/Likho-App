# tools/reel — the Instagram reel

Builds `media/reel/likho-reel-30s.mp4`: a 30-second, 1080x1920, 30 fps vertical reel made from
the real app screenshots (`design/store-screenshots/screens/`), Pencil's master art
(`design/mascot/`) and the app's own design tokens. The music, sound effects and voice-over are
synthesised here too, so nothing in the video is licensed from anyone else.

The storyboard and the copy come from [docs/instagram-reel-prompt.md](../../docs/instagram-reel-prompt.md).

## Build

```bash
python3 tools/reel/cutout.py      # cut Pencil's 8 poses out of the Gemini sheets -> art/
python3 tools/reel/deshadow.py    # drop the grey ground shadow under each pose
python3 tools/reel/render.py      # 900 frames -> frames/*.jpg   (~2 min)
python3 tools/reel/audio.py       # music + sfx + macOS voice-over -> audio/reel_mix.m4a
swiftc -O tools/reel/encode.swift -o /tmp/encode
/tmp/encode frames audio/reel_mix.m4a media/reel/likho-reel-30s.mp4 1080 1920 30
```

`render.py probe 4.2 14.0 27.5` writes half-size PNGs of single moments, which is how to check a
change without rendering the whole thing.

Only `Pillow` is needed for the pictures; the sound uses the standard library plus macOS `say`
and `afconvert`, and the encoder uses AVFoundation through `swiftc`. No ffmpeg.

## Changing it

* **Copy and timing:** `SCENES` at the bottom of `render.py` holds each scene's start and end, and
  each `scene_*` function holds its own text. `LINES` in `audio.py` holds the voice-over with the
  second each line starts at; keep the two in step.
* **Colours and type** come from the app's tokens (`app/lib/design/tokens.dart`) and the real
  fonts in `app/tool/store_screenshots/.fonts`.
* **Screens:** `shot("map")` loads `design/store-screenshots/screens/map.png`. Re-make those with
  `design/store-screenshots/build.sh` when the app's look changes.
* **Voice:** `REEL_VOICE=Rishi REEL_RATE=168 python3 tools/reel/audio.py` picks another macOS
  voice. The system voices are a placeholder: for a published reel, record the script yourself or
  buy one read, drop it in as `audio/vo<n>.wav`, and skip the `say` call.
