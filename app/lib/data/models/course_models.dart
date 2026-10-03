import 'package:flutter/foundation.dart';

/// Course content, shaped exactly like the course API response
/// (schemaVersion 1). Today it is read from assets/data/course.json; later a
/// network repository returns the same JSON. See course_repository.dart.
///
/// Adding a level = adding JSON. Adding a new kind of game = a new [Round]
/// subclass + `type` string here + a view registered in round_views.dart.

@immutable
class Course {
  const Course({required this.schemaVersion, required this.id, required this.worlds, required this.levels, required this.glyphs, this.placement});

  final int schemaVersion;
  final String id;
  final List<CourseWorld> worlds;

  /// Map levels (number 1..n), in order.
  final List<CourseLevel> levels;

  /// The placement warm-up (number 0) played after adding a child. It has no
  /// world of its own, so it is played in the first world's colours.
  final CourseLevel? placement;

  /// Letter guide strokes, SVG path data in a 100 x 100 box (baseline y = 70).
  final Map<String, List<String>> glyphs;

  CourseLevel level(int number) => levels.firstWhere((l) => l.number == number);
  CourseWorld worldOf(CourseLevel l) => worlds.firstWhere((w) => w.id == l.worldId);
  List<CourseLevel> levelsOf(CourseWorld w) => levels.where((l) => l.worldId == w.id).toList();

  static const supportedSchema = 1;

  factory Course.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, r'$');
    final version = r.integer('schemaVersion');
    if (version > supportedSchema) {
      throw FormatException('Course schemaVersion $version is newer than this app supports ($supportedSchema)');
    }
    final allLevels = r.list('levels', (x, p) => CourseLevel.fromJson(x, p));
    final worlds = r.list('worlds', (x, p) => CourseWorld.fromJson(x, p));
    final placement = allLevels.where((l) => l.placement).firstOrNull;
    return Course(
      schemaVersion: version,
      id: r.string('courseId'),
      worlds: worlds,
      levels: allLevels.where((l) => !l.placement).toList()..sort((a, b) => a.number.compareTo(b.number)),
      placement: placement == null || placement.worldId != null || worlds.isEmpty ? placement : placement.inWorld(worlds.first.id),
      glyphs: r.map('glyphs', (v, p) => [for (final (i, s) in (v as List).indexed) _asString(s, '$p[$i]')]),
    );
  }
}

@immutable
class CourseWorld {
  const CourseWorld({required this.id, required this.order, required this.name, required this.skill, required this.icon, required this.themeId, required this.bossId, required this.bossName});

  final String id;
  final int order; // 1..n, bottom to top on the map
  final String name, skill;
  final String icon; // Material Symbols name, see IconRegistry
  final String themeId; // design token key, see LikhoWorlds.byId
  final String bossId; // snail | fish | bear | robotBus | cloud | moon
  final String bossName;

  factory CourseWorld.fromJson(Map<String, dynamic> json, String path) {
    final r = JsonReader(json, path);
    final boss = r.object('boss');
    return CourseWorld(
      id: r.string('id'),
      order: r.integer('order'),
      name: r.string('name'),
      skill: r.string('skill'),
      icon: r.string('icon'),
      themeId: r.string('themeId'),
      bossId: boss.string('id'),
      bossName: boss.string('name'),
    );
  }
}

@immutable
class CourseLevel {
  const CourseLevel({
    required this.id,
    required this.number,
    required this.worldId,
    required this.placement,
    required this.name,
    required this.skill,
    required this.icon,
    required this.isBoss,
    required this.requiresSubscription,
    required this.intro,
    required this.presentation,
    required this.rounds,
  });

  final String id;
  final int number;
  final String? worldId;
  final bool placement;
  final String name, skill, icon;
  final bool isBoss;
  final bool requiresSubscription;
  final LevelIntro intro;
  final Presentation presentation;

  /// Rounds this app can play (unknown future types are dropped).
  final List<Round> rounds;

  /// The same level shown in world [id]'s colours.
  CourseLevel inWorld(String id) => CourseLevel(
        id: this.id,
        number: number,
        worldId: id,
        placement: placement,
        name: name,
        skill: skill,
        icon: icon,
        isBoss: isBoss,
        requiresSubscription: requiresSubscription,
        intro: intro,
        presentation: presentation,
        rounds: rounds,
      );

  factory CourseLevel.fromJson(Map<String, dynamic> json, String path) {
    final r = JsonReader(json, path);
    return CourseLevel(
      id: r.string('id'),
      number: r.integer('number'),
      worldId: r.optString('worldId'),
      placement: r.optBool('placement'),
      name: r.string('name'),
      skill: r.string('skill'),
      icon: r.string('icon'),
      isBoss: r.optBool('isBoss'),
      requiresSubscription: r.optBool('requiresSubscription'),
      intro: LevelIntro.fromJson(r.object('intro')),
      presentation: Presentation.fromJson(r.object('presentation')),
      rounds: r.list('rounds', Round.fromJson).where((x) => x is! UnknownRound).toList(),
    );
  }
}

@immutable
class LevelIntro {
  const LevelIntro({required this.text, required this.word, this.picture, this.say, this.audio});
  final String text; // big letters on the intro card, e.g. "B" or "c-a-t"
  final String word; // what the illustration shows, e.g. "balloon"
  final Picture? picture;

  /// What Pencil says while the intro shows ("B! B is for balloon."), with
  /// its recording ([audio], an asset path or URL).
  final String? say, audio;

  factory LevelIntro.fromJson(JsonReader r) => LevelIntro(
    text: r.optString('text') ?? '',
    word: r.optString('word') ?? '',
    picture: r.optPicture('picture'),
    say: r.optString('say'),
    audio: r.optString('audio'),
  );
}

/// Spoken words as the device voice should read them: a pronunciation
/// written {shown|IPA} (for recordings) becomes its shown part.
String spokenText(String words) => words.replaceAllMapped(RegExp(r'\{([^{}|]+)\|[^{}|]+\}'), (m) => m[1]!);

/// How a level looks. Each field is optional; views fall back to defaults.
@immutable
class Presentation {
  const Presentation({this.shape, this.slot, this.pad, this.layout, this.stage});

  /// pick items: balloon, bubble, kite, fish, mushroom, shell, pad, basket,
  /// jar, bucket, card (default), cloud, planet
  final String? shape;

  /// order slots: wagon (default), plank, stripe, panel
  final String? slot;

  /// writing pad: paper (default), track, road, sand
  final String? pad;

  /// pick layout: field (default), patient, flow, alien
  final String? layout;

  /// pick stage above the field: house, count, stars
  final String? stage;

  factory Presentation.fromJson(JsonReader r) => Presentation(
        shape: r.optString('shape'),
        slot: r.optString('slot'),
        pad: r.optString('pad'),
        layout: r.optString('layout'),
        stage: r.optString('stage'),
      );
}

/// An illustration. [key] finds a bundled image (`assets/illustrations/<key>.png`),
/// [url] a remote one; with neither, the prototype's labelled placeholder shows.
@immutable
class Picture {
  const Picture({required this.key, required this.label, this.url});
  final String key, label;
  final String? url;

  factory Picture.fromJson(JsonReader r) => Picture(key: r.string('key'), label: r.optString('label') ?? r.string('key'), url: r.optString('url'));
}

/// What the mascot says. [audio] is an asset path or URL of a recording;
/// without one the device voice reads [say] (when the words on screen are
/// not what to say, e.g. "/b/") or [text].
@immutable
class Prompt {
  const Prompt({required this.text, this.say, this.audio});
  final String text;
  final String? say, audio;

  /// What the device voice reads when there is no recording.
  String get spoken => spokenText(say ?? text);

  factory Prompt.fromJson(JsonReader r) => Prompt(text: r.string('text'), say: r.optString('say'), audio: r.optString('audio'));
}

/// The white card next to the mascot.
@immutable
class PromptCard {
  const PromptCard({this.text, this.picture, this.listen = false});
  final String? text;
  final Picture? picture;
  final bool listen;

  factory PromptCard.fromJson(JsonReader r) => PromptCard(text: r.optString('text'), picture: r.optPicture('picture'), listen: r.optBool('listen'));
}

// ------------------------------------------------------------------ rounds

sealed class Round {
  const Round({required this.id, required this.prompt, this.card});
  final String id;
  final Prompt prompt;
  final PromptCard? card;

  String get type;

  static Round fromJson(Map<String, dynamic> json, String path) {
    final r = JsonReader(json, path);
    final id = r.string('id');
    final prompt = Prompt.fromJson(r.object('prompt'));
    final card = r.has('card') ? PromptCard.fromJson(r.object('card')) : null;
    switch (r.string('type')) {
      case 'pick':
        final p = r.object('pick');
        final answer = p.object('answer');
        return PickRound(
          id: id,
          prompt: prompt,
          card: card,
          options: p.list('options', (x, q) => PickOption.fromJson(JsonReader(x, q))),
          answer: answer.string('kind') == 'any' ? null : answer.string('value'),
          shape: p.optString('shape'),
          layout: p.optString('layout'),
          count: p.optInt('count'),
          choiceKey: p.optString('choiceKey'),
          fixCapital: p.optBool('fixCapital'),
        );
      case 'write':
        final w = r.object('write');
        return WriteRound(
          id: id,
          prompt: prompt,
          card: card,
          mode: WriteMode.parse(w.string('mode'), w.path),
          target: w.optString('target'),
          guide: w.optString('guide'),
          word: w.optString('word'),
          missingIndex: w.optInt('missingIndex'),
          sentence: w.optBool('sentence'),
          story: w.optBool('story'),
        );
      case 'order':
        final o = r.object('order');
        return OrderRound(id: id, prompt: prompt, card: card, tiles: o.strings('tiles'));
      case 'speak':
        return SpeakRound(id: id, prompt: prompt, card: card);
      default:
        return UnknownRound(id: id, prompt: prompt, card: card, rawType: r.string('type'));
    }
  }
}

/// Tap the right thing.
final class PickRound extends Round {
  const PickRound({
    required super.id,
    required super.prompt,
    super.card,
    required this.options,
    required this.answer,
    this.shape,
    this.layout,
    this.count,
    this.choiceKey,
    this.fixCapital = false,
  });

  final List<PickOption> options;

  /// Label of the correct option; null = any option is right (story choices).
  final String? answer;
  final String? shape, layout; // override the level's presentation
  final int? count; // cupcakes shown on the "count" stage
  final String? choiceKey; // remembers the pick (e.g. "who" in My Story)
  final bool fixCapital; // Fix-It: the picked word gets a capital letter

  bool isCorrect(PickOption o) => answer == null || o.label == answer;

  @override
  String get type => 'pick';
}

@immutable
class PickOption {
  const PickOption({required this.id, required this.label, this.picture, this.color, this.hideLabel = false});
  final String id, label;
  final Picture? picture;
  final String? color; // named content colour (red, blue, …), see ContentColors
  final bool hideLabel;

  factory PickOption.fromJson(JsonReader r) => PickOption(
        id: r.string('id'),
        label: r.string('label'),
        picture: r.optPicture('picture'),
        color: r.optString('color'),
        hideLabel: r.optBool('hideLabel'),
      );
}

enum WriteMode {
  trace, // follow the guide strokes
  dots, // join the numbered dots
  free, // write it yourself (letters or sentences)
  missing, // fill the missing letter in a word
  spell; // write a word letter by letter

  static WriteMode parse(String v, String path) =>
      WriteMode.values.firstWhere((m) => m.name == v, orElse: () => throw FormatException('Unknown write mode "$v" at $path'));
}

/// Handwriting.
final class WriteRound extends Round {
  const WriteRound({
    required super.id,
    required super.prompt,
    super.card,
    required this.mode,
    this.target,
    this.guide,
    this.word,
    this.missingIndex,
    this.sentence = false,
    this.story = false,
  });

  final WriteMode mode;
  final String? target; // what to write (letter, word or sentence)
  final String? guide; // key into Course.glyphs for trace / dots
  final String? word; // letter boxes for missing / spell
  final int? missingIndex;
  final bool sentence, story;

  @override
  String get type => 'write';
}

/// Put tiles in order.
final class OrderRound extends Round {
  const OrderRound({required super.id, required super.prompt, super.card, required this.tiles});
  final List<String> tiles; // in the correct order

  @override
  String get type => 'order';
}

/// Say something out loud.
final class SpeakRound extends Round {
  const SpeakRound({required super.id, required super.prompt, super.card});

  @override
  String get type => 'speak';
}

/// A round type this app version does not know yet. Dropped from play.
final class UnknownRound extends Round {
  const UnknownRound({required super.id, required super.prompt, super.card, required this.rawType});
  final String rawType;

  @override
  String get type => rawType;
}

// ------------------------------------------------------------------ parsing

String _asString(Object? v, String path) => v is String ? v : throw FormatException('Expected a string at $path');

/// Small typed JSON reader that reports the path of any bad field
/// (e.g. `$.levels[3].rounds[1].pick.answer`).
class JsonReader {
  JsonReader(this.json, this.path);
  final Map<String, dynamic> json;
  final String path;

  bool has(String k) => json[k] != null;

  Never _bad(String k, String want) => throw FormatException('Expected $want at $path.$k, got ${json[k]}');

  String string(String k) => json[k] is String ? json[k] as String : _bad(k, 'a string');
  String? optString(String k) => json[k] == null ? null : string(k);
  int integer(String k) => json[k] is int ? json[k] as int : _bad(k, 'an integer');
  int? optInt(String k) => json[k] == null ? null : integer(k);
  bool optBool(String k) => json[k] == null ? false : (json[k] is bool ? json[k] as bool : _bad(k, 'a boolean'));

  JsonReader object(String k) => json[k] is Map<String, dynamic> ? JsonReader(json[k] as Map<String, dynamic>, '$path.$k') : _bad(k, 'an object');

  Picture? optPicture(String k) => json[k] == null ? null : Picture.fromJson(object(k));

  List<T> list<T>(String k, T Function(Map<String, dynamic> item, String path) f) {
    final v = json[k];
    if (v is! List) _bad(k, 'a list');
    return [
      for (final (i, x) in v.indexed)
        x is Map<String, dynamic> ? f(x, '$path.$k[$i]') : throw FormatException('Expected an object at $path.$k[$i]'),
    ];
  }

  List<String> strings(String k) {
    final v = json[k];
    if (v is! List) _bad(k, 'a list');
    return [for (final (i, x) in v.indexed) _asString(x, '$path.$k[$i]')];
  }

  Map<String, T> map<T>(String k, T Function(Object? v, String path) f) {
    final v = json[k];
    if (v is! Map<String, dynamic>) _bad(k, 'an object');
    return {for (final e in v.entries) e.key: f(e.value, '$path.$k.${e.key}')};
  }
}
