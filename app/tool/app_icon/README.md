# App icon

`build_app_icon.dart` draws Likho's app icon: Pencil waving hello on a violet sky with soft rays
and sparkles. Pencil comes from the app's own mascot painter (`lib/mascot/`), so the icon matches
the mascot in the app. Every file is drawn from vectors at its exact pixel size.

```bash
cd app
flutter test tool/app_icon/build_app_icon.dart
```

It takes a few seconds. It fails if Pencil leaves Android's safe zone, the 66 dp circle that no
launcher mask cuts off. It writes:

| where | what |
|---|---|
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/` | 1024 px icons for the light, dark and tinted (iOS 18+) home screens, without an alpha channel (App Store rule). Xcode makes the iPhone and iPad sizes from them. |
| `android/app/src/main/res/mipmap-*/` | Adaptive icon layers (Android 8+): `ic_launcher_background`, `ic_launcher_foreground` and `ic_launcher_monochrome` (Android 13 themed icons). Also `ic_launcher` and `ic_launcher_round` for Android 7 and older. Each comes in all five densities. |
| `android/app/src/main/res/mipmap-anydpi-v26/` | `ic_launcher.xml` and `ic_launcher_round.xml`, which stack the three layers |
| `../design/app-icon/` | `google-play-512.png` for the Play Store listing, and `likho-icon-1024.png` for anything else |

To change the design, edit the constants at the top of the script and run it again:
- `_day` and `_night` are the sky colours.
- `_height`, `_centre` and `_tilt` place Pencil.
- `_wave` is his pose.
- `_sparkles` holds the sparkles.
