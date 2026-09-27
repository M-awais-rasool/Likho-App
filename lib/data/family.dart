import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import 'shop_items.dart';

/// One child on the parent account (prototype `profiles`).
@immutable
class ChildProfile {
  const ChildProfile({required this.id, required this.name, required this.age, required this.color});

  final String id;
  final String name;
  final int age; // 5..8

  /// Pencil colour: the key of one of [BodySwatch.options].
  final Color color;

  BodySwatch get swatch => BodySwatch.forColor(color);

  ChildProfile copyWith({String? name, int? age, Color? color}) =>
      ChildProfile(id: id, name: name ?? this.name, age: age ?? this.age, color: color ?? this.color);
}

/// What one child has played and bought (prototype `data[id]`).
@immutable
class ChildRecord {
  const ChildRecord({this.stars = 0, this.levelStars = const {}, this.owned = const {}, this.wearing, this.room = const {}, this.days = 1, this.minutes = 0});

  final int stars;
  final Map<int, int> levelStars; // level number -> best stars (1..3)
  final Set<String> owned; // shop item ids
  final String? wearing; // shop item id of the accessory Pencil wears
  final Set<String> room; // room item ids placed in the room
  final int days; // days played
  final int minutes; // practice minutes this week

  ChildRecord copyWith({int? stars, Map<int, int>? levelStars, Set<String>? owned, String? Function()? wearing, Set<String>? room, int? days, int? minutes}) =>
      ChildRecord(
        stars: stars ?? this.stars,
        levelStars: levelStars ?? this.levelStars,
        owned: owned ?? this.owned,
        wearing: wearing != null ? wearing() : this.wearing,
        room: room ?? this.room,
        days: days ?? this.days,
        minutes: minutes ?? this.minutes,
      );

  bool isDone(int n) => levelStars.containsKey(n);
}

/// Parent settings (prototype `settings`).
@immutable
class AppSettings {
  const AppSettings({this.sessionMinutes = 10, this.music = true, this.sfx = true, this.haptics = true, this.leftHanded = false, this.reduceMotion = false});

  final int sessionMinutes; // 5, 10 or 15
  final bool music, sfx, leftHanded, reduceMotion;

  /// Vibration feedback (answers, rewards, celebrations).
  final bool haptics;

  static const sessionOptions = [5, 10, 15];

  /// Levels per play session before "Aaj ke liye bas!" (prototype lim).
  int get levelsPerSession => switch (sessionMinutes) {
    5 => 2,
    15 => 4,
    _ => 3,
  };

  AppSettings copyWith({int? sessionMinutes, bool? music, bool? sfx, bool? haptics, bool? leftHanded, bool? reduceMotion}) => AppSettings(
    sessionMinutes: sessionMinutes ?? this.sessionMinutes,
    music: music ?? this.music,
    sfx: sfx ?? this.sfx,
    haptics: haptics ?? this.haptics,
    leftHanded: leftHanded ?? this.leftHanded,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );
}

/// Everything on the parent account: children, their progress, settings
/// and the subscription.
@immutable
class FamilyState {
  const FamilyState({required this.profiles, required this.activeId, required this.records, this.settings = const AppSettings(), this.subscribed = false});

  final List<ChildProfile> profiles;
  final String activeId;
  final Map<String, ChildRecord> records;
  final AppSettings settings;
  final bool subscribed; // Likho Plus (trial or paid)

  static const maxProfiles = 4;

  ChildProfile get active => profiles.firstWhere((p) => p.id == activeId, orElse: () => profiles.first);
  ChildRecord get record => records[active.id] ?? const ChildRecord();
  ChildRecord recordOf(String id) => records[id] ?? const ChildRecord();
  bool get canAddChild => profiles.length < maxProfiles;

  FamilyState copyWith({List<ChildProfile>? profiles, String? activeId, Map<String, ChildRecord>? records, AppSettings? settings, bool? subscribed}) =>
      FamilyState(
        profiles: profiles ?? this.profiles,
        activeId: activeId ?? this.activeId,
        records: records ?? this.records,
        settings: settings ?? this.settings,
        subscribed: subscribed ?? this.subscribed,
      );
}

/// Result of finishing a level, for the Level Complete screen.
@immutable
class LevelOutcome {
  const LevelOutcome({required this.level, required this.stars, required this.gain, required this.firstTime, this.choices = const {}});
  final int level;
  final int stars;
  final int gain; // stars added to the child's total
  final bool firstTime;
  final Map<String, String> choices; // story picks (My Story)
}

/// Demo data until accounts and saving exist: the prototype's two children.
/// Ayaan: 38 stars, levels 1–7 done, owns the lamp. (The prototype also has
/// him wearing a beanie; the Gemini accessory set has no beanie, so he
/// wears nothing.) Zara: 6 stars, level 1 done.
class FamilyNotifier extends Notifier<FamilyState> {
  @override
  FamilyState build() => FamilyState(
    profiles: [
      const ChildProfile(id: 'p1', name: 'Ayaan', age: 6, color: LikhoColors.primary),
      ChildProfile(id: 'p2', name: 'Zara', age: 5, color: BodySwatch.options[4].key), // purple
    ],
    activeId: 'p1',
    records: const {
      'p1': ChildRecord(stars: 38, levelStars: {1: 3, 2: 2, 3: 3, 4: 2, 5: 3, 6: 3, 7: 2}, owned: {'lamp'}, room: {'lamp'}, days: 4, minutes: 42),
      'p2': ChildRecord(stars: 6, levelStars: {1: 2}, days: 1, minutes: 9),
    },
  );

  void _updateRecord(ChildRecord Function(ChildRecord r) f) {
    final id = state.active.id;
    state = state.copyWith(records: {...state.records, id: f(state.recordOf(id))});
  }

  void selectChild(String id) => state = state.copyWith(activeId: id);

  /// Adds a child (up to 4) and makes it the active one.
  void addChild({required String name, required int age, required Color color}) {
    if (!state.canAddChild) return;
    final id = 'p${DateTime.now().microsecondsSinceEpoch}';
    state = state.copyWith(
      profiles: [
        ...state.profiles,
        ChildProfile(id: id, name: name.trim(), age: age, color: color),
      ],
      activeId: id,
      records: {...state.records, id: const ChildRecord()},
    );
  }

  void editActive({required String name, int? age, required Color color}) {
    final id = state.active.id;
    state = state.copyWith(
      profiles: [for (final p in state.profiles) p.id == id ? p.copyWith(name: name.trim(), age: age, color: color) : p],
    );
  }

  /// Deletes the active child (never the last one) and selects the first.
  void deleteActive() {
    final rest = state.profiles.where((p) => p.id != state.activeId).toList();
    if (rest.isEmpty) return;
    state = state.copyWith(profiles: rest, activeId: rest.first.id, records: {...state.records}..remove(state.activeId));
  }

  /// A level was finished (prototype finish()): keep the best stars; the
  /// child earns the extra stars, plus 2 for a first-time finish, and 3
  /// practice minutes.
  LevelOutcome recordResult(int level, int stars, {Map<String, String> choices = const {}}) {
    final old = state.record.levelStars[level];
    final gain = math.max(0, stars - (old ?? 0)) + (old == null ? 2 : 0);
    _updateRecord((r) => r.copyWith(stars: r.stars + gain, levelStars: {...r.levelStars, level: math.max(stars, old ?? 0)}, minutes: r.minutes + 3));
    return LevelOutcome(level: level, stars: stars, gain: gain, firstTime: old == null, choices: choices);
  }

  /// Mascot room: buy, wear/take off, place/remove (prototype tapItem).
  /// Returns false when the child cannot afford [item].
  bool tapItem(ShopItem item) {
    final r = state.record;
    if (!r.owned.contains(item.id)) {
      if (r.stars < item.price) return false;
      _updateRecord(
        (r) => r.copyWith(
          stars: r.stars - item.price,
          owned: {...r.owned, item.id},
          wearing: item.isWear ? () => item.id : null,
          room: item.isWear ? null : {...r.room, item.id},
        ),
      );
      return true;
    }
    if (item.isWear) {
      _updateRecord((r) => r.copyWith(wearing: () => r.wearing == item.id ? null : item.id));
    } else {
      _updateRecord((r) => r.copyWith(room: r.room.contains(item.id) ? ({...r.room}..remove(item.id)) : {...r.room, item.id}));
    }
    return true;
  }

  void subscribe() => state = state.copyWith(subscribed: true);

  void updateSettings(AppSettings Function(AppSettings s) f) => state = state.copyWith(settings: f(state.settings));
}

final familyProvider = NotifierProvider<FamilyNotifier, FamilyState>(FamilyNotifier.new);

/// Levels played since a child was picked (prototype sessionDone / sessionStars).
@immutable
class PlaySession {
  const PlaySession({this.levels = 0, this.stars = 0, this.newSticker});
  final int levels, stars;
  final int? newSticker; // level whose sticker was just earned (Sticker Book pops it in)
}

class PlaySessionNotifier extends Notifier<PlaySession> {
  @override
  PlaySession build() => const PlaySession();

  void reset() => state = const PlaySession();

  void finished(LevelOutcome o) =>
      state = PlaySession(levels: state.levels + 1, stars: state.stars + o.stars, newSticker: o.firstTime ? o.level : state.newSticker);

  void stickerSeen() => state = PlaySession(levels: state.levels, stars: state.stars);
}

final playSessionProvider = NotifierProvider<PlaySessionNotifier, PlaySession>(PlaySessionNotifier.new);
