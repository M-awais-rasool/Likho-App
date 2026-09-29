import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import 'mascot_playground.dart';

/// Debug-only check that a screen matches its reference design.
///
/// A small "REF" chip (debug builds only) toggles the reference frame on top
/// of the screen, with an opacity slider. Long-press it to open the mascot
/// playground (dev tools). The reference is drawn at the
/// prototype's size (390 x 844 logical px) without stretching.
/// Screens can read [referenceOverlayProvider] to hold still while it is on.
class ReferenceOverlay extends ConsumerWidget {
  const ReferenceOverlay({
    super.key,
    required this.asset,
    required this.child,
    this.designSize = const Size(390, 844),
    this.alignment = Alignment.center,
  });

  /// Reference frame, e.g. assets/reference/screens/splash.png (2x).
  final String asset;
  final Widget child;
  final Size designSize;
  final Alignment alignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return child;
    final s = ref.watch(referenceOverlayProvider);
    final n = ref.read(referenceOverlayProvider.notifier);
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (s.enabled)
            IgnorePointer(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                alignment: alignment,
                child: Opacity(
                  opacity: s.opacity,
                  child: Image.asset(asset, width: designSize.width, height: designSize.height, fit: BoxFit.fill),
                ),
              ),
            ),
          Positioned(
            top: top + LikhoSpace.s1,
            right: LikhoSpace.s1,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: n.toggle,
              // debug shortcut to the dev tools
              onLongPress: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MascotPlayground())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: s.enabled ? LikhoColors.success : LikhoColors.inkFaint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('REF', style: LikhoFonts.title(size: 14, color: LikhoColors.surface)),
              ),
            ),
          ),
          if (s.enabled)
            Positioned(
              left: LikhoSpace.s2,
              right: LikhoSpace.s2,
              bottom: MediaQuery.paddingOf(context).bottom + LikhoSpace.s1,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {}, // keep taps on the panel away from the screen
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: LikhoSpace.s2),
                  decoration: BoxDecoration(
                    color: LikhoColors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(LikhoRadius.button),
                  ),
                  child: Row(
                    children: [
                      Text('Reference', style: LikhoFonts.title(size: 16)),
                      Expanded(
                        child: Slider(value: s.opacity, onChanged: n.setOpacity),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text('${(s.opacity * 100).round()}%', textAlign: TextAlign.right, style: LikhoFonts.title(size: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

@immutable
class ReferenceOverlayState {
  const ReferenceOverlayState({this.enabled = false, this.opacity = 0.5});
  final bool enabled;
  final double opacity;
}

class ReferenceOverlayNotifier extends Notifier<ReferenceOverlayState> {
  @override
  ReferenceOverlayState build() => const ReferenceOverlayState();

  void toggle() => state = ReferenceOverlayState(enabled: !state.enabled, opacity: state.opacity);
  void setOpacity(double o) => state = ReferenceOverlayState(enabled: state.enabled, opacity: o);
}

/// Shared by every screen, so the overlay stays on while you move around.
final referenceOverlayProvider = NotifierProvider<ReferenceOverlayNotifier, ReferenceOverlayState>(ReferenceOverlayNotifier.new);
