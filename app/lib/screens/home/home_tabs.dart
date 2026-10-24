import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_controls.dart';
import '../../data/games.dart';
import '../../data/story.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../feedback/app_feedback.dart';
import 'likho_tab_bar.dart';

/// The tabs in the bottom bar, in order: the team's tabs that are shown,
/// with Stories and Games only while their switches show them. Empty when
/// only Map would be left (then there is no bar, and the map keeps its
/// own Settings button).
final visibleTabsProvider = Provider<List<TabSpec>>((ref) {
  final rules = ref.watch(appControlsProvider.select((c) => c.tabBar));
  final stories = ref.watch(storiesShownProvider), games = ref.watch(gamesShownProvider);
  final tabs = [
    for (final t in rules.tabs)
      if (t.shown &&
          switch (t.id) {
            TabIds.stories => stories,
            TabIds.games => games,
            _ => true,
          })
        t,
  ];
  return tabs.length < 2 ? const [] : tabs;
});

/// Whether tab [id] is in the bottom bar now.
final tabShownProvider = Provider.family<bool, String>((ref, id) => ref.watch(visibleTabsProvider).any((t) => t.id == id));

/// The open tab; null: the one the team chose to start on.
class SelectedTab extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedTabProvider = NotifierProvider<SelectedTab, String?>(SelectedTab.new);

/// The open tab as it shows: the chosen one while it is in the bar, else
/// the start tab, else Map.
final currentTabProvider = Provider<String>((ref) {
  final tabs = ref.watch(visibleTabsProvider);
  bool has(String? id) => id != null && id != TabIds.parents && tabs.any((t) => t.id == id);
  final chosen = ref.watch(selectedTabProvider);
  if (has(chosen)) return chosen!;
  final start = ref.watch(appControlsProvider.select((c) => c.tabBar.start));
  return has(start) ? start : TabIds.map;
});

/// How much of the screen's bottom the bar covers, for pages under it
/// that place things themselves (the World Map). 0 without a bar.
class TabBarInset extends InheritedWidget {
  const TabBarInset({super.key, required this.inset, required super.child});
  final double inset;

  static double of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<TabBarInset>()?.inset ?? 0;

  @override
  bool updateShouldNotify(TabBarInset old) => old.inset != inset;
}

/// Home: the World Map, Stories and Games as tabs, with the bottom bar
/// over them. Each page keeps its place while another tab is open; the
/// one opened fades up into view. Parents is not a page: [onParents]
/// (the parent gate). Back on another tab goes to Map first.
class HomeTabs extends ConsumerStatefulWidget {
  const HomeTabs({super.key, required this.page, required this.onParents, required this.canOpen});

  /// Builds the page of tab [id] (map, stories or games).
  final Widget Function(BuildContext context, String id) page;
  final VoidCallback onParents;

  /// Whether tab [id] may open (false: Likho Plus only, the paywall is up).
  final bool Function(String id) canOpen;

  @override
  ConsumerState<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends ConsumerState<HomeTabs> with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(vsync: this, value: 1);
  final _visited = <String>{};

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _tap(String id, String current) {
    final feedback = AppFeedback.of(context);
    if (id == TabIds.parents) {
      feedback.tap();
      widget.onParents();
      return;
    }
    if (id == current) return feedback.tap();
    feedback.press();
    if (!widget.canOpen(id)) return;
    ref.read(selectedTabProvider.notifier).select(id);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(visibleTabsProvider);
    final current = ref.watch(currentTabProvider);
    final rules = ref.watch(appControlsProvider.select((c) => c.tabBar));
    final reduceMotion = ref.watch(reduceMotionProvider);
    ref.listen(currentTabProvider, (before, now) {
      if (before == now) return;
      _enter.duration = reduceMotion ? Duration.zero : rules.time(260);
      _enter.forward(from: 0);
    });
    _visited.add(current);

    final mq = MediaQuery.of(context);
    final inset = tabs.isEmpty ? 0.0 : LikhoTabBar.inset(rules, mq.padding);
    final fresh = {
      for (final t in tabs)
        if (t.badge &&
            switch (t.id) {
              TabIds.stories => ref.watch(myStoryStarsProvider).isEmpty,
              TabIds.games => ref.watch(myGamesProvider).isEmpty,
              _ => false,
            })
          t.id,
    };

    final pages = [
      for (final id in [TabIds.map, TabIds.stories, TabIds.games])
        if (_visited.contains(id) && (id == TabIds.map || tabs.any((t) => t.id == id)))
          KeyedSubtree(
            key: ValueKey('page-$id'),
            child: Offstage(
              offstage: id != current,
              child: TickerMode(
                enabled: id == current,
                child: _Rise(animation: id == current ? _enter : kAlwaysCompleteAnimation, child: widget.page(context, id)),
              ),
            ),
          ),
    ];

    return PopScope(
      canPop: current == TabIds.map,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(selectedTabProvider.notifier).select(TabIds.map);
      },
      child: TabBarInset(
        inset: inset,
        child: Stack(
          children: [
            Positioned.fill(
              child: MediaQuery(
                data: mq.copyWith(padding: mq.padding.copyWith(bottom: mq.padding.bottom + inset)),
                child: Stack(fit: StackFit.expand, children: pages),
              ),
            ),
            // the list pages fade out under the bar (the map runs on under it)
            if (tabs.isNotEmpty && current != TabIds.map)
              Positioned(
                key: const ValueKey('tab-fade'),
                left: 0,
                right: 0,
                bottom: 0,
                height: inset + 28,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [LikhoColors.background.withValues(alpha: 0), LikhoColors.background.withValues(alpha: .92)],
                      ),
                    ),
                  ),
                ),
              ),
            if (tabs.isNotEmpty)
              Positioned(
                // keyed: the fade above comes and goes, the bar keeps its state
                key: const ValueKey('tab-bar'),
                left: 0,
                right: 0,
                bottom: 0,
                child: LikhoTabBar(rules: rules, tabs: tabs, selected: current, fresh: fresh, reduceMotion: reduceMotion, onTap: (id) => _tap(id, current)),
              ),
          ],
        ),
      ),
    );
  }
}

/// The page just opened: fades in and rises a little. (Always the same
/// wrappers, so the page under it keeps its state.)
class _Rise extends StatelessWidget {
  const _Rise({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(animation.value);
      return Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      );
    },
  );
}
