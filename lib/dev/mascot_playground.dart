import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/likho_widgets.dart';
import '../design/tokens.dart';
import '../mascot/mascot.dart';
import '../mascot/mascot_animations.dart';
import '../screens/app_flow.dart';
import '../screens/likho_route.dart';
import '../screens/splash_screen.dart';
import '../screens/world_map/world_map_screen.dart';
import 'reference_overlay.dart';

/// Dev screen to check the Pencil mascot against the reference art.
///
/// * a button for every state, "Say" with a sample voice line
/// * body colour and accessory pickers
/// * drag anywhere: the eyes follow the finger
/// * reference overlay: master image or expression-sheet cell on top of the
///   mascot, 0–100 % opacity, optional "hold pose" for a still comparison
class MascotPlayground extends ConsumerWidget {
  const MascotPlayground({super.key});

  static const sampleAudio = 'assets/audio/pencil_hello.wav';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(playgroundMascotProvider);
    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => c.lookAt(e.position),
        onPointerMove: (e) => c.lookAt(e.position),
        onPointerUp: (_) => c.lookReset(),
        onPointerCancel: (_) => c.lookReset(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(LikhoSpace.screenMargin, LikhoSpace.s2, LikhoSpace.screenMargin, 0),
                child: Text('Mascot playground', style: LikhoFonts.title(size: 28)),
              ),
              Expanded(flex: 11, child: _Stage(controller: c)),
              Expanded(flex: 10, child: _Panel(controller: c)),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ state

final playgroundMascotProvider = Provider.autoDispose<MascotController>((ref) {
  final c = MascotController();
  ref.onDispose(c.dispose);
  return c;
});

enum ReferenceSource { master, sheet, cap }

@immutable
class PlaygroundSettings {
  const PlaygroundSettings({
    this.color = LikhoColors.primary,
    this.accessory,
    this.overlay = false,
    this.opacity = 0.5,
    this.source = ReferenceSource.master,
    this.hold = false,
  });

  final Color color;
  final String? accessory;
  final bool overlay;
  final double opacity;
  final ReferenceSource source;
  final bool hold;

  PlaygroundSettings copyWith({Color? color, String? accessory, bool clearAccessory = false, bool? overlay, double? opacity, ReferenceSource? source, bool? hold}) =>
      PlaygroundSettings(
        color: color ?? this.color,
        accessory: clearAccessory ? null : accessory ?? this.accessory,
        overlay: overlay ?? this.overlay,
        opacity: opacity ?? this.opacity,
        source: source ?? this.source,
        hold: hold ?? this.hold,
      );
}

class PlaygroundNotifier extends Notifier<PlaygroundSettings> {
  @override
  PlaygroundSettings build() => const PlaygroundSettings();

  MascotController get _c => ref.read(playgroundMascotProvider);

  void setColor(Color c) {
    state = state.copyWith(color: c);
    _c.setBodyColor(c);
  }

  void setAccessory(String? id) {
    state = id == null ? state.copyWith(clearAccessory: true) : state.copyWith(accessory: id);
    if (id == null) {
      _c.removeAccessory();
    } else {
      _c.wear(id);
      if (id == MascotAccessory.cap && state.source == ReferenceSource.cap) _applyHold();
    }
  }

  void setOverlay(bool on) => state = state.copyWith(overlay: on);
  void setOpacity(double o) => state = state.copyWith(opacity: o);

  void setSource(ReferenceSource s) {
    state = state.copyWith(source: s);
    _applyHold();
  }

  void setHold(bool hold) {
    state = state.copyWith(hold: hold);
    _applyHold();
  }

  void play(MascotState s) {
    _c.play(s);
    if (state.hold) _applyHold();
  }

  /// Holds the pose that matches the chosen reference image.
  void _applyHold() {
    if (!state.hold) {
      if (_c.isFrozen) _c.unfreeze();
      return;
    }
    if (state.source == ReferenceSource.sheet) {
      final s = _c.state;
      _c.debugShow(s, MascotAnimations.referenceMoments[s] ?? 0);
    } else {
      _c.freezeAtRest();
    }
  }
}

final playgroundProvider = NotifierProvider.autoDispose<PlaygroundNotifier, PlaygroundSettings>(PlaygroundNotifier.new);

// ------------------------------------------------------------------ stage

class _Stage extends ConsumerWidget {
  const _Stage({required this.controller});
  final MascotController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(playgroundProvider);
    return LayoutBuilder(builder: (context, box) {
      // leave headroom for jumps, raised arms and hats
      final h = (box.maxHeight * 0.78).clamp(120.0, 720.0);
      final w = PencilMascot.widthFor(h);
      return Align(
        alignment: const Alignment(0, 0.7),
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PencilMascot(controller: controller, size: h),
              if (s.overlay)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ValueListenableBuilder<MascotState>(
                      valueListenable: controller.stateListenable,
                      builder: (context, state, _) => Opacity(
                        opacity: s.opacity,
                        child: Image.asset(_referencePath(s.source, state), fit: BoxFit.fill, gaplessPlayback: true),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  static String _referencePath(ReferenceSource src, MascotState state) => switch (src) {
        ReferenceSource.master => 'assets/reference/master_idle.png',
        ReferenceSource.sheet =>
          switch (state) {
            MascotState.wave || MascotState.think || MascotState.cover => 'assets/reference/master_idle.png',
            MascotState.asleep => 'assets/reference/sheet_sleepy.png',
            _ => 'assets/reference/sheet_${state.name}.png',
          },
        ReferenceSource.cap => 'assets/reference/accessory_cap.png',
      };
}

// ------------------------------------------------------------------ controls

class _Panel extends ConsumerWidget {
  const _Panel({required this.controller});
  final MascotController controller;

  static const _accessoryLabels = {
    MascotAccessory.cap: 'Cap',
    MascotAccessory.wizardHat: 'Wizard hat',
    MascotAccessory.partyHat: 'Party hat',
    MascotAccessory.roundGlasses: 'Round glasses',
    MascotAccessory.starGlasses: 'Star glasses',
    MascotAccessory.cape: 'Cape',
    MascotAccessory.scarf: 'Scarf',
    MascotAccessory.crown: 'Crown',
    MascotAccessory.headphones: 'Headphones',
    MascotAccessory.bow: 'Bow',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(playgroundProvider);
    final n = ref.read(playgroundProvider.notifier);
    return Container(
      margin: const EdgeInsets.fromLTRB(LikhoSpace.s2, 0, LikhoSpace.s2, LikhoSpace.s2),
      decoration: BoxDecoration(
        color: LikhoColors.surface,
        borderRadius: BorderRadius.circular(LikhoRadius.card),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LikhoRadius.card),
        child: ListView(
          padding: const EdgeInsets.all(LikhoSpace.s2),
          children: [
            const _Heading('Screens'),
            Wrap(
              spacing: LikhoSpace.s1,
              runSpacing: LikhoSpace.s1,
              children: [
                LikhoButton(
                  label: 'Splash',
                  onTap: () => Navigator.of(context).push(LikhoRoute<void>(
                    builder: (ctx) => SplashScreen(onDone: () => Navigator.of(ctx).pop()),
                  )),
                ),
                LikhoButton(
                  label: 'World Map',
                  onTap: () => Navigator.of(context).push(LikhoRoute<void>(
                    rise: false,
                    builder: (ctx) => WorldMapScreen(onOpenLevel: (n) => AppFlow.openLevel(ctx, n)),
                  )),
                ),
              ],
            ),
            const _Heading('All screens (prototype menu)'),
            Wrap(
              spacing: LikhoSpace.s1,
              runSpacing: LikhoSpace.s1,
              children: [for (final k in AppFlowJump.screens) LikhoButton(label: k, fontSize: 14, onTap: () => AppFlowJump.open(context, k))],
            ),
            const _Heading('Play a level (skips the intro)'),
            Wrap(
              spacing: LikhoSpace.s1,
              runSpacing: LikhoSpace.s1,
              children: [
                for (var n = 1; n <= 36; n++) LikhoButton(label: '$n', onTap: () => AppFlow.openLevel(context, n, skipIntro: true)),
              ],
            ),
            Row(
              children: [
                LikhoToggle(
                  value: ref.watch(referenceOverlayProvider).enabled,
                  onChanged: (_) => ref.read(referenceOverlayProvider.notifier).toggle(),
                ),
                const SizedBox(width: LikhoSpace.s1),
                Expanded(
                  child: Text('Screen reference overlay (screens hold their last frame)',
                      style: LikhoFonts.title(size: 18, weight: FontWeight.w500)),
                ),
              ],
            ),
            const _Heading('States'),
            ValueListenableBuilder<MascotState>(
              valueListenable: controller.stateListenable,
              builder: (context, current, _) => Wrap(
                spacing: LikhoSpace.s1,
                runSpacing: LikhoSpace.s1,
                children: [
                  for (final st in MascotState.values)
                    LikhoButton(label: _title(st.name), selected: st == current, onTap: () => n.play(st)),
                ],
              ),
            ),
            const SizedBox(height: LikhoSpace.s2),
            ValueListenableBuilder<bool>(
              valueListenable: controller.speakingListenable,
              builder: (context, speaking, _) => LikhoButton(
                label: speaking ? 'Speaking…' : 'Say hello',
                height: LikhoSize.mainButton,
                fontSize: 24,
                color: LikhoColors.primary,
                selected: speaking,
                selectedColor: LikhoColors.success,
                onTap: () => controller.say(MascotPlayground.sampleAudio),
              ),
            ),
            const _Heading('Body colour'),
            Wrap(
              children: [
                for (final sw in BodySwatch.options)
                  LikhoSwatch(color: sw.key, selected: sw.key == s.color, onTap: () => n.setColor(sw.key)),
              ],
            ),
            const _Heading('Accessory'),
            Wrap(
              spacing: LikhoSpace.s1,
              runSpacing: LikhoSpace.s1,
              children: [
                LikhoButton(label: 'None', selected: s.accessory == null, onTap: () => n.setAccessory(null)),
                for (final e in _accessoryLabels.entries)
                  LikhoButton(label: e.value, selected: s.accessory == e.key, onTap: () => n.setAccessory(e.key)),
              ],
            ),
            const _Heading('Reference overlay'),
            Row(
              children: [
                LikhoToggle(value: s.overlay, onChanged: n.setOverlay),
                const SizedBox(width: LikhoSpace.s1),
                Expanded(
                  child: Slider(value: s.opacity, onChanged: s.overlay ? n.setOpacity : null),
                ),
                SizedBox(
                  width: 56,
                  child: Text('${(s.opacity * 100).round()}%', textAlign: TextAlign.right, style: LikhoFonts.title(size: 18)),
                ),
              ],
            ),
            Wrap(
              spacing: LikhoSpace.s1,
              runSpacing: LikhoSpace.s1,
              children: [
                LikhoButton(label: 'Master', selected: s.source == ReferenceSource.master, onTap: () => n.setSource(ReferenceSource.master)),
                LikhoButton(label: 'Expression sheet', selected: s.source == ReferenceSource.sheet, onTap: () => n.setSource(ReferenceSource.sheet)),
                LikhoButton(label: 'Cap', selected: s.source == ReferenceSource.cap, onTap: () => n.setSource(ReferenceSource.cap)),
              ],
            ),
            Row(
              children: [
                LikhoToggle(value: s.hold, onChanged: n.setHold),
                const SizedBox(width: LikhoSpace.s1),
                Expanded(child: Text('Hold the pose that matches the reference', style: LikhoFonts.title(size: 18, weight: FontWeight.w500))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _title(String s) => s[0].toUpperCase() + s.substring(1);
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: LikhoSpace.s2, bottom: LikhoSpace.s1),
        child: Text(text, style: LikhoFonts.title(size: 20)),
      );
}
