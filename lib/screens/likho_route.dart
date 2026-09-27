import 'package:flutter/widgets.dart';

/// The prototype's screen transitions, 0.3 s ease-out: "scrIn" fades in
/// while rising 24 px; screens with "fadeIn" (the map) only fade ([rise] false).
class LikhoRoute<T> extends PageRouteBuilder<T> {
  LikhoRoute({required WidgetBuilder builder, bool rise = true, super.settings})
      : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, _, _) => builder(context),
          transitionsBuilder: (context, animation, _, child) {
            final t = CurvedAnimation(parent: animation, curve: Curves.easeOut);
            return FadeTransition(
              opacity: t,
              child: AnimatedBuilder(
                animation: t,
                builder: (context, c) => rise ? Transform.translate(offset: Offset(0, 24 * (1 - t.value)), child: c) : c!,
                child: child,
              ),
            );
          },
        );
}
