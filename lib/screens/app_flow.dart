import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course_providers.dart';
import '../data/progress.dart';
import 'gameplay/gameplay_screen.dart';
import 'level_intro/level_intro_screen.dart';
import 'likho_route.dart';

/// Navigation between the kid screens, in one place.
abstract final class AppFlow {
  /// Map -> level intro -> gameplay -> (Level Complete, next screen to build)
  /// -> back to the map with the result saved.
  static void openLevel(BuildContext context, int number, {bool skipIntro = false}) {
    final container = ProviderScope.containerOf(context);
    final course = container.read(courseProvider).value;
    if (course == null) return;
    final level = course.level(number);
    final nav = Navigator.of(context);

    Widget game(BuildContext ctx) => GameplayScreen(
          level: level,
          onExit: () => Navigator.of(ctx).pop(),
          onFinished: (result) {
            container.read(progressProvider.notifier).recordResult(number, result.stars);
            // TODO(level-complete): show the Level Complete screen here once approved.
            Navigator.of(ctx).pop();
          },
        );

    if (skipIntro) {
      nav.push(LikhoRoute<void>(builder: game));
      return;
    }
    nav.push(LikhoRoute<void>(
      builder: (ctx) => LevelIntroScreen(
        level: level,
        onDone: () => Navigator.of(ctx).pushReplacement(LikhoRoute<void>(builder: game)),
      ),
    ));
  }
}
