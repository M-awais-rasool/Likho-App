import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../feedback/app_feedback.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../mascot/mascot.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';
import '../gameplay/widgets/game_buttons.dart';

/// Pieces shared by 03 Sign up, 04 Login and 05 Forgot password.

enum AuthError { none, email, password }

/// Pencil reacts to the form (prototype auth.mascot): cheers when done,
/// covers his eyes while the password is typed, encourages after a mistake.
MascotState authMascotState({required bool ok, required bool passwordFocus, required AuthError error}) => ok
    ? MascotState.happy
    : passwordFocus
    ? MascotState.cover
    : error != AuthError.none
    ? MascotState.encourage
    : MascotState.idle;

/// Screen frame: 58 px top padding, back button, scrolling column, gap 14.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.onBack, required this.children, this.scroll = true, this.bottom = 36});
  final VoidCallback onBack;
  final List<Widget> children;
  final bool scroll;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final pad = EdgeInsets.fromLTRB(24, frameTop(context, 58), 24, bottom);
    final column = [
      Align(
        alignment: Alignment.centerLeft,
        child: CircleIconButton.back(onTap: onBack),
      ),
      for (final c in children) ...[const SizedBox(height: 14), c],
    ];
    return StatusBar(
      child: Material(
        color: LikhoColors.background,
        child: MaxWidth(
          width: 440,
          child: scroll
              ? ScrollFill(
                  padding: pad,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: column),
                )
              : Padding(
                  padding: pad,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: column),
                ),
        ),
      ),
    );
  }
}

/// Pencil (78 x 110) next to the title and a line of help.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle, required this.mascot});
  final String title, subtitle;
  final MascotState mascot;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      PencilFigure(width: 78, height: 110, state: mascot, holdEnd: true),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: LikhoFonts.title(size: 30, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle, style: LikhoFonts.body(size: 15, color: UiColors.inkBody, height: 1.4)),
          ],
        ),
      ),
    ],
  );
}

/// Label + white field with a 3 px bottom line (orange on error) + hint.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    this.label,
    this.error,
    this.password = false,
    this.onFocus,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.shadow = true,
  });

  final TextEditingController controller;
  final String hint;
  final String? label;
  final String? error;
  final bool password;
  final ValueChanged<bool>? onFocus;
  final ValueChanged<String>? onChanged, onSubmitted;
  final TextInputType? keyboardType;
  final bool shadow;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final FocusNode _focus = FocusNode();
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => widget.onFocus?.call(_focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final err = widget.error;
    final field = Container(
      height: 60,
      decoration: BoxDecoration(
        color: LikhoColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [if (widget.shadow) const BoxShadow(color: UiColors.ink05, offset: Offset(0, 2))],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border(bottom: BorderSide(color: err != null ? LikhoColors.hint : GameColors.ink12, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              obscureText: widget.password && !_show,
              keyboardType: widget.keyboardType ?? (widget.password ? TextInputType.visiblePassword : TextInputType.emailAddress),
              autocorrect: false,
              enableSuggestions: !widget.password,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              cursorColor: LikhoColors.ink,
              style: LikhoFonts.body(size: 18),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: LikhoFonts.body(size: 18, color: UiColors.inkHint),
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.fromLTRB(18, 0, widget.password ? 8 : 18, 0),
              ),
            ),
          ),
          if (widget.password)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                AppFeedback.of(context).tap();
                setState(() => _show = !_show);
              },
              child: SizedBox.square(
                dimension: 44,
                child: Center(child: SymbolIcon(_show ? Symbols.visibility_off_rounded : Symbols.visibility_rounded, size: 24, color: LikhoColors.inkMuted)),
              ),
            ),
          if (widget.password) const SizedBox(width: 8),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: LikhoFonts.body(size: 14, weight: FontWeight.w700, color: UiColors.inkBody),
          ),
          const SizedBox(height: 6),
        ],
        field,
        if (err != null) ...[const SizedBox(height: 6), FormHint(err)],
      ],
    );
  }
}

/// Orange-brown hint under a field ("Sahi email likhein").
class FormHint extends StatelessWidget {
  const FormHint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SymbolIcon(Symbols.info_rounded, size: 18, color: UiColors.error),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: LikhoFonts.body(size: 13, weight: FontWeight.w700, color: UiColors.error),
        ),
      ),
    ],
  );
}

/// Yellow submit button that shows a spinner while waiting and a green
/// check when done.
class SubmitButton extends StatelessWidget {
  const SubmitButton({super.key, required this.label, required this.onTap, this.loading = false, this.ok = false});
  final String label;
  final VoidCallback onTap;
  final bool loading, ok;

  @override
  Widget build(BuildContext context) => BigButton(
    label: label,
    height: 72,
    fontSize: 22,
    onTap: loading ? null : onTap,
    leading: loading
        ? const ButtonSpinner()
        : ok
        ? const PopIn(seconds: .3, child: SymbolIcon(Symbols.check_circle_rounded, size: 28, fill: true, color: UiColors.okGreen))
        : null,
  );
}

/// "Continue with Apple / Google" and "Email se" buttons.
class SocialButton extends StatelessWidget {
  const SocialButton.apple({super.key, required this.onTap, this.label = 'Continue with Apple', this.height = 64, this.fontSize = 18, this.radius = 20})
    : _kind = 0;
  const SocialButton.google({super.key, required this.onTap, this.label = 'Continue with Google', this.height = 64, this.fontSize = 18, this.radius = 20})
    : _kind = 1;
  const SocialButton.email({super.key, required this.onTap, this.label = 'Email se', this.height = 64, this.fontSize = 18, this.radius = 20}) : _kind = 2;

  final int _kind;
  final VoidCallback onTap;
  final String label;
  final double height, fontSize, radius;

  @override
  Widget build(BuildContext context) {
    final small = height < 60;
    final fg = _kind == 1 ? LikhoColors.ink : LikhoColors.surface;
    final Widget icon = switch (_kind) {
      0 => SymbolIcon(Symbols.phone_iphone_rounded, size: small ? 22 : 24, fill: true, color: fg),
      1 => GoogleDot(size: small ? 22 : 26),
      _ => SymbolIcon(Symbols.mail_rounded, size: 24, color: fg),
    };
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return PushButton(
      onTap: withSound(context, ButtonSound.press, onTap),
      color: switch (_kind) {
        0 => UiColors.apple,
        1 => LikhoColors.surface,
        _ => LikhoColors.secondary,
      },
      edgeColor: _kind == 2 ? GameColors.secondaryDeep : null,
      edge: _kind == 2 ? 5 : 0,
      height: height,
      width: double.infinity,
      pressScale: .97,
      shape: _kind == 1 ? shape.copyWith(side: const BorderSide(color: GameColors.ink10, width: 2)) : shape,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          SizedBox(width: small ? 8 : 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: LikhoFonts.body(size: fontSize, weight: FontWeight.w700, color: fg),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The prototype's stand-in Google mark: a four-colour ring.
class GoogleDot extends StatelessWidget {
  const GoogleDot({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        // conic-gradient starts at 12 o'clock
        gradient: SweepGradient(
          transform: GradientRotation(-math.pi / 2),
          colors: [
            UiColors.googleBlue,
            UiColors.googleBlue,
            UiColors.googleGreen,
            UiColors.googleGreen,
            UiColors.googleYellow,
            UiColors.googleYellow,
            UiColors.googleCoral,
            UiColors.googleCoral,
          ],
          stops: [0, .25, .25, .5, .5, .75, .75, 1],
        ),
      ),
      child: Center(
        child: Container(
          width: size * 14 / 26,
          height: size * 14 / 26,
          decoration: const BoxDecoration(color: LikhoColors.surface, shape: BoxShape.circle),
        ),
      ),
    ),
  );
}
