import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import 'api/api_client.dart';
import 'api/likho_api.dart';
import 'auth.dart';
import 'family.dart';
import 'models/course_models.dart';
import 'shop_items.dart';

/// App controls: what the team switches on and off in the admin panel
/// (App controls page), for this family. The server sends them at
/// GET /v1/config; they are kept on the phone, so the app follows the last
/// ones it got when offline, and the built-in [AppControls.defaults] (the
/// app as it always was, stories still off) before the first download.

/// Who a switch is on for, as the server resolved it for this family.
enum Access {
  off,
  on,

  /// On while the family has Likho Plus.
  plus;

  static Access parse(Object? v) => switch (v) {
    'on' => Access.on,
    'plus' => Access.plus,
    _ => Access.off,
  };
}

/// Switches (the admin panel's features).
abstract final class Feature {
  static const stories = 'stories';
  static const games = 'games';
  static const room = 'room';
  static const stickers = 'stickers';
  static const certificate = 'certificate';
  static const placement = 'placement';
  static const guest = 'guest';
  static const sfx = 'sfx';
  static const voice = 'voice';
  static const haptics = 'haptics';
}

@immutable
class ItemRule {
  const ItemRule({this.hidden = false, this.price});
  final bool hidden;
  final int? price;
}

/// Likho Plus as the team set it up.
@immutable
class BillingRules {
  const BillingRules({
    this.enabled = true,
    this.freeLevels,
    this.guestLevels = 1,
    this.trialLevels = 0,
    this.serverTrial = true,
    this.trialDays = 7,
    this.monthly = true,
    this.yearly = true,
    this.bestValue = 'yearly',
    this.benefits = const [],
    this.plusFree = false,
    this.freeForAll = false,
    this.freeForAllUntil,
  });

  /// False: no Likho Plus anywhere, every level free.
  final bool enabled;

  /// Levels 1..freeLevels need no Plus; null (nothing downloaded yet): each
  /// level's own `requiresSubscription`.
  final int? freeLevels;

  /// Levels a guest ("Try it first") can play.
  final int guestLevels;

  /// During a free trial only levels up to this one are open (0 = all).
  final int trialLevels;

  /// The server's free trial (without Google Play), and its length.
  final bool serverTrial;
  final int trialDays;
  final bool monthly, yearly;
  final String? bestValue;

  /// The paywall's list (empty: the app's own).
  final List<String> benefits;

  /// Nobody needs Plus right now (billing off, or free for everyone);
  /// [freeForAll]: because of the promotion, until [freeForAllUntil].
  final bool plusFree, freeForAll;
  final DateTime? freeForAllUntil;

  /// Whether Likho Plus shows anywhere in the app.
  bool get showPlus => enabled && !freeForAll;

  /// Whether [level] needs Likho Plus.
  bool needsPlus(CourseLevel level) {
    if (plusFree) return false;
    final free = freeLevels;
    return free == null ? level.requiresSubscription : level.number > free;
  }

  /// Whether a family in its free trial cannot play [level] yet.
  bool trialBlocks(CourseLevel level) => needsPlus(level) && trialLevels > 0 && level.number > trialLevels;

  factory BillingRules.fromJson(Map<String, dynamic> j) => BillingRules(
    enabled: j['enabled'] != false,
    freeLevels: (j['freeLevels'] as num?)?.toInt(),
    guestLevels: (j['guestLevels'] as num?)?.toInt() ?? 1,
    trialLevels: (j['trialLevels'] as num?)?.toInt() ?? 0,
    serverTrial: j['serverTrial'] != false,
    trialDays: (j['trialDays'] as num?)?.toInt() ?? 7,
    monthly: j['monthly'] != false,
    yearly: j['yearly'] != false,
    bestValue: switch (j['bestValue']) {
      final String s when s.isNotEmpty => s,
      _ => null,
    },
    benefits: [for (final b in j['benefits'] as List? ?? const []) if (b is String && b.trim().isNotEmpty) b],
    plusFree: j['plusFree'] == true,
    freeForAll: j['freeForAll'] == true,
    freeForAllUntil: DateTime.tryParse(j['freeForAllUntil'] as String? ?? ''),
  );
}

/// The bottom bar's tabs.
abstract final class TabIds {
  static const map = 'map';
  static const stories = 'stories';
  static const games = 'games';

  /// Not a page: opens the parent gate, then the dashboard.
  static const parents = 'parents';
  static const all = [map, stories, games, parents];
}

/// How the bottom bar looks: [candy] (the tab pops up as a 3D button),
/// [jelly] (a colour blob slides to the tab), [island] (a big Map button
/// in the middle).
enum TabBarStyle { candy, jelly, island }

/// How a tab answers a tap.
enum TabAnimation { bounce, slide, pop, none }

/// The bar behind the tabs.
enum TabSurface { white, glass, colour }

/// One tab of the bottom bar, as the team set it up.
@immutable
class TabSpec {
  const TabSpec(this.id, {this.shown = true, required this.label, required this.color, this.badge = false});
  final String id;
  final bool shown;
  final String label;
  final Color color;

  /// "NEW" until the child has played a story or a game.
  final bool badge;
}

/// The bottom bar (App controls, Bottom bar tab).
@immutable
class TabBarRules {
  const TabBarRules({
    this.style = TabBarStyle.candy,
    this.animation = TabAnimation.bounce,
    this.speed = 1,
    this.wiggle = true,
    this.surface = TabSurface.white,
    this.barColor = const Color(0xFF7C5CFF),
    this.floating = true,
    this.roundness = 28,
    this.labels = true,
    this.start = TabIds.map,
    this.tabs = defaultTabs,
  });

  final TabBarStyle style;
  final TabAnimation animation;

  /// How long the animations take: 1 normal, more is slower.
  final double speed;
  final bool wiggle, floating, labels;
  final TabSurface surface;
  final Color barColor;
  final double roundness;
  final String start;

  /// Every tab, in the bar's order.
  final List<TabSpec> tabs;

  static const defaultTabs = [
    TabSpec(TabIds.map, label: 'Map', color: LikhoColors.primary),
    TabSpec(TabIds.stories, label: 'Stories', color: LikhoColors.secondary, badge: true),
    TabSpec(TabIds.games, label: 'Games', color: MonsterColors.ribbon, badge: true),
    TabSpec(TabIds.parents, label: 'Parents', color: LikhoColors.success),
  ];

  /// Scales a duration by [speed].
  Duration time(int ms) => Duration(milliseconds: (ms * speed).round());

  factory TabBarRules.fromJson(Map<String, dynamic> j) {
    T pick<T extends Enum>(List<T> values, Object? v, T fallback) => values.firstWhere((e) => e.name == v, orElse: () => fallback);
    Color? hex(Object? v) => v is String && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v) ? colorFromHex(v) : null;
    final tabs = <TabSpec>[];
    for (final t in j['tabs'] as List? ?? const []) {
      if (t is! Map) continue;
      final id = t['id'];
      final def = defaultTabs.where((d) => d.id == id).firstOrNull;
      if (def == null || tabs.any((x) => x.id == id)) continue;
      final label = (t['label'] as String? ?? '').trim();
      tabs.add(TabSpec(
        def.id,
        shown: def.id == TabIds.map || t['shown'] != false,
        label: label.isEmpty ? def.label : label,
        color: hex(t['color']) ?? def.color,
        badge: t['badge'] == true,
      ));
    }
    // a tab this app has but the server did not send (an older server)
    for (final d in defaultTabs) {
      if (!tabs.any((x) => x.id == d.id)) tabs.add(d);
    }
    final start = j['start'];
    return TabBarRules(
      style: pick(TabBarStyle.values, j['style'], TabBarStyle.candy),
      animation: pick(TabAnimation.values, j['animation'], TabAnimation.bounce),
      speed: switch (j['speed']) {
        'slow' => 1.6,
        'fast' => .6,
        _ => 1,
      },
      wiggle: j['wiggle'] != false,
      surface: pick(TabSurface.values, j['surface'], TabSurface.white),
      barColor: hex(j['barColor']) ?? const Color(0xFF7C5CFF),
      floating: j['floating'] != false,
      roundness: ((j['roundness'] as num?)?.toDouble() ?? 28).clamp(0, 36),
      labels: j['labels'] != false,
      start: start is String && start != TabIds.parents && TabIds.all.contains(start) ? start : TabIds.map,
      tabs: tabs,
    );
  }
}

/// A message from the team (maintenance screen, parents' dashboard).
@immutable
class TeamNotice {
  const TeamNotice({this.on = false, this.title = '', this.text = '', this.id = ''});
  final bool on;
  final String title, text, id;

  factory TeamNotice.fromJson(Object? v) {
    final j = v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
    return TeamNotice(on: j['on'] == true, title: j['title'] as String? ?? '', text: j['text'] as String? ?? '', id: j['id'] as String? ?? '');
  }
}

@immutable
class AppControls {
  const AppControls({
    this.revision = 0,
    this.features = const {},
    this.comingSoon = true,
    this.episodes = const {},
    this.items = const {},
    this.games = const {},
    this.pencilColors,
    this.billing = const BillingRules(),
    this.minVersion = '',
    this.maintenance = const TeamNotice(),
    this.parentMessage = const TeamNotice(),
    this.tabBar = const TabBarRules(),
    this.storyOrder = const [],
    this.newStories = const {},
    this.playGames = const {},
    this.playGameOrder = const [],
    this.newPlayGames = const {},
  });

  final int revision;
  final Map<String, Access> features;

  /// Stories: the letters still to come, and each episode.
  final bool comingSoon;
  final Map<String, Access> episodes;
  final Map<String, ItemRule> items;

  /// Round types switched off are skipped (writing always stays).
  final Map<String, bool> games;

  /// Pencil's colours a new child can pick (null: all).
  final List<Color>? pencilColors;
  final BillingRules billing;

  /// Older apps must update ('' = any).
  final String minVersion;
  final TeamNotice maintenance, parentMessage;

  /// The bottom bar: its look and its tabs.
  final TabBarRules tabBar;

  /// Stories: the team's order of the episodes (first at the top) and the
  /// ones tagged NEW.
  final List<String> storyOrder;
  final Set<String> newStories;

  /// The Games screen's games (not the round types in [games]): who each
  /// is on for, the team's order and the ones tagged NEW.
  final Map<String, Access> playGames;
  final List<String> playGameOrder;
  final Set<String> newPlayGames;

  /// [ids] in the team's [order]; the ones it lacks keep their own order
  /// after it.
  static List<String> ordered(List<String> ids, List<String> order) => [
    for (final id in order)
      if (ids.contains(id)) id,
    for (final id in ids)
      if (!order.contains(id)) id,
  ];

  /// Whether game [id] can be played (unknown games are on: older servers).
  bool playGameOn(String id, {bool subscribed = false}) => switch (playGames[id]) {
    null || Access.on => true,
    Access.plus => subscribed,
    Access.off => false,
  };

  /// Whether game [id] shows (on, or Plus-only while Plus is sold).
  bool playGameShown(String id, {bool subscribed = false}) => playGameOn(id, subscribed: subscribed) || (playGames[id] == Access.plus && billing.showPlus);

  /// Before anything was downloaded: as the app always was, stories off.
  static const defaults = AppControls(features: {Feature.stories: Access.off});

  /// Whether [feature] is on (unknown switches are on: older servers).
  bool on(String feature, {bool subscribed = false}) => switch (features[feature]) {
    null || Access.on => true,
    Access.plus => subscribed,
    Access.off => false,
  };

  /// Whether episode [id] shows (on, or Plus-only while Plus is sold).
  bool episodeShown(String id, {bool subscribed = false}) => episodeOn(id, subscribed: subscribed) || (episodes[id] == Access.plus && billing.showPlus);

  bool episodeOn(String id, {bool subscribed = false}) => switch (episodes[id]) {
    null || Access.on => true,
    Access.plus => subscribed,
    Access.off => false,
  };

  /// Whether the switch is on only with Likho Plus (the app can say so).
  bool plusOnly(String feature) => features[feature] == Access.plus;

  bool itemHidden(String id) => items[id]?.hidden ?? false;

  /// The shop item at its price now, or null when it is hidden.
  ShopItem? item(ShopItem it) {
    final rule = items[it.id];
    if (rule?.hidden ?? false) return null;
    final price = rule?.price;
    return price == null || price < 1 || price == it.price ? it : it.withPrice(price);
  }

  /// The accessory Pencil shows for the shop item [wearing] (hidden items
  /// are not shown).
  String? accessoryFor(String? wearing) => wearing == null || itemHidden(wearing) ? null : ShopItem.byId(wearing)?.accessory;

  bool gameOn(String type) => type == 'write' || (games[type] ?? true);

  /// The level as it is played: switched-off round types left out (all of
  /// them kept when nothing would be left).
  CourseLevel playable(CourseLevel level) {
    if (games.values.every((on) => on)) return level;
    final rounds = level.rounds.where((r) => gameOn(r.type)).toList();
    if (rounds.isEmpty || rounds.length == level.rounds.length) return level;
    return level.copyWith(rounds: rounds);
  }

  /// Whether this app is older than the team allows.
  bool needsUpdate(String version) => minVersion.isNotEmpty && compareVersions(version, minVersion) < 0;

  factory AppControls.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> obj(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};
    final stories = obj(j['stories']);
    final app = obj(j['app']);
    final gameList = obj(j['gameList']);
    List<String> strings(Object? v) => [for (final x in v is List ? v : const []) if (x is String) x];
    final colors = j['pencilColors'];
    return AppControls(
      revision: (j['revision'] as num?)?.toInt() ?? 0,
      features: {for (final e in obj(j['features']).entries) e.key: Access.parse(e.value)},
      comingSoon: stories['comingSoon'] != false,
      episodes: {for (final e in obj(stories['episodes']).entries) e.key: Access.parse(e.value)},
      items: {
        for (final e in obj(obj(j['room'])['items']).entries)
          e.key: ItemRule(hidden: obj(e.value)['hidden'] == true, price: (obj(e.value)['price'] as num?)?.toInt()),
      },
      games: {for (final e in obj(j['games']).entries) if (e.value is bool) e.key: e.value as bool},
      pencilColors: colors is List
          ? [
              for (final c in colors)
                if (c is String && RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(c)) colorFromHex(c),
            ]
          : null,
      billing: BillingRules.fromJson(obj(j['billing'])),
      minVersion: app['minVersion'] as String? ?? '',
      maintenance: TeamNotice.fromJson(app['maintenance']),
      parentMessage: TeamNotice.fromJson(app['parentMessage']),
      tabBar: TabBarRules.fromJson(obj(j['tabBar'])),
      storyOrder: strings(stories['order']),
      newStories: strings(stories['new']).toSet(),
      playGames: {for (final e in obj(gameList['modes']).entries) e.key: Access.parse(e.value)},
      playGameOrder: strings(gameList['order']),
      newPlayGames: strings(gameList['new']).toSet(),
    );
  }
}

/// Compares "1.2.3+4" versions: negative, 0 or positive (a missing build
/// number counts as 0).
int compareVersions(String a, String b) {
  List<int> parts(String v) {
    final (main, build) = switch (v.trim().split('+')) {
      [final m, final b, ...] => (m, b),
      [final m] => (m, '0'),
      _ => ('', '0'),
    };
    final p = [for (final x in main.split('.')) int.tryParse(x) ?? 0];
    while (p.length < 3) {
      p.add(0);
    }
    return [...p.take(3), int.tryParse(build) ?? 0];
  }

  final pa = parts(a), pb = parts(b);
  for (var i = 0; i < 4; i++) {
    if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
  }
  return 0;
}

/// How often the app asks for new controls while it is open. Null (tests,
/// the admin preview): never; the controls stay as set. main() sets it.
final appControlsSyncProvider = Provider<Duration?>((ref) => null);

/// The controls for this family; they follow the server (see
/// [appControlsSyncProvider]).
class AppControlsNotifier extends Notifier<AppControls> {
  static const file = 'app_controls.json';

  String? _etag;
  DateTime? _askedAt;
  bool _asking = false, _fresh = false;

  @override
  AppControls build() {
    final every = ref.watch(appControlsSyncProvider);
    if (every == null) return AppControls.defaults;
    // a family sees its own switches: ask again when the account changes
    ref.listen(authProvider.select(_accountOf), (before, now) {
      if (before != now) unawaited(refresh(force: true));
    });
    final timer = Timer.periodic(every, (_) => unawaited(refresh()));
    ref.onDispose(timer.cancel);
    Future.microtask(_start);
    return AppControls.defaults;
  }

  static Object? _accountOf(AuthState a) {
    if (!a.signedIn) return null;
    final account = a.me?['account'];
    return account is Map ? account['id'] : null;
  }

  Future<void> _start() async {
    final text = await ref.read(localFilesProvider).read(file);
    if (!ref.mounted) return;
    if (text != null && !_fresh) {
      try {
        final j = jsonDecode(text) as Map<String, dynamic>;
        state = AppControls.fromJson((j['config'] as Map).cast<String, dynamic>());
        _etag = j['etag'] as String?;
      } catch (e) {
        debugPrint('app controls: $e');
      }
    }
    await refresh(force: true);
  }

  /// Asks the server for the controls (at most every 30 s unless [force]).
  Future<void> refresh({bool force = false}) async {
    if (!ref.mounted || _asking) return;
    final now = DateTime.now();
    if (!force && _askedAt != null && now.difference(_askedAt!) < const Duration(seconds: 30)) return;
    _asking = true;
    _askedAt = now;
    try {
      final signedIn = ref.read(authProvider).signedIn;
      final (body, etag) = await ref.read(apiProvider).config(etag: _etag, signedIn: signedIn);
      if (!ref.mounted || body == null) return;
      final next = AppControls.fromJson(jsonDecode(body) as Map<String, dynamic>);
      _etag = etag;
      _fresh = true;
      state = next;
      await ref.read(localFilesProvider).write(file, jsonEncode({'etag': etag, 'config': jsonDecode(body)}));
    } on ApiException catch (e) {
      debugPrint('app controls: $e'); // offline: keep the ones we have
    } catch (e) {
      debugPrint('app controls: $e');
    } finally {
      _asking = false;
    }
  }
}

final appControlsProvider = NotifierProvider<AppControlsNotifier, AppControls>(AppControlsNotifier.new);

/// Fixed controls (tests, the admin preview):
/// `appControlsProvider.overrideWith(() => FixedControls(c))`.
class FixedControls extends AppControlsNotifier {
  FixedControls(this.controls);
  final AppControls controls;

  @override
  AppControls build() => controls;

  @override
  Future<void> refresh({bool force = false}) async {}
}

/// Whether [feature] is on for the active family (Plus counted).
final featureOnProvider = Provider.family<bool, String>((ref, feature) {
  final c = ref.watch(appControlsProvider);
  return c.on(feature, subscribed: ref.watch(familyProvider.select((f) => f.subscribed)));
});

/// Whether [feature] shows: on, or for Likho Plus families while Plus is
/// sold (tapping it then opens the paywall).
final featureShownProvider = Provider.family<bool, String>((ref, feature) {
  final c = ref.watch(appControlsProvider);
  return ref.watch(featureOnProvider(feature)) || (c.features[feature] == Access.plus && c.billing.showPlus);
});

/// Pencil's colours a new child can pick, in the app's order.
final pencilColorsProvider = Provider<List<BodySwatch>>((ref) {
  final allowed = ref.watch(appControlsProvider.select((c) => c.pencilColors));
  if (allowed == null || allowed.isEmpty) return BodySwatch.options;
  final keys = {for (final c in allowed) c.toARGB32()};
  final out = [for (final s in BodySwatch.options) if (keys.contains(s.key.toARGB32())) s];
  return out.isEmpty ? BodySwatch.options : out;
});

/// The team's message a parent closed on the dashboard (its id), kept on
/// the phone: a new message shows again.
class ClosedNotice extends Notifier<String?> {
  static const file = 'closed_notice.txt';

  @override
  String? build() {
    Future.microtask(() async {
      final id = await ref.read(localFilesProvider).read(file);
      if (ref.mounted && state == null) state = id?.trim();
    });
    return null;
  }

  void close(String id) {
    state = id;
    unawaited(ref.read(localFilesProvider).write(file, id));
  }
}

final closedNoticeProvider = NotifierProvider<ClosedNotice, String?>(ClosedNotice.new);

/// The team's message for the parents' dashboard, unless it was closed.
final parentMessageProvider = Provider<TeamNotice?>((ref) {
  final m = ref.watch(appControlsProvider.select((c) => c.parentMessage));
  if (!m.on || m.text.isEmpty || ref.watch(closedNoticeProvider) == m.id) return null;
  return m;
});
