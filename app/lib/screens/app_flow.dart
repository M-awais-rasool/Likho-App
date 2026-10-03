import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/api_client.dart';
import '../data/auth.dart';
import '../data/course_providers.dart';
import '../data/family.dart';
import '../data/models/course_models.dart';
import '../feedback/app_feedback.dart';
import '../feedback/game_feedback.dart';
import '../game/level_session.dart';
import 'app_shell.dart';
import 'auth/sign_in_sheet.dart';
import 'auth/welcome_screen.dart';
import 'certificate/certificate_screen.dart';
import 'common/confirm_dialog.dart';
import 'common/toast.dart';
import 'gameplay/gameplay_screen.dart';
import 'level_complete/level_complete_screen.dart';
import 'level_intro/level_intro_screen.dart';
import 'likho_route.dart';
import 'parent/course_progress_screen.dart';
import 'parent/dashboard_screen.dart';
import 'parent/parent_gate.dart';
import 'parent/paywall_screen.dart';
import 'parent/settings_screen.dart';
import 'placement/placement_done_screen.dart';
import 'profile/child_profile_screen.dart';
import 'profiles/child_setup_screen.dart';
import 'profiles/whos_playing_screen.dart';
import 'room/mascot_room_screen.dart';
import 'session_end/session_end_screen.dart';
import 'stickers/sticker_book_screen.dart';
import 'world_map/world_map_screen.dart';

/// Navigation between all screens, in one place (the prototype's go / back).
///
/// Stack shapes:
/// * Splash -> Welcome (signed out) or Who's playing (signed in)
/// * Welcome -> "Continue with Google" -> Who's playing (or adding the
///   first child) / "Try it first" -> warm-up -> map as a guest
/// * Who's playing -> World Map -> everything else
/// * the World Map is always right above Who's playing, or the root
abstract final class AppFlow {
  static const welcomeRoute = 'welcome';
  static const whosRoute = 'whos';
  static const mapRoute = 'map';

  /// Add to MaterialApp.navigatorObservers so the flow knows what is open.
  static final observer = LikhoNavObserver();

  /// MaterialApp.navigatorKey (the app shell navigates with it).
  static final navigatorKey = GlobalKey<NavigatorState>();

  static ProviderContainer _c(BuildContext context) => ProviderScope.containerOf(context);

  // ------------------------------------------------------------------ account

  /// Where the Splash goes once the saved sign-in has been checked.
  static Future<void> afterSplash(BuildContext context) async {
    final container = _c(context);
    await container.read(authProvider.notifier).ready;
    if (!context.mounted) return;
    container.read(authProvider).signedIn ? _home(context) : toWelcome(context);
  }

  /// A signed-in family starts at Who's playing, or adds its first child.
  static void _home(BuildContext context) {
    if (_c(context).read(familyProvider).profiles.isEmpty) {
      Navigator.of(context).pushAndRemoveUntil(_firstChild(), (_) => false);
    } else {
      toWhos(context);
    }
  }

  static Route<void> welcomeRoutePage() => LikhoRoute<void>(
    settings: const RouteSettings(name: welcomeRoute),
    builder: (ctx) => WelcomeScreen(
      onGoogle: () async {
        final ok = await _signIn(ctx);
        if (ok && ctx.mounted) _home(ctx);
        return ok;
      },
      onTryFirst: () => openPlacement(ctx),
      onTerms: () => Toast.show(ctx, 'Terms and Privacy Policy coming soon'),
      onTestUser: TestUser.enabled
          ? () async {
              final ok = await _signIn(ctx, testUser: true);
              if (ok && ctx.mounted) _home(ctx);
              return ok;
            }
          : null,
    ),
  );

  /// After logout: Welcome becomes the only screen.
  static void toWelcome(BuildContext context) {
    final nav = Navigator.of(context);
    if (observer.has(welcomeRoute)) {
      nav.popUntil(ModalRoute.withName(welcomeRoute));
      return;
    }
    nav.pushAndRemoveUntil(welcomeRoutePage(), (_) => false);
  }

  /// "Continue with Google" (Welcome or the guest sheet), or the test
  /// account ([testUser]): the account is made the first time, continued
  /// after that. True once signed in.
  static Future<bool> _signIn(BuildContext context, {bool testUser = false}) async {
    final container = _c(context);
    final auth = container.read(authProvider.notifier);
    try {
      final isNew = testUser ? await auth.signInAsTestUser() : await auth.signInWithGoogle();
      if (isNew == null) return false; // the Google sheet was closed
      container.read(feedbackProvider).unlock();
      return true;
    } on ApiException catch (e) {
      if (context.mounted) Toast.show(context, signInError(e));
    } catch (e) {
      debugPrint(testUser ? 'Test user sign-in: $e' : 'Google sign-in: $e');
      if (context.mounted) Toast.show(context, 'Google sign-in failed. Please try again.');
    }
    return false;
  }

  static String signInError(ApiException e) => switch (e.code) {
    'offline' => 'No internet connection. Please try again.',
    'rate_limited' => 'Please wait a moment and try again.',
    _ => 'Sign-in failed. Please try again.',
  };

  /// Guests ("Try it first") play the warm-up and level 1; anything
  /// more asks a parent to sign in first. Runs [open] when allowed.
  static Future<void> _member(BuildContext context, VoidCallback open) async {
    if (!_c(context).read(familyProvider).guest) return open();
    final ok = await showSignInSheet(
      context,
      onGoogle: () => _signIn(context),
      onTestUser: TestUser.enabled ? () => _signIn(context, testUser: true) : null,
    );
    // the guest's phone-only progress is not kept: start the real family
    if (ok && context.mounted) _home(context);
  }

  /// A new account's first child (then the warm-up). Back = sign out again.
  static Route<void> _firstChild() => LikhoRoute<void>(
    builder: (ctx) => ChildSetupScreen(
      mode: ChildSetupMode.add,
      onBack: () => unawaited(_c(ctx).read(authProvider.notifier).logOut()),
      onDone: () => openPlacement(ctx, replace: true),
    ),
  );

  // ------------------------------------------------------------------ children

  /// Who's playing becomes the root (after sign-in, "Switch", "Manage
  /// profiles", or editing a child).
  static void toWhos(BuildContext context) => Navigator.of(context).pushAndRemoveUntil(
    LikhoRoute<void>(
      settings: const RouteSettings(name: whosRoute),
      builder: (ctx) => WhosPlayingScreen(
        onPicked: () => toMap(ctx),
        onAddChild: () => _gated(ctx, () => Navigator.of(ctx).push(_childSetup(ChildSetupMode.add))),
        onParent: () => _gated(ctx, () => Navigator.of(ctx).push(_dashboard())),
      ),
    ),
    (_) => false,
  );

  static Route<void> _childSetup(ChildSetupMode mode) => LikhoRoute<void>(
    builder: (ctx) => ChildSetupScreen(
      mode: mode,
      onBack: () => Navigator.of(ctx).pop(),
      // new child -> placement warm-up; edited child -> Who's playing
      onDone: () => mode == ChildSetupMode.add ? openPlacement(ctx, replace: true) : toWhos(ctx),
      onDeleted: () => toWhos(ctx),
    ),
  );

  static Future<void> _gated(BuildContext context, VoidCallback open) async {
    if (await showParentGate(context) && context.mounted) open();
  }

  // ------------------------------------------------------------------ map

  static Widget mapScreen(BuildContext ctx) => CourseGate(
    child: WorldMapScreen(
      onOpenLevel: (n) => openLevel(ctx, n),
      onProfile: () {
        AppFeedback.of(ctx).tap();
        _member(ctx, () => Navigator.of(ctx).push(_profile()));
      },
      onRoom: () {
        AppFeedback.of(ctx).press();
        _member(ctx, () => Navigator.of(ctx).push(LikhoRoute<void>(builder: (c) => MascotRoomScreen(onBack: () => Navigator.of(c).pop()))));
      },
      onSettings: () {
        AppFeedback.of(ctx).tap();
        _member(ctx, () => _gated(ctx, () => Navigator.of(ctx).push(_dashboard())));
      },
    ),
  );

  /// Back to the World Map: pops to it when it is open, otherwise opens it
  /// right above Who's playing (or as the only screen).
  static void toMap(BuildContext context) {
    final nav = Navigator.of(context);
    if (observer.has(mapRoute)) {
      nav.popUntil(ModalRoute.withName(mapRoute));
      return;
    }
    nav.pushAndRemoveUntil(
      LikhoRoute<void>(
        rise: false,
        settings: const RouteSettings(name: mapRoute),
        builder: mapScreen,
      ),
      (r) => r.settings.name == whosRoute,
    );
  }

  static Route<void> _profile() => LikhoRoute<void>(
    builder: (ctx) => ChildProfileScreen(
      onBack: () => Navigator.of(ctx).pop(),
      onEdit: () => _gated(ctx, () => Navigator.of(ctx).push(_childSetup(ChildSetupMode.edit))),
      onStickers: () => Navigator.of(ctx).push(LikhoRoute<void>(builder: (c) => StickerBookScreen(onBack: () => Navigator.of(c).pop()))),
    ),
  );

  // ------------------------------------------------------------------ parents

  static Route<void> _dashboard() => LikhoRoute<void>(
    builder: (ctx) => DashboardScreen(
      onClose: () => toMap(ctx),
      onSettings: () => Navigator.of(ctx).push(_settings()),
      onSwitchChild: () => toWhos(ctx),
      onCourse: () => Navigator.of(ctx).push(LikhoRoute<void>(builder: (c) => CourseProgressScreen(onBack: () => Navigator.of(c).pop()))),
      onPlans: () => Navigator.of(ctx).push(_paywall()),
      onRestore: () => Toast.show(ctx, 'No previous purchases found.'),
      onShare: () => Toast.show(ctx, 'Share card copied.'),
    ),
  );

  static Route<void> _settings() => LikhoRoute<void>(
    builder: (ctx) => SettingsScreen(
      onBack: () => Navigator.of(ctx).pop(),
      // signing out moves the app to Welcome (AppShell)
      onLogOut: () => unawaited(_c(ctx).read(familyProvider.notifier).logOut()),
      onManageChildren: () => toWhos(ctx),
      onPlan: () => Navigator.of(ctx).push(_paywall()),
      onHelp: () => Toast.show(ctx, 'Help center coming soon'),
      onDeleteAccount: () => _deleteAccount(ctx),
    ),
  );

  static Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showConfirm(
      context,
      title: 'Delete account?',
      message: "All children's progress, stars and stickers will be permanently deleted.",
      yes: 'Delete',
    );
    if (!ok || !context.mounted) return;
    try {
      await _c(context).read(authProvider.notifier).deleteAccount();
    } on ApiException catch (e) {
      if (context.mounted) Toast.show(context, e.offline ? 'No internet connection. Please try again.' : "Couldn't delete the account. Please try again.");
    }
  }

  /// Likho Plus. After the trial starts it closes, then opens [pendingLevel]
  /// (a locked level the child tapped) if there is one.
  static Route<void> _paywall({int? pendingLevel}) => LikhoRoute<void>(
    builder: (ctx) => PaywallScreen(
      onClose: () => Navigator.of(ctx).pop(),
      onRestore: () => Toast.show(ctx, 'No previous purchases found.'),
      onStartTrial: (_) async {
        final container = _c(ctx);
        final family = container.read(familyProvider.notifier);
        try {
          await family.subscribe();
        } on ApiException catch (e) {
          if (!ctx.mounted) return;
          Toast.show(ctx, switch (e.code) {
            'trial_used' => 'The free trial has already been used.',
            'offline' => 'No internet connection. Please try again.',
            _ => "Couldn't start the trial. Please try again.",
          });
          if (e.code == 'trial_used') unawaited(family.refreshMe());
          return;
        }
        if (!ctx.mounted) return;
        container.read(feedbackProvider).unlock();
        Toast.show(ctx, 'Your 7-day free trial has started!');
        Future.delayed(const Duration(milliseconds: 700), () {
          if (!ctx.mounted) return;
          final nav = Navigator.of(ctx);
          nav.pop();
          if (pendingLevel != null && nav.mounted) openLevel(nav.context, pendingLevel);
        });
      },
    ),
  );

  // ------------------------------------------------------------------ levels

  /// Map -> (paywall for Plus levels) -> level intro -> gameplay -> Level
  /// Complete -> map / session end / certificate, with the result saved.
  static void openLevel(BuildContext context, int number, {bool skipIntro = false}) {
    final container = _c(context);
    final course = container.read(courseProvider).value;
    if (course == null) return;
    final level = course.level(number);
    final nav = Navigator.of(context);
    if (number > 1 && container.read(familyProvider).guest) {
      _member(context, () {});
      return;
    }
    if (level.requiresSubscription && !container.read(familyProvider).subscribed) {
      nav.push(_paywall(pendingLevel: number));
      return;
    }
    container.read(feedbackProvider).levelStart();
    if (skipIntro) {
      nav.push(_game(container, level));
      return;
    }
    nav.push(
      LikhoRoute<void>(
        builder: (ctx) => IntroFeedback(
          child: LevelIntroScreen(level: level, onDone: () => Navigator.of(ctx).pushReplacement(_game(container, level))),
        ),
      ),
    );
  }

  /// Gameplay, with its sounds and haptics layered on by [GameFeedback].
  static Route<void> _game(ProviderContainer container, CourseLevel level) {
    final played = Stopwatch()..start(); // practice time for the parents' report
    return LikhoRoute<void>(
      builder: (ctx) => GameFeedback(
        level: level,
        child: GameplayScreen(
          level: level,
          onExit: () {
            container.read(feedbackProvider).back();
            Navigator.of(ctx).pop();
          },
          onFinished: (result) {
            final choices = container.read(levelSessionProvider(level)).choices;
            final outcome = container
                .read(familyProvider.notifier)
                .recordResult(level.number, result.stars, choices: choices, seconds: played.elapsed.inSeconds.clamp(1, 1800));
            container.read(playSessionProvider.notifier).finished(outcome);
            Navigator.of(ctx).pushReplacement(_complete(container, level, outcome));
          },
        ),
      ),
    );
  }

  static Route<void> _complete(ProviderContainer container, CourseLevel level, LevelOutcome outcome) => LikhoRoute<void>(
    rise: false,
    builder: (ctx) => LevelCompleteScreen(
      level: level,
      outcome: outcome,
      onAgain: () => Navigator.of(ctx).pushReplacement(_game(container, level)),
      onNext: () {
        final nav = Navigator.of(ctx);
        final session = container.read(playSessionProvider);
        if (level.number == 36) {
          nav.pushReplacement(
            LikhoRoute<void>(
              rise: false,
              builder: (c) => CertificateScreen(onPrint: () => Toast.show(c, 'Certificate PDF ready!'), onPlayground: () => Navigator.of(c).pop()),
            ),
          );
        } else if (session.levels >= container.read(familyProvider).settings.levelsPerSession) {
          nav.pushReplacement(
            LikhoRoute<void>(
              rise: false,
              builder: (c) => SessionEndScreen(
                stars: session.stars,
                onHome: () {
                  container.read(playSessionProvider.notifier).reset();
                  Navigator.of(c).pop();
                },
              ),
            ),
          );
        } else {
          nav.pop();
        }
      },
    ),
  );

  /// The placement warm-up (after adding a child, or "Try it first"),
  /// then "Let's get started!" and the map.
  static void openPlacement(BuildContext context, {bool replace = false}) {
    final container = _c(context);
    final level = container.read(courseProvider).value?.placement;
    if (level == null) return toMap(context);
    final route = LikhoRoute<void>(
      builder: (ctx) => GameFeedback(
        level: level,
        child: GameplayScreen(
          level: level,
          onExit: () {
            container.read(feedbackProvider).back();
            toMap(ctx);
          },
          onFinished: (_) => Navigator.of(ctx).pushReplacement(LikhoRoute<void>(builder: (c) => PlacementDoneScreen(onDone: () => toMap(c)))),
        ),
      ),
    );
    final nav = Navigator.of(context);
    replace ? nav.pushReplacement(route) : nav.push(route);
  }
}

/// QA shortcuts to every screen (the prototype's side menu, `jump(k)`),
/// used by the dev launcher and the mascot playground. [context] must be
/// under the app's Navigator.
abstract final class AppFlowJump {
  static const screens = [
    'welcome', 'signIn', 'offline', 'whos', 'onb', 'edit', 'placement', 'placementDone', //
    'map', 'complete', 'complete1', 'boss', 'sessionEnd', 'certificate', 'room', 'profile', 'stickers', //
    'gate', 'dashboard', 'course', 'settings', 'paywall',
  ];

  static void open(BuildContext context, String key) {
    final container = AppFlow._c(context);
    final course = container.read(courseProvider).value;
    final nav = Navigator.of(context);
    void push(Widget Function(BuildContext) b, {bool rise = true}) => nav.push(LikhoRoute<void>(rise: rise, builder: b));
    final cur = (() {
      final r = container.read(familyProvider).record;
      for (var n = 1; n <= 36; n++) {
        if (!r.isDone(n)) return n;
      }
      return 36;
    })();
    void complete(int n, int stars, int gain) {
      if (course == null) return;
      nav.push(AppFlow._complete(container, course.level(n), LevelOutcome(level: n, stars: stars, gain: gain, firstTime: false)));
    }

    switch (key) {
      case 'welcome':
        nav.push(AppFlow.welcomeRoutePage());
      case 'signIn':
        showSignInSheet(context, onGoogle: () async => false);
      case 'offline':
        push((c) => CourseOffline(onRetry: () => Navigator.of(c).pop()));
      case 'whos':
        AppFlow.toWhos(context);
      case 'onb':
        nav.push(AppFlow._childSetup(ChildSetupMode.add));
      case 'edit':
        nav.push(AppFlow._childSetup(ChildSetupMode.edit));
      case 'placement':
        AppFlow.openPlacement(context);
      case 'placementDone':
        push((c) => PlacementDoneScreen(onDone: () => AppFlow.toMap(c)));
      case 'map':
        AppFlow.toMap(context);
      case 'complete':
        complete(cur, 3, 5);
      case 'complete1':
        complete(cur, 1, 1);
      case 'boss':
        complete(6, 3, 5);
      case 'sessionEnd':
        push((c) => SessionEndScreen(stars: container.read(playSessionProvider).stars, onHome: () => Navigator.of(c).pop()), rise: false);
      case 'certificate':
        push((c) => CertificateScreen(onPrint: () => Toast.show(c, 'Certificate PDF ready!'), onPlayground: () => Navigator.of(c).pop()), rise: false);
      case 'room':
        push((c) => MascotRoomScreen(onBack: () => Navigator.of(c).pop()));
      case 'profile':
        nav.push(AppFlow._profile());
      case 'stickers':
        push((c) => StickerBookScreen(onBack: () => Navigator.of(c).pop()));
      case 'gate':
        AppFlow._gated(context, () => nav.push(AppFlow._dashboard()));
      case 'dashboard':
        nav.push(AppFlow._dashboard());
      case 'course':
        push((c) => CourseProgressScreen(onBack: () => Navigator.of(c).pop()));
      case 'settings':
        nav.push(AppFlow._settings());
      case 'paywall':
        nav.push(AppFlow._paywall());
    }
  }
}

/// Remembers which named routes are open.
class LikhoNavObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];

  bool has(String name) => _routes.any((r) => r.settings.name == name && r.isActive);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes
    ..removeWhere((r) => r.navigator == null) // routes of a Navigator that is gone
    ..add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      _routes[i] = newRoute;
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
  }
}
