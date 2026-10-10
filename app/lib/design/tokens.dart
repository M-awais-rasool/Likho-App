// Likho design tokens: the single source of colours, sizes and type.
// No other file may hard-code a colour.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand / UI colours (from the brief).
abstract final class LikhoColors {
  static const primary = Color(0xFFFFC83D);
  static const secondary = Color(0xFF4D9DE0);
  static const success = Color(0xFF3BB273);
  static const hint = Color(0xFFFF8A5B); // never red for mistakes
  static const background = Color(0xFFFFF8EC);
  static const backgroundGlow = Color(0xFFFFF0CC); // splash radial glow (prototype)
  static const clear = Color(0x00000000); // transparent (status bar, empty fills)
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2B2D42);

  // Pencil tokens from the brief, for UI use. The mascot itself uses the values
  // measured on the master art (see [MascotColors]); they differ slightly.
  static const eraser = Color(0xFFFF9EB5);
  static const graphite = Color(0xFF2B2D42);

  static const primaryDeep = Color(0xFFE0A21A); // 3D edge under yellow buttons (prototype)
  static const inkMuted = Color(0xFF6B6E85); // settings icon (prototype)
  static const shadowSoft = Color(0x1A2B2D42); // rgba(43,45,66,.10)
  static const shadowFaint = Color(0x142B2D42); // rgba(43,45,66,.08)

  // Neutral helpers used by dev screens.
  static const inkSoft = Color(0x992B2D42);
  static const inkFaint = Color(0x1F2B2D42);
  static const surfaceSunk = Color(0xFFF3EBDD);
}

/// Mascot colours measured on the master image (design/mascot/ic1bzv…jpeg).
/// Body colours live in [BodySwatch] because they change with setBodyColor.
abstract final class MascotColors {
  static const eraser = Color(0xFFFC999C);
  static const eraserShade = Color(0xFFF18087);
  static const eraserLine = Color(0xFFCF6168);
  static const band = Color(0xFFCBD3DC);
  static const bandHighlight = Color(0xFFE8EEF6);
  static const bandShade = Color(0xFFB6C1CC);
  static const bandLine = Color(0xFF8898A6);
  static const cone = Color(0xFFECB57D);
  static const coneLight = Color(0xFFF4CA98);
  static const coneDark = Color(0xFFDB9A67);
  static const coneLine = Color(0xFFBC7540);
  static const graphite = Color(0xFF323447);
  static const eyeRim = Color(0xFFA05C1B);
  static const eyeWhite = Color(0xFFFFFFFF);
  static const pupil = Color(0xFF2A2E4A);
  static const happyEye = Color(0xFF5C3C2C); // closed "^ ^" eyes, expression sheet
  static const brow = Color(0xFF9B5618);
  static const cheek = Color(0xFFF78A5C);
  static const mouth = Color(0xFF6E3227);
  static const mouthTeeth = Color(0xFFFFFFFF);
  static const tongue = Color(0xFFEF8882);
  static const tongueLine = Color(0xFFB8545A);
  static const effects = Color(0xFFA8908A); // zzz, surprise and motion lines
  static const shadow = Color(0xFFE5E5EB);
  static const debugMissing = Color(0xFFFF00FF); // unknown colour in a part file
}

/// One body colour with the shades the art needs.
class BodySwatch {
  const BodySwatch({
    required this.key,
    required this.base,
    required this.light,
    required this.dark,
    required this.line,
    required this.lid,
    Color? tint,
  }) : tint = tint ?? const Color(0xFFFFEFC2);

  /// The colour the app asks for (one of [BodySwatch.options] or any colour).
  final Color key;
  final Color base;
  final Color light;
  final Color dark;
  final Color line;
  final Color lid;

  /// Pale tint of the colour for UI circles (profile avatar), prototype PAL.
  final Color tint;

  /// Yellow, measured on the master image (lid measured on the sleepy cell).
  static const yellow = BodySwatch(
    key: Color(0xFFFFC83D),
    base: Color(0xFFFEC344),
    light: Color(0xFFFBD065),
    dark: Color(0xFFF5AA36),
    line: Color(0xFFC27A28),
    lid: Color(0xFFECA434),
    tint: Color(0xFFFFEFC2),
  );

  /// The six colours from the brief. Blue, green, purple and pink use the
  /// shades measured on the colour sheet (design/mascot/etxq16…jpeg); their eyelid
  /// shade and all of coral are derived (no reference art for them).
  static final List<BodySwatch> options = [
    yellow,
    BodySwatch.measured(const Color(0xFF4D9DE0), 0xFF64ABE3, 0xFF80BDE9, 0xFF4C9ADC, 0xFF3A75A5, 0xFFD6E9FA),
    BodySwatch.measured(const Color(0xFF3BB273), 0xFF68C996, 0xFF85D7A9, 0xFF4AB27F, 0xFF398860, 0xFFCDEFDB),
    BodySwatch.derive(const Color(0xFFFF8A5B), tint: const Color(0xFFFFDDCF)),
    BodySwatch.measured(const Color(0xFFB79CED), 0xFFB8A0EA, 0xFFCAB5F0, 0xFFA88BDF, 0xFF886BAB, 0xFFE5DCFB),
    BodySwatch.measured(const Color(0xFFFF9EB5), 0xFFFB9AAB, 0xFFFDB1BB, 0xFFF68394, 0xFFC4606D, 0xFFFCDCE8),
  ];

  factory BodySwatch.measured(Color key, int base, int light, int dark, int line, int tint) => BodySwatch(
        key: key,
        base: Color(base),
        light: Color(light),
        dark: Color(dark),
        line: Color(line),
        lid: _lidFor(Color(base)),
        tint: Color(tint),
      );

  static Color _lidFor(Color base) {
    final h = HSLColor.fromColor(base);
    return h
        .withLightness((h.lightness - 0.09).clamp(0.0, 1.0))
        .withSaturation((h.saturation - 0.06).clamp(0.0, 1.0))
        .toColor();
  }

  /// Shades for a colour without reference art. The HSL offsets are the
  /// average of the five measured swatches.
  factory BodySwatch.derive(Color c, {Color? tint}) {
    final h = HSLColor.fromColor(c);
    HSLColor shift(double dl, double ds) => h
        .withLightness((h.lightness + dl).clamp(0.0, 1.0))
        .withSaturation((h.saturation + ds).clamp(0.0, 1.0));
    return BodySwatch(
      key: c,
      base: c,
      light: shift(0.065, 0.01).toColor(),
      dark: shift(-0.065, -0.06).toColor(),
      line: shift(-0.21, -0.33).toColor(),
      lid: _lidFor(c),
      tint: tint ?? shift(0.3, 0).toColor(),
    );
  }

  static BodySwatch forColor(Color c) {
    for (final s in options) {
      if (s.key.toARGB32() == c.toARGB32()) return s;
    }
    return BodySwatch.derive(c);
  }
}

/// The scenery a world's map section is painted with (see SceneryPainter).
enum WorldScene { meadow, castle, cove, frost, forest, town, mountain, beach, garden, sky, jungle, island, river, space }

/// Colours of one world: the map section fades from [bg] at the bottom to
/// [sky] at the top; done levels are [accent] on a [deep] edge; scenery is
/// drawn in [soft] and [pop]. Gameplay, level intro and level complete use
/// [bg], [soft] and [accent] too.
class WorldTheme {
  const WorldTheme({
    required this.bg,
    required this.accent,
    required this.deep,
    required this.soft,
    Color? sky,
    Color? pop,
    this.scene = WorldScene.meadow,
    this.dark = false,
  })  : sky = sky ?? bg,
        pop = pop ?? accent;
  final Color bg, accent, deep, soft, sky, pop;
  final WorldScene scene;
  final bool dark;
}

/// The fourteen world themes. Theme ids are the look, not the world: in the
/// course they go round the colour wheel (green, lime, gold, orange, coral,
/// pink, magenta, lavender, blue, sky, teal, mint) and end in the two night
/// worlds, so each world's colours are close to the one before. [all] is in
/// that course order.
abstract final class LikhoWorlds {
  static const letterLand = WorldTheme(
      bg: Color(0xFFE6F5D8), sky: Color(0xFFF4FBEA), accent: Color(0xFF5BB13C), deep: Color(0xFF3F8A26), soft: Color(0xFFCDEAB4), pop: Color(0xFFFFC93C));
  static const alphabetCastle = WorldTheme(
      bg: Color(0xFFF6E4F5), sky: Color(0xFFFDF2F9), accent: Color(0xFFC752C0), deep: Color(0xFF9A3594), soft: Color(0xFFEBC9EA), pop: Color(0xFFFFC23D),
      scene: WorldScene.castle);
  static const smallLetterCove = WorldTheme(
      bg: Color(0xFFD6F2EF), sky: Color(0xFFEDFAF8), accent: Color(0xFF11A7A0), deep: Color(0xFF0B7F7A), soft: Color(0xFFB2E5E0), pop: Color(0xFFFF8A6B),
      scene: WorldScene.cove);
  static const frostyBay = WorldTheme(
      bg: Color(0xFF17344F), sky: Color(0xFF0D2036), accent: Color(0xFF56C2EE), deep: Color(0xFF2C8DC0), soft: Color(0xFF26507A), pop: Color(0xFF7CF0C4),
      scene: WorldScene.frost, dark: true);
  static const phonicsForest = WorldTheme(
      bg: Color(0xFFFCE4CE), sky: Color(0xFFFFF4E6), accent: Color(0xFFE8702A), deep: Color(0xFFBB521A), soft: Color(0xFFF6C9A4), pop: Color(0xFFD9472B),
      scene: WorldScene.forest);
  static const wordTown = WorldTheme(
      bg: Color(0xFFE1E8FC), sky: Color(0xFFF2F5FF), accent: Color(0xFF3D63DD), deep: Color(0xFF2847B0), soft: Color(0xFFC5D2F6), pop: Color(0xFFFFC23D),
      scene: WorldScene.town);
  static const soundMountain = WorldTheme(
      bg: Color(0xFFEAE2FA), sky: Color(0xFFFBF0F7), accent: Color(0xFF8C67DB), deep: Color(0xFF6A49B8), soft: Color(0xFFD6C8F2), pop: Color(0xFFFF9EC4),
      scene: WorldScene.mountain);
  static const blendBeach = WorldTheme(
      bg: Color(0xFFFFEDC8), sky: Color(0xFFE2F5FB), accent: Color(0xFFF0A417), deep: Color(0xFFC27F06), soft: Color(0xFFF8DB9C), pop: Color(0xFF2EC4D6),
      scene: WorldScene.beach);
  static const sightGarden = WorldTheme(
      bg: Color(0xFFFCE2EB), sky: Color(0xFFFFF3F7), accent: Color(0xFFEE5F8F), deep: Color(0xFFC43F6E), soft: Color(0xFFF6C3D5), pop: Color(0xFF6CC04A),
      scene: WorldScene.garden);
  static const sentenceSky = WorldTheme(
      bg: Color(0xFFD8EEFC), sky: Color(0xFFF2FAFF), accent: Color(0xFF2EA3E6), deep: Color(0xFF1A7DB8), soft: Color(0xFFB9DFF7), pop: Color(0xFFFFFFFF),
      scene: WorldScene.sky);
  static const actionJungle = WorldTheme(
      bg: Color(0xFFEBF4CC), sky: Color(0xFFF7FAE4), accent: Color(0xFF8DB51E), deep: Color(0xFF6A8C0E), soft: Color(0xFFD3E69C), pop: Color(0xFFFF8F3C),
      scene: WorldScene.jungle);
  static const questionIsland = WorldTheme(
      bg: Color(0xFFFFE3DA), sky: Color(0xFFE0F5F6), accent: Color(0xFFF05A4F), deep: Color(0xFFC73D33), soft: Color(0xFFF9C2B6), pop: Color(0xFF2FC2B0),
      scene: WorldScene.island);
  static const readingRiver = WorldTheme(
      bg: Color(0xFFD6F2E5), sky: Color(0xFFEDFAF4), accent: Color(0xFF22B07D), deep: Color(0xFF15875D), soft: Color(0xFFB3E3CD), pop: Color(0xFF4BA8E8),
      scene: WorldScene.river);
  static const storySpace = WorldTheme(
      bg: Color(0xFF252950), sky: Color(0xFF181B3B), accent: Color(0xFFA08BF0), deep: Color(0xFF7A63D4), soft: Color(0xFF3A4077), pop: Color(0xFFFFE38A),
      scene: WorldScene.space, dark: true);

  static const all = [
    letterLand, actionJungle, blendBeach, phonicsForest, questionIsland, sightGarden, alphabetCastle, //
    soundMountain, wordTown, sentenceSky, smallLetterCove, readingRiver, frostyBay, storySpace,
  ];

  static const ids = [
    'letterLand', 'actionJungle', 'blendBeach', 'phonicsForest', 'questionIsland', 'sightGarden', 'alphabetCastle', //
    'soundMountain', 'wordTown', 'sentenceSky', 'smallLetterCove', 'readingRiver', 'frostyBay', 'storySpace',
  ];

  /// Position of a `themeId` in [all] (0 when unknown), e.g. for the map's
  /// decorations of a world.
  static int indexOf(String id) => ids.contains(id) ? ids.indexOf(id) : 0;

  /// Theme for a course world's `themeId`.
  static WorldTheme byId(String id) => all[indexOf(id)];
}

/// World map colours (prototype "10 World map").
abstract final class MapColors {
  static const pathBand = Color(0x8CFFFFFF); // rgba(255,255,255,.55)
  static const pathDots = Color(0xF2FFFFFF); // rgba(255,255,255,.95)
  static const nodeLocked = Color(0xFFDCD6CA);
  static const nodeLockedDeep = Color(0xFFC6BFB1);
  static const nodeLockedDark = Color(0xFF474C82);
  static const nodeLockedDarkDeep = Color(0xFF363A6A);
  static const nodeInnerHighlight = Color(0x59FFFFFF); // inset 0 3px 0 rgba(255,255,255,.35)
  static const iconLocked = Color(0x522B2D42); // rgba(43,45,66,.32)
  static const iconLockedDark = Color(0x66FFFFFF); // rgba(255,255,255,.4)
  static const starOff = Color(0x2E2B2D42); // rgba(43,45,66,.18)
  static const starShadow = Color(0x1A000000); // rgba(0,0,0,.1)
  static const labelBg = Color(0xBFFFFFFF); // rgba(255,255,255,.75)
  static const labelBgDark = Color(0x1FFFFFFF); // rgba(255,255,255,.12)
  static const topFade = Color(0xF2FFF8EC); // rgba(255,248,236,.95)
  static const topFadeClear = Color(0x00FFF8EC);
  static const settingsBg = Color(0xD9FFFFFF); // rgba(255,255,255,.85)

  // decorations, per world (3 kinds each)
  static const bush = Color(0xFFC3E3A5);
  static const flower = Color(0xFFFFD66B);
  static const cloud = Color(0xD9FFFFFF); // .85
  static const wave = Color(0xB3FFFFFF); // .7
  static const sand = Color(0xFFF1DDB8);
  static const shell = Color(0xFFFFC2AD);
  static const treeLight = Color(0xFFA6CE93);
  static const treeDark = Color(0xFF86B874);
  static const leaf = Color(0xFFF0A04B);
  static const houseRed = Color(0xFFF7C9B5);
  static const houseBlue = Color(0xFFCFE3F3);
  static const cloudWhite = Color(0xFFFFFFFF);
  static const cloudShade = Color(0xFFDCE2F0); // the belly of the cloud bank between worlds
  static const kite = Color(0xFFFFC83D);
  static const cloudSoft = Color(0xE6FFFFFF); // .9
  static const rock = Color(0xFFD9D1EA);
  static const rockDark = Color(0xFFC4B8E0);
  static const beachBall = Color(0xFFFFB86B);
  static const sandWarm = Color(0xFFF6DDAE);
  static const blossom = Color(0xFFF59BBE);
  static const blossomBush = Color(0xFFF5C9DB);
  static const jungleLeaf = Color(0xFFB5CF5E);
  static const jungleLeafDark = Color(0xFF97B443);
  static const palm = Color(0xFFE8CF6E);
  static const ripple = Color(0xB3FFFFFF); // .7
  static const lilyPad = Color(0xFF9CD39C);
  static const riverStone = Color(0xFFCBE6EE);
  static const starDot = Color(0xFFFFE8A3);
  static const planet = Color(0xFF7A63D4);
  static const planetShade = Color(0x2E000000); // inset rgba(0,0,0,.18)
}

/// World bosses (lib/bosses): shared face colours (Pencil's), then each
/// boss's own colours. Shades and outlines are derived (Shade.of).
abstract final class BossColors {
  static const shadow = Color(0x1A000000);
  static const shine = Color(0xFFFFFFFF); // drawn at .55
  static const cheek = Color(0x8CFF8FA3); // .55
  static const eyeWhite = Color(0xFFFFFFFF);
  static const pupil = Color(0xFF2A2E4A);
  static const happyEye = Color(0xFF4A3434); // closed "^ ^" and sleeping eyes
  static const mouth = Color(0xFF6E3227);
  static const tongue = Color(0xFFEF8882);
  static const faceLight = Color(0xFFFFD1DA); // smile on a dark face (ladybug)
  static const bubble = Color(0xFFE8F6FF);
  static const bubbleRim = Color(0xFF9CCBEA);
  static const zzz = Color(0xFF7C7FA8);
  static const zzzNight = Color(0xFFE6E0FF);

  static const snailBody = Color(0xFFFFD47A);
  static const snailShell = Color(0xFFFF8C9E);
  static const fishBody = Color(0xFFFF9233);
  static const fishBand = Color(0xFFFFFFFF);
  static const fishBandShade = Color(0xFFE4ECF5);
  static const fishLine = Color(0xFF3A2D3F);
  static const bearFur = Color(0xFFB07A4E);
  static const bearCream = Color(0xFFF5D7B2);
  static const bearNose = Color(0xFF4A3A30);
  static const pawPad = Color(0xFFF2B0A6);
  static const autumnLeaf = Color(0xFFEE6A2E);
  static const busBody = Color(0xFFFFC83D);
  static const busDark = Color(0xFF3A3D5C);
  static const busWindow = Color(0xFFCFE8F8);
  static const busWindowLight = Color(0xFFE6F4FC);
  static const busWindowShade = Color(0xFFB4D6EE);
  static const busWindowLine = Color(0xFF6E9CC2);
  static const busLightOn = Color(0xFFFFF4B8);
  static const busLightOff = Color(0xFF9A9CB8);
  static const robotArm = Color(0xFFA9B4C6);
  static const cloudBody = Color(0xFFFFFFFF);
  static const cloudShade = Color(0xFFD9E9F8);
  static const cloudLine = Color(0xFF8FB8E2);
  static const rainbow = [Color(0xFFFF6B6B), Color(0xFFFFA94D), Color(0xFFFFD43B), Color(0xFF69DB7C), Color(0xFF4DABF7), Color(0xFF9775FA)];
  static const moon = Color(0xFFFFE07A);
  static const moonCrater = Color(0xFFF2C85A);
  static const moonCraterShade = Color(0xFFE5B544);
  static const nightcap = Color(0xFF5C6CF2);
  static const nightcapLine = Color(0xFF3B47A8);
  static const starGold = Color(0xFFFFE38A);
  static const goatFur = Color(0xFFF7F2E8);
  static const goatLine = Color(0xFFA8977C);
  static const goatHorn = Color(0xFFD9BA8E);
  static const goatEarInner = Color(0xFFF7B5B0);
  static const goatMuzzle = Color(0xFFFBE1D6);
  static const goatHoof = Color(0xFF6B5B4E);
  static const collar = Color(0xFFEE5A5F);
  static const bell = Color(0xFFFFC93C);
  static const crabShell = Color(0xFFF2604B);
  static const ladybugShell = Color(0xFFF0434B);
  static const ladybugHead = Color(0xFF34375A);
  static const ladybugHeadLight = Color(0xFF474B75);
  static const ladybugHeadDark = Color(0xFF2A2C49);
  static const ladybugHeadLine = Color(0xFF1C1E33);
  static const ladybugWing = Color(0xFFDDF0FF);
  static const ladybugWingLine = Color(0xFF9CC3E6);
  static const monkeyFur = Color(0xFF9C6A44);
  static const monkeyFace = Color(0xFFF6D4AE);
  static const turtleShell = Color(0xFF3FA45F);
  static const turtlePlate = Color(0xFF7CCB82);
  static const turtleRim = Color(0xFFF2D27A);
  static const turtleSkin = Color(0xFFA3D97F);
  static const hibiscus = Color(0xFFFF6F91);
  static const hibiscusCentre = Color(0xFFFFD43B);
  static const frogSkin = Color(0xFF8ACF4E);
  static const frogBelly = Color(0xFFEAF6BD);
  static const lilyPad = Color(0xFF3BAA78);
  static const crown = Color(0xFFFFC93C);
  static const gem = Color(0xFFFF5A6E);
  static const dragonBody = Color(0xFF5FD0A8);
  static const dragonBelly = Color(0xFFFFE6A0);
  static const dragonWing = Color(0xFFFF9BC0);
  static const dragonHorn = Color(0xFFFFF0C8);
  static const penguinBody = Color(0xFF86A0C4);
  static const penguinWhite = Color(0xFFFAFCFF);
  static const penguinWhiteShade = Color(0xFFDCE6F2);
  static const penguinBeak = Color(0xFFFFA63D);
  static const penguinScarf = Color(0xFFFF5C72);
}

/// Named colours used by course content (e.g. Paint Shop: "red").
abstract final class ContentColors {
  static const red = Color(0xFFF2735B);
  static const blue = Color(0xFF4D9DE0);
  static const yellow = Color(0xFFFFC83D);
  static const green = Color(0xFF3BB273);
  static const purple = Color(0xFF9B7FE6);

  static Color? byName(String? name) => switch (name) {
        'red' => red,
        'blue' => blue,
        'yellow' => yellow,
        'green' => green,
        'purple' => purple,
        _ => null,
      };

  /// Default colours of pick items, in order (prototype cols).
  static const items = [Color(0xFFFF8A5B), Color(0xFF4D9DE0), Color(0xFFFFC83D), Color(0xFF3BB273), Color(0xFF9B7FE6)];
}

/// Gameplay screen colours (prototype "12 Gameplay").
abstract final class GameColors {
  static const secondaryDeep = Color(0xFF2F7CC0); // replay button edge
  static const successDeep = Color(0xFF268F58); // "Done" edge
  static const hintDeep = Color(0xFFE0673A);
  static const white95 = Color(0xF2FFFFFF);
  static const white85 = Color(0xD9FFFFFF);
  static const white60 = Color(0x99FFFFFF);
  static const white55 = Color(0x8CFFFFFF);
  static const white35 = Color(0x59FFFFFF);
  static const white28 = Color(0x47FFFFFF);
  static const white25 = Color(0x40FFFFFF);
  static const white20 = Color(0x33FFFFFF);
  static const white15 = Color(0x26FFFFFF);
  static const white01 = Color(0x03FFFFFF);
  static const white00 = Color(0x00FFFFFF); // fully clear white: gradient end stops fade white, not black
  static const ink00 = Color(0x002B2D42);
  static const ink06 = Color(0x0F2B2D42);
  static const ink07 = Color(0x122B2D42);
  static const ink08 = Color(0x142B2D42);
  static const ink10 = Color(0x1A2B2D42);
  static const ink12 = Color(0x1F2B2D42);
  static const ink14 = Color(0x242B2D42);
  static const ink15 = Color(0x262B2D42);
  static const ink35 = Color(0x592B2D42);
  static const ink40 = Color(0x662B2D42);
  static const ink60 = Color(0x992B2D42);
  static const black06 = Color(0x0F000000);
  static const black08 = Color(0x14000000);
  static const black10 = Color(0x1A000000);
  static const black12 = Color(0x1F000000);
  static const black18 = Color(0x2E000000);
  static const black20 = Color(0x33000000);
  static const paperWarm = Color(0xFFFFFDF8); // illustration placeholder
  static const paperNote = Color(0xFFFFFDF5);
  static const successGlow = Color(0x593BB273); // .35
  static const successGlowStrong = Color(0x993BB273); // .6
  static const successInk = Color(0xB33BB273); // .7
  static const successTint = Color(0x403BB273); // .25
  static const successPale = Color(0xFFE6F6EC);
  static const hintTint = Color(0x33FF8A5B); // .2
  static const hintPale = Color(0xFFFFF1EA);
  static const hintBox = Color(0xFFFFF4EC);
  static const glowYellowSoft = Color(0x66FFC83D); // .4
  static const eraser = Color(0xFFF07F97);

  // writing pad
  static const lineTop = Color(0xFFBFD8F0);
  static const lineBase = Color(0xFF8FBCE6);
  static const lineDesc = Color(0xFFE6D9C8);
  static const guidePaper = Color(0xFFE7E2D8);
  static const guideDashed = Color(0xFFC9CDD3); // the next stroke's path when writing without tracing

  // tracing lane: the area ink may go in (trace / dots rounds)
  static const lanePaper = Color(0x2EFFC83D); // primary .18
  static const laneDone = Color(0x383BB273); // success .22: a finished stroke
  static const stepArrow = Color(0xE64D9DE0); // secondary .9: direction chevrons

  // pick shapes
  static const bubbleEdge = Color(0x99BDE8E4);
  static const bubbleShadow = Color(0x2E157C77);
  static const bubbleLabel = Color(0xFF157C77);
  static const mushroomStem = Color(0xFFFFF1DC);
  static const shellA = Color(0xFFFFD3C2);
  static const shellB = Color(0xFFFFC2AD);
  static const shellShade = Color(0x2EE0673A);
  static const shellLabel = Color(0xFF8A3F22);
  static const lilyPad = Color(0xFF7CC47F);
  static const lilyPadShadow = Color(0x402C6B41);
  static const basketA = Color(0xFFD9A066);
  static const basketB = Color(0xFFC78A50);
  static const basketDeep = Color(0xFFA86F3A);
  // sort rounds: the hungry monster
  static const monster = Color(0xFF8E6CE0);
  static const monsterDeep = Color(0xFF6E4FC4);
  static const monsterMouth = Color(0xFF3B1F6B);
  static const monsterTongue = Color(0xFFFF8FA8);
  static const jarTop = Color(0xBFFFFFFF);
  static const jarBottom = Color(0x73FFFFFF);
  static const jarShadow = Color(0x2E2C6B41);
  static const jarLabel = Color(0xFF2C6B41);
  static const cloudShadow = Color(0x1F2767A5);
  static const cloudLabel = Color(0xFF2767A5);
  static const planetRing = Color(0x14FFFFFF);

  // stages
  static const roof = Color(0xFFB4573A);
  static const window = Color(0xFFCFE8F8);
  static const door = Color(0xFF8C5A48);
  static const cupcakeA = Color(0xFFF2B880);
  static const cupcakeB = Color(0xFFE8A566);
  static const frosting = Color(0xFFFCD5E1);
  static const frostingShade = Color(0xFFF4B3C8);
  static const cherry = Color(0xFFF2735B);

  // order slots
  static const trainDark = Color(0xFF3A3D5C);
  static const sleeper = Color(0xFFB98A62);
  static const rail = Color(0xFF8C6B4F);
  static const riverTop = Color(0xFF8FD0E8);
  static const riverBottom = Color(0xFF5DB5D6);
  static const bank = Color(0xFF86B874);
  static const plankEdge = Color(0x598C5A48);
  static const deer = Color(0xFFC98B5B);
  static const panelNumber = Color(0xFFA39D90);
  static const wagonColors = [Color(0xFFFF8A5B), Color(0xFFFFC83D), Color(0xFF3BB273), Color(0xFF4D9DE0)];

  // doctor (patient)
  static const clinicTop = Color(0xFFEAF4FB);
  static const clinicFloor = Color(0xFFE7F1EA);
  static const shirt = Color(0xFF9FCDEB);
  static const hand = Color(0xFFF4C9A8);
  static const ear = Color(0xFFF0BD98);
  static const face = Color(0xFFF7D2B4);
  static const hair = Color(0xFF5A4036);
  static const nose = Color(0xFFEBA88A);
  static const lips = Color(0xFFC9604A);
  static const blush = Color(0x80FF8FA3);
  static const faceShade = Color(0x0D000000);

  // fix-it paper
  static const ruled = Color(0x2E4D9DE0);

  // alien (speak)
  static const spaceTop = Color(0xFF3A4077);
  static const spaceBottom = Color(0xFF252950);
  static const starDot = Color(0xFFFFE8A3);
  static const alien = Color(0xFF7FD69A);

  // boss bubbles
  static const bubbleRim = Color(0xF2FFFFFF);
  static const bubbleMid = Color(0x66FFFFFF);
  static const bubbleBlue = Color(0x80A0C8F0);

  static const sparks = [Color(0xFFFFC83D), Color(0xFFFF8A5B), Color(0xFF4D9DE0), Color(0xFF3BB273)];
  static const confetti = [Color(0xFFFFC83D), Color(0xFF3BB273), Color(0xFF4D9DE0), Color(0xFFFF8A5B), Color(0xFF9B7FE6)];
}

/// Shared colours of the account, profile, room and parent screens
/// (prototype screens 02–09 and 13–23).
abstract final class UiColors {
  static const inkBody = Color(0xFF5C5F77); // body copy under titles
  static const inkLabel = Color(0xFF8C8577); // section labels, "Add child"
  static const inkAdd = Color(0xFF9A9384); // "add" icon on Who's playing
  static const inkHint = Color(0xFFA39D90); // "ya" divider, small print
  static const chevron = Color(0xFFB3AC9E);
  static const link = Color(0xFF2F7CC0);
  static const error = Color(0xFFC2562E); // form hints (never red)
  static const okGreen = Color(0xFF1F7A4A);
  static const danger = Color(0xFF8C5A48); // "delete" text
  static const dangerTint = Color(0x1FFF8A5B); // rgba(255,138,91,.12)
  static const ink05 = Color(0x0D2B2D42);
  static const ink18 = Color(0x2E2B2D42);
  static const ink20 = Color(0x332B2D42);
  static const black04 = Color(0x0A000000);
  static const black05 = Color(0x0D000000);
  static const black25 = Color(0x40000000);
  static const black35 = Color(0x59000000);
  static const white10 = Color(0x1AFFFFFF);
  static const white80 = Color(0xCCFFFFFF);
  static const white92 = Color(0xEBFFFFFF);
  static const scrim = Color(0x8C1D1E2C); // rgba(29,30,44,.55), parent gate
  static const scrimSoft = Color(0x801D1E2C); // .5, delete confirm
  static const chip = Color(0xFFF1EEE8); // grey buttons, row dividers
  static const chipAlt = Color(0xFFF4F1EA);
  static const chipPressed = Color(0xFFE9E4D8);
  static const toggleOff = Color(0xFFD9D4CA);
  static const parentBg = Color(0xFFF7F4EE);
  static const googleBlue = Color(0xFF4D9DE0);
  static const googleGreen = Color(0xFF3BB273);
  static const googleYellow = Color(0xFFFFC83D);
  static const googleCoral = Color(0xFFFF8A5B);
}

/// 02 Welcome.
abstract final class WelcomeColors {
  static const top = Color(0xFFFFF1D2);
  static const letterB = Color(0x474D9DE0); // #4D9DE0 at .28
  static const letterC = Color(0x473BB273); // #3BB273 at .28
  static const letterE = Color(0x409B7FE6); // #9B7FE6 at .25
  static const letterA = Color(0xFFFF8A5B);
}

/// 06 Who's playing, 07 Onboarding, 09 Placement done.
abstract final class ProfileColors {
  static const glow = Color(0xFFFFEFC9);
  static const nameShadow = Color(0x40E0A21A); // rgba(224,162,26,.25)
  static const flame = Color(0xFFFFB23D);
  static const candles = [Color(0xFFFF8A5B), Color(0xFF4D9DE0), Color(0xFF3BB273), Color(0xFF9B7FE6)];
  static const placementGlow = Color(0xFFEAF5DE);

  /// 3D edge under a colour swatch (prototype PAL[c][1]); purple and pink
  /// have no prototype shade for the brief colours, so theirs are derived.
  static Color deepFor(Color key) => switch (key.toARGB32()) {
        0xFFFFC83D => LikhoColors.primaryDeep,
        0xFF4D9DE0 => GameColors.secondaryDeep,
        0xFF3BB273 => GameColors.successDeep,
        0xFFFF8A5B => GameColors.hintDeep,
        _ => _darker(key),
      };

  static Color _darker(Color c) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness - .14).clamp(0.0, 1.0)).toColor();
  }
}

/// 13 Level complete.
abstract final class CompleteColors {
  static const glow = Color(0xB3FFFFFF); // rgba(255,255,255,.7)
  static const flash = Color(0xFFFFF6D6);
  static const starSlot = Color(0x122B2D42); // rgba(43,45,66,.07)
  static const starSlotShade = Color(0x1A2B2D42);
  static const starEmpty = Color(0x242B2D42); // .14
  static const starGlow = Color(0xB3FFC83D); // rgba(255,200,61,.7)
}

/// 14 Session end: evening sky.
abstract final class SessionEndColors {
  static const skyTop = Color(0xFF5B5896);
  static const skyMid = Color(0xFF9A86C4);
  static const skyBottom = Color(0xFFF2B9A0);
  static const moon = Color(0xFFFFE8A3);
  static const moonShade = Color(0xFFF5D27A);
  static const moonGlow = Color(0x99FFE8A3);
  static const star = Color(0xFFFFE08A);
  static const bed = Color(0xFFF7EEE0);
  static const buttonEdge = Color(0x262B2D42); // .15
}

/// 15 Mascot room.
abstract final class RoomColors {
  static const wallA = Color(0xFFFBE3D0);
  static const wallB = Color(0xFFF8DCC6);
  static const skyTop = Color(0xFFBDE3FA);
  static const skyBottom = Color(0xFFE6F4FD);
  static const curtain = Color(0xD9FF8A5B); // #FF8A5B at .85
  static const floorA = Color(0xFFE7C49A);
  static const floorB = Color(0xFFDDB88C);
  static const poster = Color(0xFF4D9DE0);
  static const lampGlow = Color(0x99FFC83D);
  static const wood = Color(0xFF8C6B4F);
  static const leafLight = Color(0xFF5DAE3B);
  static const leafDark = Color(0xFF3F8A26);
  static const pot = Color(0xFFE27D5F);
  static const rugA = Color(0xFF9B7FE6);
  static const rugB = Color(0xFFB8A4EF);
  static const shelfTop = Color(0xFFB98A62);
  static const shelfBottom = Color(0xFFA97B55);
  static const shelfEdge = Color(0xFF8C6B4F);
  static const itemWorn = Color(0xFFFFF6DA);
  static const priceChip = Color(0xFFFFF1C9);
  static const roomIcon = Color(0xFFB4573A);
}

/// 16 Child profile.
abstract final class ChildProfileColors {
  static const starBg = Color(0xFFFFF1C9);
  static const starInset = Color(0x33E0A21A);
  static const flagBg = Color(0xFFDDF3E6);
  static const flagInset = Color(0x333BB273);
  static const sunBg = Color(0xFFFFE4D7);
  static const sunInset = Color(0x33FF8A5B);
  static const worldOff = Color(0xFFE7E1D5);
  static const bookTop = Color(0xFF9B7FE6);
  static const bookBottom = Color(0xFF7659C9);
  static const bookEdge = Color(0xFF5E45AE);
  static const bookSpine = Color(0xFFE7D9BF);
}

/// 17 Sticker book.
abstract final class StickerColors {
  static const bg = Color(0xFF8E73D9);
  static const page = Color(0xFFFFF8EC);
  static const pageEdge = Color(0xFF6B53B8);
  static const paperEdge = Color(0xFFE9DDC7);
  static const shine = Color(0x73FFFFFF); // .45
  static const shineBoss = Color(0x99FFFFFF); // .6
  static const goldLight = Color(0xFFFFE08A);
  static const goldDeep = Color(0xFFE0A21A);
  static const goldGlow = Color(0x66E0A21A); // .4
  static const goldFaint = Color(0x40E0A21A); // .25
  static const bossName = Color(0xFFB07A10);
  static const missIcon = Color(0x1A2B2D42); // .1
}

/// 18 Certificate.
abstract final class CertificateColors {
  static const top = Color(0xFF3B3F7A);
  static const bottom = Color(0xFF1E2144);
  static const star = Color(0xFFFFE8A3);
}

/// 19–22 Parent screens.
abstract final class ParentColors {
  static const strongBg = Color(0xFFDDF3E6);
  static const strongFg = Color(0xFF1F7A4A);
  static const practiceBg = Color(0xFFFFE9DE);
  static const practiceFg = Color(0xFFB4502A);
  static const notYetFg = Color(0xFFA39D90);
  static const journeyTop = Color(0xFFFFF1CF);
  static const journeyBottom = Color(0xFFFFE3D4);
  static const journeyShadow = Color(0x1FE0673A); // rgba(224,103,58,.12)
  static const journeyLabel = Color(0xFFB4573A);
  static const paperLine = Color(0xFFDDEBF7);
  static const starOff = Color(0xFFE4DED2);
  static const rowLine = Color(0xFFF7F4EE);
  static const planSelected = Color(0xFFF2F8FE);
  static const featureGreenBg = Color(0xFFE3EEDB);
  static const featureGreen = Color(0xFF3F8F5A);
  static const featureBlueBg = Color(0xFFE3F0FC);
  static const featureBlue = Color(0xFF2767A5);
  static const featureCoralBg = Color(0xFFFFE9DE);
  static const featureCoral = Color(0xFFB4573A);
  static const featurePurpleBg = Color(0xFFEFE9FB);
  static const featurePurple = Color(0xFF7659C9);
}

/// 8pt grid spacing.
abstract final class LikhoSpace {
  static const double s1 = 8;
  static const double s2 = 16;
  static const double screenMargin = 24;
}

abstract final class LikhoSize {
  static const double kidTapMin = 64;
  static const double mainButton = 80;
}

abstract final class LikhoRadius {
  static const double button = 24;
  static const double card = 28;
  static const double writingPad = 32;
}

/// Fonts from the brief (Google Fonts).
abstract final class LikhoFonts {
  /// Titles and buttons.
  static TextStyle title({double size = 24, FontWeight weight = FontWeight.w700, Color color = LikhoColors.ink}) =>
      GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color, height: 1.1);

  /// Letters to trace and word tiles (the prototype uses Andika Bold).
  static TextStyle letter({double size = 96, Color color = LikhoColors.ink, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.andika(fontSize: size, color: color, fontWeight: weight);

  /// Illustration placeholders (prototype: ui-monospace, Menlo).
  static TextStyle placeholder({double size = 10, Color color = GameColors.ink60}) =>
      TextStyle(fontFamily: 'Menlo', fontFamilyFallback: const ['Courier', 'monospace'], fontSize: size, color: color, height: 1.3);

  /// Body copy on kid and account screens (the prototype's base font, Nunito).
  static TextStyle body({double size = 16, FontWeight weight = FontWeight.w600, Color color = LikhoColors.ink, double? height}) =>
      GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color, height: height);

  /// Parent screens.
  static TextStyle parent({double size = 16, FontWeight weight = FontWeight.w500, Color color = LikhoColors.ink}) =>
      GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color);
}

/// App theme built only from the tokens above: no ripples, no Material
/// shadows or default fonts.
ThemeData likhoTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: LikhoColors.primary,
      primary: LikhoColors.primary,
      onPrimary: LikhoColors.ink,
      secondary: LikhoColors.secondary,
      surface: LikhoColors.surface,
      onSurface: LikhoColors.ink,
    ),
    scaffoldBackgroundColor: LikhoColors.background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    hoverColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: GoogleFonts.baloo2TextTheme(base.textTheme).apply(bodyColor: LikhoColors.ink, displayColor: LikhoColors.ink),
    sliderTheme: const SliderThemeData(
      activeTrackColor: LikhoColors.primary,
      inactiveTrackColor: LikhoColors.surfaceSunk,
      thumbColor: LikhoColors.ink,
      overlayColor: Colors.transparent,
      trackHeight: 8,
    ),
  );
}
