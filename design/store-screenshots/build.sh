#!/bin/sh
# Saves the Likho store screenshots (1080 x 1920) and the feature graphic
# (1024 x 500) from compose.html with headless Chrome. Render the inputs
# first, from app/:
#   flutter test tool/store_screenshots/render_screens.dart
#   flutter test tool/store_screenshots/render_mascot.dart
set -e
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p play
shot() { # name query width height
  perl -e 'alarm 40; exec @ARGV' "$CHROME" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --force-device-scale-factor=1 --window-size="$3,$4" --virtual-time-budget=4000 \
    --screenshot="$PWD/play/$1.png" "file://$PWD/compose.html?$2" >/dev/null 2>&1 || true
  sips -g pixelWidth -g pixelHeight "play/$1.png" | tail -2 | tr '\n' ' '; echo " $1"
}
for i in 1 2 3 4 5 6 7 8; do shot "likho-0$i" "s=$i" 1080 1920; done
shot likho-feature-graphic "s=feature" 1024 500
# Play wants 24-bit PNGs (no alpha)
python3 -c "
import glob
from PIL import Image
for f in glob.glob('play/*.png'):
    Image.open(f).convert('RGB').save(f, optimize=True)
"
