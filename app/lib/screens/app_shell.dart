import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/auth.dart';
import '../data/course_providers.dart';
import '../data/family.dart';
import '../design/tokens.dart';
import '../mascot/mascot.dart';
import 'app_flow.dart';
import 'common/kid_widgets.dart';
import 'common/pencil_figure.dart';
import 'common/toast.dart';

/// Sits around the Navigator (MaterialApp.builder) and keeps the app in
/// step with the server:
/// * a change that could not be saved shows as a toast
/// * when the server ends the session, the app goes back to Welcome
/// * finished levels still waiting are sent when the app comes back
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: () => ref.read(familyProvider.notifier).flush());
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  void _toast(String text) {
    final overlay = widget.navigatorKey.currentState?.overlay;
    if (overlay != null) Toast.showOn(overlay, text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(syncMessageProvider, (_, m) {
      if (m != null) _toast(m.text);
    });
    ref.listen(authProvider, (before, now) {
      if (before?.signedIn != true || now.signedIn) return;
      final nav = widget.navigatorKey.currentState;
      if (nav == null) return;
      AppFlow.toWelcome(nav.context);
      if (now.expired) _toast('Please sign in again.');
    });
    return widget.child;
  }
}

/// The World Map needs the course. On the very first launch it is
/// downloaded; without internet this asks to try again instead of an
/// empty map.
class CourseGate extends ConsumerWidget {
  const CourseGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseProvider);
    if (course.value != null || !course.hasError) return child;
    return CourseOffline(loading: course.isLoading, onRetry: () => ref.invalidate(courseProvider));
  }
}

class CourseOffline extends StatelessWidget {
  const CourseOffline({super.key, required this.onRetry, this.loading = false});
  final VoidCallback onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) => StatusBar(
    child: Material(
      color: LikhoColors.background,
      child: MaxWidth(
        width: 440,
        child: ScrollFill(
          padding: EdgeInsets.fromLTRB(24, frameTop(context, 96), 24, 44),
          child: Column(
            children: [
              const PencilFigure(width: 150, height: 210, state: MascotState.encourage, holdEnd: true),
              const SizedBox(height: 22),
              Text(
                "You're offline",
                textAlign: TextAlign.center,
                style: LikhoFonts.title(size: 32, weight: FontWeight.w800).copyWith(height: 1.12),
              ),
              const SizedBox(height: 10),
              Text(
                'Likho downloads its levels the first time it opens. Please connect to the internet and try again.',
                textAlign: TextAlign.center,
                style: LikhoFonts.body(size: 17, color: UiColors.inkBody, height: 1.45),
              ),
              const Spacer(),
              BigButton(
                label: 'Try again',
                icon: loading ? null : Symbols.refresh_rounded,
                leading: loading ? const ButtonSpinner() : null,
                height: 76,
                onTap: loading ? null : onRetry,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
