import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course_providers.dart';
import '../data/family.dart';
import '../data/models/course_models.dart';
import '../data/repositories/auth_repository.dart';
import '../game/level_session.dart';
import 'auth/forgot_password_screen.dart';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';
import 'auth/welcome_screen.dart';
import 'certificate/certificate_screen.dart';
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
/// * Welcome -> Sign up / Login / Forgot password
/// * Who's playing (root after sign-in) -> World Map -> everything else
/// * the World Map is always right above Who's playing, or the root
abstract final class AppFlow {
  static const welcomeRoute = 'welcome';
  static const whosRoute = 'whos';
  static const mapRoute = 'map';

  /// Add to MaterialApp.navigatorObservers so the flow knows what is open.
  static final observer = LikhoNavObserver();

  static ProviderContainer _c(BuildContext context) => ProviderScope.containerOf(context);

  // ------------------------------------------------------------------ account

  static Route<void> welcomeRoutePage() => LikhoRoute<void>(
    settings: const RouteSettings(name: welcomeRoute),
    builder: (ctx) =>
        WelcomeScreen(onSignUp: () => Navigator.of(ctx).push(_signUp()), onLogIn: () => Navigator.of(ctx).push(_logIn()), onTryFirst: () => openPlacement(ctx)),
  );

  /// After logout: Welcome becomes the only screen.
  static void toWelcome(BuildContext context) => Navigator.of(context).pushAndRemoveUntil(welcomeRoutePage(), (_) => false);

  static Route<void> _signUp({String email = ''}) => LikhoRoute<void>(
    builder: (ctx) => SignUpScreen(
      email: email,
      onBack: () => Navigator.of(ctx).pop(),
      onDone: () => toWhos(ctx),
      onLogIn: (e) => Navigator.of(ctx).pushReplacement(_logIn(email: e)),
      onTerms: () => Toast.show(ctx, 'Privacy policy khulegi'),
    ),
  );

  static Route<void> _logIn({String email = ''}) => LikhoRoute<void>(
    builder: (ctx) => LoginScreen(
      email: email,
      onBack: () => Navigator.of(ctx).pop(),
      onDone: () => toWhos(ctx),
      onSignUp: (e) => Navigator.of(ctx).pushReplacement(_signUp(email: e)),
      onForgot: (e) => Navigator.of(ctx).push(
        LikhoRoute<void>(
          builder: (c) => ForgotPasswordScreen(email: e, onBack: () => Navigator.of(c).pop(), onLogIn: (_) => Navigator.of(c).pop()),
        ),
      ),
    ),
  );

  // ------------------------------------------------------------------ children

  /// Who's playing becomes the root (after sign-in, "Badlein", "Profiles
  /// manage karein", or editing a child).
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

  static Widget mapScreen(BuildContext ctx) => WorldMapScreen(
    onOpenLevel: (n) => openLevel(ctx, n),
    onProfile: () => Navigator.of(ctx).push(_profile()),
    onRoom: () => Navigator.of(ctx).push(LikhoRoute<void>(builder: (c) => MascotRoomScreen(onBack: () => Navigator.of(c).pop()))),
    onSettings: () => _gated(ctx, () => Navigator.of(ctx).push(_dashboard())),
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
      onRestore: () => Toast.show(ctx, 'Koi purani purchase nahi mili'),
      onShare: () => Toast.show(ctx, 'Share card copy ho gaya'),
    ),
  );

  static Route<void> _settings() => LikhoRoute<void>(
    builder: (ctx) => SettingsScreen(
      onBack: () => Navigator.of(ctx).pop(),
      onLogOut: () async {
        await _c(ctx).read(authProvider.notifier).logOut();
        if (ctx.mounted) toWelcome(ctx);
      },
      onManageChildren: () => toWhos(ctx),
      onPlan: () => Navigator.of(ctx).push(_paywall()),
      onHelp: () => Toast.show(ctx, 'Help center khulega'),
      onDeleteAccount: () => Toast.show(ctx, 'Confirm email bheji gayi'),
    ),
  );

  /// Likho Plus. After the trial starts it closes, then opens [pendingLevel]
  /// (a locked level the child tapped) if there is one.
  static Route<void> _paywall({int? pendingLevel}) => LikhoRoute<void>(
    builder: (ctx) => PaywallScreen(
      onClose: () => Navigator.of(ctx).pop(),
      onRestore: () => Toast.show(ctx, 'Koi purani purchase nahi mili'),
      onStartTrial: (_) {
        final container = _c(ctx);
        container.read(familyProvider.notifier).subscribe();
        Toast.show(ctx, '7 din ka free trial shuru!');
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
    if (level.requiresSubscription && !container.read(familyProvider).subscribed) {
      nav.push(_paywall(pendingLevel: number));
      return;
    }
    if (skipIntro) {
      nav.push(_game(container, level));
      return;
    }
    nav.push(
      LikhoRoute<void>(
        builder: (ctx) => LevelIntroScreen(level: level, onDone: () => Navigator.of(ctx).pushReplacement(_game(container, level))),
      ),
    );
  }

  static Route<void> _game(ProviderContainer container, CourseLevel level) => LikhoRoute<void>(
    builder: (ctx) => GameplayScreen(
      level: level,
      onExit: () => Navigator.of(ctx).pop(),
      onFinished: (result) {
        final choices = container.read(levelSessionProvider(level)).choices;
        final outcome = container.read(familyProvider.notifier).recordResult(level.number, result.stars, choices: choices);
        container.read(playSessionProvider.notifier).finished(outcome);
        Navigator.of(ctx).pushReplacement(_complete(container, level, outcome));
      },
    ),
  );

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

  /// The placement warm-up (after adding a child, or "pehle try karein"),
  /// then "Chalo shuru karein!" and the map.
  static void openPlacement(BuildContext context, {bool replace = false}) {
    final container = _c(context);
    final level = container.read(courseProvider).value?.placement;
    if (level == null) return toMap(context);
    final route = LikhoRoute<void>(
      builder: (ctx) => GameplayScreen(
        level: level,
        onExit: () => toMap(ctx),
        onFinished: (_) => Navigator.of(ctx).pushReplacement(LikhoRoute<void>(builder: (c) => PlacementDoneScreen(onDone: () => toMap(c)))),
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
    'welcome', 'signup', 'signupEmail', 'login', 'forgot', 'forgotSent', 'whos', 'onb', 'edit', 'placement', 'placementDone', //
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
      case 'signup':
        nav.push(AppFlow._signUp());
      case 'signupEmail':
        push((c) => SignUpScreen(emailOpen: true, onBack: () => Navigator.of(c).pop(), onDone: () => AppFlow.toWhos(c), onLogIn: (_) {}, onTerms: () {}));
      case 'login':
        nav.push(AppFlow._logIn());
      case 'forgot':
      case 'forgotSent':
        push(
          (c) => ForgotPasswordScreen(
            email: key == 'forgotSent' ? 'ammi@gmail.com' : '',
            sent: key == 'forgotSent',
            onBack: () => Navigator.of(c).pop(),
            onLogIn: (_) => Navigator.of(c).pop(),
          ),
        );
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

  bool has(String name) => _routes.any((r) => r.settings.name == name);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes.add(route);

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
