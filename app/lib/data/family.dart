import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import 'api/api_client.dart';
import 'api/likho_api.dart';
import 'auth.dart';
import 'course_providers.dart';
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

  /// Stands in while an account has no child yet.
  static const none = ChildProfile(id: '', name: '', age: 6, color: LikhoColors.primary);
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

  /// Levels per play session before "That's all for today!" (prototype lim).
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

  Map<String, dynamic> toJson() => {
    'sessionMinutes': sessionMinutes,
    'music': music,
    'sfx': sfx,
    'haptics': haptics,
    'leftHanded': leftHanded,
    'reduceMotion': reduceMotion,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    sessionMinutes: (j['sessionMinutes'] as num?)?.toInt() ?? 10,
    music: j['music'] as bool? ?? true,
    sfx: j['sfx'] as bool? ?? true,
    haptics: j['haptics'] as bool? ?? true,
    leftHanded: j['leftHanded'] as bool? ?? false,
    reduceMotion: j['reduceMotion'] as bool? ?? false,
  );
}

/// The signed-in parent.
@immutable
class Account {
  const Account({required this.id, required this.email, this.name = '', this.pictureUrl = '', this.tester = false});
  final String id, email, name, pictureUrl;

  /// A test account: every level is open (set on the server).
  final bool tester;
}

/// Where the family's data lives.
enum FamilyMode {
  /// Signed in: the server keeps it; every change is sent to the API.
  online,

  /// "Try it first" without an account: kept only on the phone.
  guest,

  /// Sample data for tests and the dev tools (never sent anywhere).
  demo,
}

/// Everything on the parent account: children, their progress, settings
/// and the subscription.
@immutable
class FamilyState {
  const FamilyState({
    required this.profiles,
    required this.activeId,
    required this.records,
    this.settings = const AppSettings(),
    this.subscribed = false,
    this.plusPlan,
    this.plusUntil,
    this.plusRenews = false,
    this.plusStore,
    this.plusTrial = false,
    this.storeAccountId = '',
    this.account,
    this.mode = FamilyMode.demo,
  });

  final List<ChildProfile> profiles;
  final String activeId;
  final Map<String, ChildRecord> records;
  final AppSettings settings;
  final bool subscribed; // Likho Plus (trial or paid)

  /// The Google Play plan behind Likho Plus ("monthly" / "yearly"), or null
  /// (a trial, a grant, or no Plus).
  final String? plusPlan;

  /// When Likho Plus ends (or renews) and whether the store renews it; the
  /// store ("google_play") or null (a trial or a grant).
  final DateTime? plusUntil;
  final bool plusRenews;
  final String? plusStore;

  /// Likho Plus comes from a free trial right now (the server's or Google
  /// Play's): the trial may open fewer levels (App controls).
  final bool plusTrial;

  /// The account's ID for the store (the server's hash), sent with a purchase.
  final String storeAccountId;
  final Account? account;
  final FamilyMode mode;

  static const maxProfiles = 4;

  bool get online => mode == FamilyMode.online;
  bool get guest => mode == FamilyMode.guest;

  ChildProfile get active => profiles.isEmpty ? ChildProfile.none : profiles.firstWhere((p) => p.id == activeId, orElse: () => profiles.first);
  ChildRecord get record => records[active.id] ?? const ChildRecord();
  ChildRecord recordOf(String id) => records[id] ?? const ChildRecord();
  bool get canAddChild => profiles.length < maxProfiles;

  FamilyState copyWith({List<ChildProfile>? profiles, String? activeId, Map<String, ChildRecord>? records, AppSettings? settings, bool? subscribed, bool? plusTrial}) =>
      FamilyState(
        profiles: profiles ?? this.profiles,
        activeId: activeId ?? this.activeId,
        records: records ?? this.records,
        settings: settings ?? this.settings,
        subscribed: subscribed ?? this.subscribed,
        plusPlan: plusPlan,
        plusUntil: plusUntil,
        plusRenews: plusRenews,
        plusStore: plusStore,
        plusTrial: plusTrial ?? this.plusTrial,
        storeAccountId: storeAccountId,
        account: account,
        mode: mode,
      );

  /// The account as GET /v1/me returns it.
  factory FamilyState.fromMe(Map<String, dynamic> me, {String? activeId}) {
    final acc = (me['account'] as Map).cast<String, dynamic>();
    final kids = [for (final c in (me['children'] as List? ?? const [])) (c as Map).cast<String, dynamic>()];
    final ids = [for (final c in kids) c['id'] as String];
    return FamilyState(
      profiles: [for (final c in kids) childProfileFromJson(c)],
      activeId: activeId != null && ids.contains(activeId) ? activeId : (ids.isEmpty ? '' : ids.first),
      records: {for (final c in kids) c['id'] as String: childRecordFromJson(c)},
      settings: AppSettings.fromJson((me['settings'] as Map).cast<String, dynamic>()),
      subscribed: (me['subscription'] as Map?)?['active'] == true,
      plusPlan: (me['subscription'] as Map?)?['active'] == true ? (me['subscription'] as Map)['plan'] as String? : null,
      plusUntil: DateTime.tryParse((me['subscription'] as Map?)?['plusUntil'] as String? ?? '')?.toLocal(),
      plusRenews: (me['subscription'] as Map?)?['autoRenewing'] == true,
      plusStore: (me['subscription'] as Map?)?['active'] == true ? (me['subscription'] as Map)['store'] as String? : null,
      plusTrial: (me['subscription'] as Map?)?['active'] == true && (me['subscription'] as Map)['trial'] == true,
      storeAccountId: (me['subscription'] as Map?)?['storeAccountId'] as String? ?? '',
      account: Account(
        id: acc['id'] as String,
        email: acc['email'] as String? ?? '',
        name: acc['name'] as String? ?? '',
        pictureUrl: acc['pictureUrl'] as String? ?? '',
        tester: acc['tester'] == true,
      ),
      mode: FamilyMode.online,
    );
  }

  /// Trying the app before signing in: one child, nothing saved.
  factory FamilyState.guest() => const FamilyState(
    profiles: [ChildProfile(id: 'guest', name: 'Friend', age: 6, color: LikhoColors.primary)],
    activeId: 'guest',
    records: {'guest': ChildRecord()},
    mode: FamilyMode.guest,
  );

  /// The prototype's sample family (tests, dev tools). Ayaan: 38 stars,
  /// levels 1–7 done, owns the lamp. Zara: 6 stars, level 1 done.
  factory FamilyState.demo() => FamilyState(
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
}

/// '#FFC83D' <-> Color, as the API sends colours.
String colorToHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Color colorFromHex(String hex) => Color(0xFF000000 | int.parse(hex.replaceFirst('#', ''), radix: 16));

ChildProfile childProfileFromJson(Map<String, dynamic> c) =>
    ChildProfile(id: c['id'] as String, name: c['name'] as String, age: (c['age'] as num).toInt(), color: colorFromHex(c['color'] as String));

/// A child as the API sends it; [courseId] picks the course whose progress
/// the map shows (progress is kept per course).
ChildRecord childRecordFromJson(Map<String, dynamic> c, {String courseId = appCourseId}) => ChildRecord(
  stars: (c['stars'] as num?)?.toInt() ?? 0,
  levelStars: {
    for (final e in ((((c['progress'] as Map?)?[courseId] as Map?)?['levelStars'] as Map?) ?? const {}).entries)
      int.parse(e.key as String): (e.value as num).toInt(),
  },
  owned: {for (final i in (c['owned'] as List? ?? const [])) i as String},
  wearing: c['wearing'] as String?,
  room: {for (final i in (c['room'] as List? ?? const [])) i as String},
  days: (c['daysPlayed'] as num?)?.toInt() ?? 0,
  minutes: (c['minutesThisWeek'] as num?)?.toInt() ?? 0,
);

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

/// A finished level waiting to reach the server (kept on the phone, so no
/// progress is lost offline; the key makes a resend count once).
@immutable
class PendingResult {
  const PendingResult({required this.key, required this.childId, this.courseId = appCourseId, required this.level, required this.stars, required this.seconds});
  final String key, childId, courseId;
  final int level, stars, seconds;

  Map<String, dynamic> toJson() => {'key': key, 'childId': childId, 'courseId': courseId, 'level': level, 'stars': stars, 'seconds': seconds};
  factory PendingResult.fromJson(Map<String, dynamic> j) => PendingResult(
    key: j['key'] as String,
    childId: j['childId'] as String,
    courseId: j['courseId'] as String? ?? appCourseId,
    level: (j['level'] as num).toInt(),
    stars: (j['stars'] as num).toInt(),
    seconds: (j['seconds'] as num).toInt(),
  );
}

/// The family, as the screens see it. Changes show at once (the same rules
/// as the server) and, when signed in, are sent to the API; the server's
/// answer then corrects the numbers if anything differs. A change the
/// server refuses is undone and explained with a message
/// (syncMessageProvider).
class FamilyNotifier extends Notifier<FamilyState> {
  static const outboxFile = 'pending_results.json';

  final List<PendingResult> _outbox = [];
  bool _flushing = false;
  DateTime _loadedAt = DateTime.now(); // when the account last came from the server

  LikhoApi get _api => ref.read(apiProvider);

  @override
  FamilyState build() {
    final auth = ref.watch(authProvider);
    if (auth.signedIn && auth.me != null) {
      Future.microtask(_loadOutbox);
      _loadedAt = DateTime.now();
      return FamilyState.fromMe(auth.me!);
    }
    return FamilyState.guest();
  }

  void _say(String message) => ref.read(syncMessageProvider.notifier).show(message);

  void _update(String childId, ChildRecord Function(ChildRecord r) f) =>
      state = state.copyWith(records: {...state.records, childId: f(state.recordOf(childId))});

  void selectChild(String id) => state = state.copyWith(activeId: id);

  /// Reloads the whole account from the server (after a refused change).
  Future<void> refreshMe() async {
    if (!state.online) return;
    try {
      final me = await _api.me();
      if (!ref.mounted) return;
      await MeSnapshot.save(ref.read(localFilesProvider), me);
      if (!ref.mounted) return;
      state = FamilyState.fromMe(me, activeId: state.activeId);
      _loadedAt = DateTime.now();
      _applyPendingLocally();
    } on ApiException catch (e) {
      debugPrint('refreshMe: $e');
    }
  }

  /// The app is back in front: sends the results still waiting and, when
  /// the account came from the server a while ago (or on another day),
  /// reloads it. So changes made meanwhile show (e.g. Likho Plus given by
  /// the team), and the server knows the family used the app today.
  Future<void> resumed({DateTime? now}) async {
    await flush();
    if (!ref.mounted || !state.online) return;
    now ??= DateTime.now();
    final sameDay = now.year == _loadedAt.year && now.month == _loadedAt.month && now.day == _loadedAt.day;
    if (sameDay && now.difference(_loadedAt) < const Duration(minutes: 30)) return;
    await refreshMe();
  }

  // ------------------------------------------------------------ children

  /// Adds a child (up to 4) and makes it the active one. Throws
  /// [ApiException] when the server cannot save it.
  Future<void> addChild({required String name, required int age, required Color color}) async {
    if (!state.canAddChild) return;
    if (state.online) {
      final c = await _api.createChild(name: name.trim(), age: age, color: colorToHex(color));
      if (!ref.mounted) return;
      state = state.copyWith(
        profiles: [...state.profiles, childProfileFromJson(c)],
        activeId: c['id'] as String,
        records: {...state.records, c['id'] as String: childRecordFromJson(c)},
      );
      return;
    }
    final id = 'p${DateTime.now().microsecondsSinceEpoch}';
    state = state.copyWith(
      profiles: [...state.profiles, ChildProfile(id: id, name: name.trim(), age: age, color: color)],
      activeId: id,
      records: {...state.records, id: const ChildRecord()},
    );
  }

  Future<void> editActive({required String name, int? age, required Color color}) async {
    final id = state.active.id;
    if (state.online) {
      final c = await _api.updateChild(id, name: name.trim(), age: age, color: colorToHex(color));
      if (!ref.mounted) return;
      state = state.copyWith(profiles: [for (final p in state.profiles) p.id == id ? childProfileFromJson(c) : p]);
      return;
    }
    state = state.copyWith(profiles: [for (final p in state.profiles) p.id == id ? p.copyWith(name: name.trim(), age: age, color: color) : p]);
  }

  /// Deletes the active child (never the last one) and selects the first.
  Future<void> deleteActive() async {
    final id = state.activeId;
    final rest = state.profiles.where((p) => p.id != id).toList();
    if (rest.isEmpty) return;
    if (state.online) await _api.deleteChild(id);
    if (!ref.mounted) return;
    state = state.copyWith(profiles: rest, activeId: rest.first.id, records: {...state.records}..remove(id));
  }

  // ------------------------------------------------------------ progress

  /// A level was finished (prototype finish()): keep the best stars; the
  /// child earns the extra stars, plus 2 for a first-time finish. Shown at
  /// once; when signed in it is queued and sent to the server.
  LevelOutcome recordResult(int level, int stars, {Map<String, String> choices = const {}, int seconds = 180}) {
    final childId = state.active.id;
    final old = state.recordOf(childId).levelStars[level];
    final gain = math.max(0, stars - (old ?? 0)) + (old == null ? 2 : 0);
    _update(
      childId,
      (r) => r.copyWith(stars: r.stars + gain, levelStars: {...r.levelStars, level: math.max(stars, old ?? 0)}, minutes: r.minutes + (seconds / 60).ceil()),
    );
    if (state.online) {
      _outbox.add(PendingResult(key: _newKey(), childId: childId, level: level, stars: stars, seconds: seconds));
      unawaited(_saveOutbox().then((_) => flush()));
    }
    return LevelOutcome(level: level, stars: stars, gain: gain, firstTime: old == null, choices: choices);
  }

  /// Sends queued results, oldest first. Stops at the first connection
  /// problem (tried again later: next result, app resume, sign-in).
  Future<void> flush() async {
    if (!ref.mounted || _flushing || !state.online) return;
    _flushing = true;
    var resync = false;
    final totals = <String, Map<String, dynamic>>{};
    try {
      while (_outbox.isNotEmpty) {
        final p = _outbox.first;
        try {
          final o = await _api.recordResult(p.childId, courseId: p.courseId, level: p.level, stars: p.stars, seconds: p.seconds, key: p.key);
          if (!ref.mounted) return;
          totals[p.childId] = o;
          _outbox.removeAt(0);
        } on ApiException catch (e) {
          if (!ref.mounted || !e.rejected) break;
          _outbox.removeAt(0); // the server said no (e.g. locked level): fix up from its data
          resync = true;
        }
        await _saveOutbox();
        if (!ref.mounted) return;
      }
    } finally {
      _flushing = false;
    }
    if (!ref.mounted) return;
    // the server's totals win once a child has nothing left in the queue
    for (final MapEntry(key: id, value: o) in totals.entries) {
      if (_outbox.any((p) => p.childId == id) || o['courseId'] != appCourseId) continue;
      _update(id, (r) => r.copyWith(stars: (o['totalStars'] as num).toInt(), levelStars: {...r.levelStars, (o['level'] as num).toInt(): (o['bestStars'] as num).toInt()}));
    }
    if (resync) await refreshMe();
  }

  /// Sends finished levels still waiting, then signs the parent out.
  Future<void> logOut() async {
    await flush();
    await ref.read(authProvider.notifier).logOut();
  }

  Future<void> _loadOutbox() async {
    final text = await ref.read(localFilesProvider).read(outboxFile);
    if (text == null || !ref.mounted) return;
    try {
      final items = [for (final j in jsonDecode(text) as List) PendingResult.fromJson((j as Map).cast<String, dynamic>())];
      final known = {for (final p in _outbox) p.key};
      _outbox.addAll(items.where((p) => !known.contains(p.key)));
      _applyPendingLocally();
      await flush();
    } catch (e) {
      debugPrint('outbox: $e');
    }
  }

  /// Unsent results still count on the phone (offline start).
  void _applyPendingLocally() {
    for (final p in _outbox.where((p) => p.courseId == appCourseId)) {
      final old = state.recordOf(p.childId).levelStars[p.level];
      if (old != null && old >= p.stars) continue;
      final gain = math.max(0, p.stars - (old ?? 0)) + (old == null ? 2 : 0);
      _update(p.childId, (r) => r.copyWith(stars: r.stars + gain, levelStars: {...r.levelStars, p.level: p.stars}));
    }
  }

  Future<void> _saveOutbox() => ref.read(localFilesProvider).write(outboxFile, jsonEncode([for (final p in _outbox) p.toJson()]));

  static final math.Random _rnd = math.Random.secure();
  static String _newKey() => List.generate(16, (_) => _rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  // ------------------------------------------------------------ room

  /// Mascot room: buy, wear/take off, place/remove (prototype tapItem).
  /// Returns false when the child cannot afford [item]. The room changes at
  /// once; the server then confirms it (and spends the stars).
  bool tapItem(ShopItem item) {
    final childId = state.active.id;
    final before = state.recordOf(childId);
    final r = before;
    if (!r.owned.contains(item.id)) {
      if (r.stars < item.price) return false;
      _update(
        childId,
        (r) => r.copyWith(
          stars: r.stars - item.price,
          owned: {...r.owned, item.id},
          wearing: item.isWear ? () => item.id : null,
          room: item.isWear ? null : {...r.room, item.id},
        ),
      );
    } else if (item.isWear) {
      _update(childId, (r) => r.copyWith(wearing: () => r.wearing == item.id ? null : item.id));
    } else {
      _update(childId, (r) => r.copyWith(room: r.room.contains(item.id) ? ({...r.room}..remove(item.id)) : {...r.room, item.id}));
    }
    if (state.online) unawaited(_syncItem(childId, item, before));
    return true;
  }

  Future<void> _syncItem(String childId, ShopItem item, ChildRecord before) async {
    try {
      final s = await _api.tapItem(childId, item.id);
      if (!ref.mounted) return;
      _update(
        childId,
        (r) => r.copyWith(
          stars: (s['stars'] as num).toInt(),
          wearing: () => s['wearing'] as String?,
          owned: {for (final i in s['owned'] as List) i as String},
          room: {for (final i in s['room'] as List) i as String},
        ),
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      _update(childId, (_) => before);
      _say(e.offline ? 'No internet connection. Please try again.' : "That didn't work. Please try again.");
      if (!e.offline) unawaited(refreshMe());
    }
  }

  // ------------------------------------------------------------ parent

  /// Starts the server's free trial of Likho Plus (its days are in the App
  /// controls). Throws [ApiException] on failure.
  Future<void> subscribe() async {
    if (state.online) {
      final s = await _api.startTrial();
      if (!ref.mounted) return;
      state = state.copyWith(subscribed: s['active'] == true, plusTrial: s['active'] == true);
      return;
    }
    state = state.copyWith(subscribed: true, plusTrial: true);
  }

  void updateSettings(AppSettings Function(AppSettings s) f) {
    final before = state.settings;
    final after = f(before);
    state = state.copyWith(settings: after);
    if (!state.online) return;
    final patch = {
      for (final MapEntry(:key, :value) in after.toJson().entries)
        if (before.toJson()[key] != value) key: value,
    };
    if (patch.isNotEmpty) unawaited(_saveSettings(patch, before));
  }

  Future<void> _saveSettings(Map<String, dynamic> patch, AppSettings before) async {
    try {
      final s = await _api.updateSettings(patch);
      if (!ref.mounted) return;
      state = state.copyWith(settings: AppSettings.fromJson(s));
    } on ApiException catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(settings: before);
      _say("Couldn't save the setting. Check your internet connection.");
    }
  }
}

/// A notifier that never talks to the server: sample data for tests and the
/// dev tools (`familyProvider.overrideWith(DemoFamilyNotifier.new)`).
class DemoFamilyNotifier extends FamilyNotifier {
  DemoFamilyNotifier([this.initial]);
  final FamilyState? initial;

  @override
  FamilyState build() => initial ?? FamilyState.demo();
}

final familyProvider = NotifierProvider<FamilyNotifier, FamilyState>(FamilyNotifier.new);

/// A short message about something that could not be saved (shown as a
/// toast by the app shell). [n] makes the same text show again.
typedef SyncMessage = ({int n, String text});

class SyncMessages extends Notifier<SyncMessage?> {
  @override
  SyncMessage? build() => null;

  void show(String text) => state = (n: (state?.n ?? 0) + 1, text: text);
}

final syncMessageProvider = NotifierProvider<SyncMessages, SyncMessage?>(SyncMessages.new);

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

/// "11 Oct 2026": a day as parents read it (the phone's local date).
String formatDay(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = d.toLocal();
  return '${l.day} ${months[l.month - 1]} ${l.year}';
}
