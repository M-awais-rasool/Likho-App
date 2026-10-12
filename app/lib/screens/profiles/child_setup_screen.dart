import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/api/api_client.dart';
import '../../data/family.dart';
import '../../feedback/app_feedback.dart';
import '../../feedback/pencil_lines.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../mascot/mascot.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';
import '../common/toast.dart';

enum ChildSetupMode { add, edit }

/// 07 Onboarding "Add child" (3 steps) and "Edit child", from the prototype:
/// name (parents type it) -> age (tap a birthday cake) -> Pencil's colour.
/// Adding a child, Pencil asks each step out loud ([PencilLines]).
/// Adding finishes with [onDone] (placement warm-up next); editing saves and
/// finishes with [onDone] too. In edit mode "Profile delete" asks first and
/// then calls [onDeleted].
class ChildSetupScreen extends ConsumerStatefulWidget {
  const ChildSetupScreen({super.key, required this.mode, required this.onBack, required this.onDone, this.onDeleted});

  final ChildSetupMode mode;
  final VoidCallback onBack, onDone;
  final VoidCallback? onDeleted;

  static const ages = [5, 6, 7, 8];

  @override
  ConsumerState<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends ConsumerState<ChildSetupScreen> {
  late final ChildProfile? _editing = widget.mode == ChildSetupMode.edit ? ref.read(familyProvider).active : null;
  late final _name = TextEditingController(text: _editing?.name ?? '');
  late int? _age = _editing?.age;
  late Color _color = _editing?.color ?? LikhoColors.primary;
  int _step = 0;
  bool _happy = false;
  bool _confirmDelete = false;
  bool _saving = false; // waiting for the server
  int _splash = 0; // colour splash replays
  final List<Timer> _timers = [];

  bool get _edit => widget.mode == ChildSetupMode.edit;
  bool get _nameOk => _name.text.trim().isNotEmpty;

  /// Pencil's question for a step (when adding: a parent edits in silence),
  /// once the step has risen in.
  String? _line(String line) => _edit ? null : line;
  static const _sayAt = Duration(milliseconds: 450);

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _name.dispose();
    super.dispose();
  }

  void _later(int ms, VoidCallback f) => _timers.add(
    Timer(Duration(milliseconds: ms), () {
      if (mounted) f();
    }),
  );

  Future<void> _next() async {
    if (_saving) return;
    final fb = ref.read(feedbackProvider);
    if (_step == 0 && !_nameOk) {
      fb.nope();
      return;
    }
    FocusScope.of(context).unfocus();
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    final n = ref.read(familyProvider.notifier);
    setState(() => _saving = true);
    try {
      if (_edit) {
        await n.editActive(name: _name.text, age: _age, color: _color);
      } else {
        await n.addChild(name: _name.text, age: _age ?? 6, color: _color);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      fb.nope();
      Toast.show(context, saveError(e));
      return;
    }
    if (!mounted) return;
    fb.done();
    widget.onDone();
  }

  /// A short parent-friendly reason a save failed.
  static String saveError(ApiException e) => switch (e.code) {
    'offline' => 'No internet connection. Please try again.',
    'too_many_children' => 'You can add up to 4 children.',
    'last_child' => "The last profile can't be deleted.",
    _ => "Couldn't save. Please try again.",
  };

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step > 0) {
      setState(() => _step--);
    } else {
      widget.onBack();
    }
  }

  void _pickAge(int n) {
    ref.read(feedbackProvider).candle();
    setState(() => _age = n);
    _later(420, () => setState(() => _step = 2));
  }

  void _pickColor(Color c) {
    ref.read(feedbackProvider).paint();
    setState(() {
      _color = c;
      _happy = true;
      _splash++;
    });
    _later(1200, () => setState(() => _happy = false));
  }

  @override
  Widget build(BuildContext context) {
    return StatusBar(
      child: Material(
        color: LikhoColors.background,
        child: Stack(
          children: [
            MaxWidth(
              width: 460,
              child: ScrollFill(
                padding: EdgeInsets.fromLTRB(24, frameTop(context, 58), 24, 40),
                child: Column(
                  children: [
                    _header(),
                    Expanded(
                      child: KeyedSubtree(
                        key: ValueKey(_step),
                        child: RiseIn(
                          child: switch (_step) {
                            0 => _nameStep(),
                            1 => _ageStep(),
                            _ => _colorStep(),
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_confirmDelete) _DeleteConfirm(name: _editing?.name ?? '', onNo: () => setState(() => _confirmDelete = false), onYes: _delete),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(familyProvider.notifier).deleteActive();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _confirmDelete = false;
      });
      Toast.show(context, saveError(e));
      return;
    }
    if (!mounted) return;
    setState(() => _confirmDelete = false);
    widget.onDeleted?.call();
  }

  Widget _header() => SizedBox(
    height: 48,
    child: Row(
      children: [
        CircleIconButton.back(onTap: _back, size: 44, iconSize: 22, shadowY: 3),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: springOut,
                    height: 12,
                    width: i == _step ? 28 : 12,
                    decoration: BoxDecoration(color: i <= _step ? LikhoColors.primary : GameColors.ink14, borderRadius: BorderRadius.circular(6)),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_edit)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ref.read(feedbackProvider).tap();
              setState(() => _confirmDelete = true);
            },
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: UiColors.dangerTint, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const SymbolIcon(Symbols.delete_rounded, size: 18, color: UiColors.danger),
                  const SizedBox(width: 4),
                  Text(
                    'Delete profile',
                    style: LikhoFonts.body(size: 13, weight: FontWeight.w700, color: UiColors.danger),
                  ),
                ],
              ),
            ),
          )
        else
          const SizedBox(width: 44),
      ],
    ),
  );

  // ---------------------------------------------------------------- step 1: name
  Widget _nameStep() => Column(
    children: [
      const SizedBox(height: 22),
      PencilFigure(
        width: 130,
        height: 184,
        color: _color,
        state: _happy ? MascotState.happy : MascotState.watching,
        lookDown: true,
        say: _line(PencilLines.name),
        sayAt: _sayAt,
      ),
      const SizedBox(height: 14),
      Text(
        "Child's name?",
        textAlign: TextAlign.center,
        style: LikhoFonts.title(size: 34, weight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SymbolIcon(Symbols.supervisor_account_rounded, size: 18, color: UiColors.inkBody),
          const SizedBox(width: 6),
          Flexible(
            child: Text('A parent should do this step', style: LikhoFonts.body(size: 15, color: UiColors.inkBody)),
          ),
        ],
      ),
      const SizedBox(height: 26),
      Container(
        height: 84,
        decoration: BoxDecoration(
          color: LikhoColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: LikhoColors.primary, width: 3),
          boxShadow: const [BoxShadow(color: ProfileColors.nameShadow, offset: Offset(0, 6))],
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: _name,
          maxLength: 14,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.words,
          cursorColor: LikhoColors.ink,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _next(),
          style: LikhoFonts.title(size: 34).copyWith(height: 1.2),
          decoration: InputDecoration(
            hintText: 'Enter name',
            hintStyle: LikhoFonts.title(size: 34, color: UiColors.inkBody).copyWith(height: 1.2),
            border: InputBorder.none,
            counterText: '',
            isCollapsed: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
      const Spacer(),
      BigButton(label: 'Next', iconAfter: Symbols.arrow_forward_rounded, opacity: _nameOk ? 1 : .45, onTap: _next),
    ],
  );

  // ---------------------------------------------------------------- step 2: age
  Widget _ageStep() => Column(
    children: [
      const SizedBox(height: 18),
      // talks while saying the line (or all along when editing, as before)
      PencilFigure(
        width: 96,
        height: 136,
        color: _color,
        state: _edit ? MascotState.talking : MascotState.idle,
        say: _line(PencilLines.age),
        sayAt: _sayAt,
      ),
      const SizedBox(height: 12),
      Text("Child's age?", style: LikhoFonts.title(size: 34, weight: FontWeight.w800)),
      const SizedBox(height: 30),
      SizedBox(
        width: 140 * 2 + 22,
        child: Wrap(
          spacing: 22,
          runSpacing: 22,
          children: [for (final n in ChildSetupScreen.ages) _AgeCake(age: n, selected: _age == n, onTap: () => _pickAge(n))],
        ),
      ),
    ],
  );

  // ---------------------------------------------------------------- step 3: colour
  Widget _colorStep() => Column(
    children: [
      const SizedBox(height: 18),
      Text(
        "Pick Pencil's colour!",
        textAlign: TextAlign.center,
        style: LikhoFonts.title(size: 32, weight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: 260,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 10,
              top: 20,
              child: _ColorSplash(color: _color, replay: _splash),
            ),
            // picking a colour stops the line: Pencil cheers instead
            PencilFigure(
              width: 170,
              height: 240,
              color: _color,
              state: _happy ? MascotState.happy : MascotState.idle,
              say: _line(PencilLines.colour),
              sayAt: _sayAt,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: 72 * 3 + 26 * 2,
        child: Wrap(
          spacing: 26,
          runSpacing: 18,
          children: [
            for (final s in BodySwatch.options) _Swatch(color: s.key, selected: s.key.toARGB32() == _color.toARGB32(), onTap: () => _pickColor(s.key)),
          ],
        ),
      ),
      const Spacer(),
      BigButton(
        label: 'Done!',
        icon: _saving ? null : Symbols.check_circle_rounded,
        iconFill: true,
        leading: _saving ? const ButtonSpinner() : null,
        onTap: _saving ? null : _next,
      ),
    ],
  );
}

/// Round age button with [age] birthday candles.
class _AgeCake extends StatefulWidget {
  const _AgeCake({required this.age, required this.selected, required this.onTap});
  final int age;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AgeCake> createState() => _AgeCakeState();
}

class _AgeCakeState extends State<_AgeCake> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? .9 : 1,
        duration: const Duration(milliseconds: 200),
        curve: springOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: sel ? LikhoColors.primary : LikhoColors.surface,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: sel ? LikhoColors.primaryDeep : GameColors.ink10, offset: const Offset(0, 6))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 30,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var k = 0; k < widget.age; k++) ...[
                      if (k > 0) const SizedBox(width: 4),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Sway(
                            seconds: 1,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 7,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: ProfileColors.flame,
                                borderRadius: BorderRadius.vertical(top: Radius.elliptical(3.5, 5.4), bottom: Radius.elliptical(3.5, 3.6)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 6,
                            height: 16,
                            decoration: BoxDecoration(color: ProfileColors.candles[k % 4], borderRadius: BorderRadius.circular(2)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text('${widget.age}', style: LikhoFonts.title(size: 54, weight: FontWeight.w800).copyWith(height: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paint splash behind Pencil: a soft blob that bursts in the picked colour.
class _ColorSplash extends StatelessWidget {
  const _ColorSplash({required this.color, required this.replay});
  final Color color;
  final int replay;

  // border-radius: 46% 54% 42% 58% / 55% 45% 55% 45% on 240 x 240
  static const _shape = BorderRadius.only(
    topLeft: Radius.elliptical(110.4, 132),
    topRight: Radius.elliptical(129.6, 108),
    bottomRight: Radius.elliptical(100.8, 132),
    bottomLeft: Radius.elliptical(139.2, 108),
  );

  @override
  Widget build(BuildContext context) {
    final blob = Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(color: replay == 0 ? LikhoColors.primary : color, borderRadius: _shape),
    );
    if (replay == 0) return Opacity(opacity: .25, child: blob);
    return Entrance(
      key: ValueKey(replay),
      duration: const Duration(milliseconds: 600),
      child: blob,
      builder: (context, t, child) {
        final s = keyframes(t, const [(0, .2), (.6, 1.15), (1, 1)], settleEase);
        final r = keyframes(t, const [(0, 0), (.6, 40), (1, 60)], settleEase);
        final o = keyframes(t, const [(0, .9), (.6, .5), (1, .28)], settleEase);
        return Opacity(
          opacity: o,
          child: Transform.rotate(
            angle: r * math.pi / 180,
            child: Transform.scale(scale: s, child: child),
          ),
        );
      },
    );
  }
}

class _Swatch extends StatefulWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final sel = widget.selected;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? .88 : (sel ? 1.08 : 1),
        duration: const Duration(milliseconds: 250),
        curve: springOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            boxShadow: sel
                ? [BoxShadow(color: c, spreadRadius: 8), const BoxShadow(color: LikhoColors.background, spreadRadius: 4)]
                : [BoxShadow(color: ProfileColors.deepFor(c), offset: const Offset(0, 5))],
          ),
          child: const CustomPaint(
            // inset 0 -6px 0 rgba(0,0,0,.08), inset 0 4px 0 rgba(255,255,255,.35)
            painter: InsetShadowPainter([(Offset(0, -6), GameColors.black08), (Offset(0, 4), GameColors.white35)]),
          ),
        ),
      ),
    );
  }
}

class _DeleteConfirm extends StatelessWidget {
  const _DeleteConfirm({required this.name, required this.onNo, required this.onYes});
  final String name;
  final VoidCallback onNo, onYes;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: FadeIn(
      seconds: .2,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: ColoredBox(
          color: UiColors.scrimSoft,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: BubbleIn(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(color: LikhoColors.surface, borderRadius: BorderRadius.circular(LikhoRadius.card)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Delete profile?', style: LikhoFonts.body(size: 20, weight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Text(
                        "All of $name's progress, stars and stickers will be permanently deleted.",
                        style: LikhoFonts.body(size: 15, color: UiColors.inkBody, height: 1.5),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: FlatButton(label: 'Cancel', color: UiColors.chip, onTap: onNo),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FlatButton(label: 'Delete', color: LikhoColors.ink, textColor: LikhoColors.surface, onTap: onYes),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
