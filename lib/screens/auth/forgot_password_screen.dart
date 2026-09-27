import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/repositories/auth_repository.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../mascot/mascot.dart';
import '../common/kid_widgets.dart';
import '../common/pencil_figure.dart';
import 'auth_widgets.dart';

/// 05 Forgot password (+ "Forgot · sent" when [sent]), from the prototype.
/// Pencil thinks; after "Link bhejein" an envelope flies off his hand and
/// he cheers.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, required this.onBack, required this.onLogIn, this.email = '', this.sent = false});

  final VoidCallback onBack;
  final ValueChanged<String> onLogIn;
  final String email;
  final bool sent;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.email);
  late bool _sent = widget.sent;
  bool _loading = false, _err = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!AuthValidator.email(_email.text)) return setState(() => _err = true);
    setState(() {
      _err = false;
      _loading = true;
    });
    await ref.read(authProvider.notifier).sendPasswordReset(_email.text);
    if (mounted) {
      setState(() {
        _loading = false;
        _sent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      onBack: widget.onBack,
      bottom: 40,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SizedBox(
            height: 184,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                PencilFigure(width: 130, height: 184, state: _sent ? MascotState.happy : MascotState.think, holdEnd: true),
                if (_sent) const Positioned(top: 70, child: _Envelope()),
              ],
            ),
          ),
        ),
        if (!_sent) ...[
          Text(
            'Password bhool gaye?',
            textAlign: TextAlign.center,
            style: LikhoFonts.title(size: 30, weight: FontWeight.w800),
          ),
          Text(
            'Apni email likhein, hum naya password banane ka link bhejenge.',
            textAlign: TextAlign.center,
            style: LikhoFonts.body(size: 15, color: UiColors.inkBody, height: 1.45),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: AuthField(
              controller: _email,
              hint: 'aap@email.com',
              shadow: false,
              error: _err ? 'Sahi email likhein' : null,
              onChanged: (_) => _err ? setState(() => _err = false) : null,
              onSubmitted: (_) => _submit(),
            ),
          ),
          SubmitButton(label: 'Link bhejein', loading: _loading, onTap: _submit),
        ] else
          RiseIn(
            delay: .5,
            seconds: .4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Apni email check karein',
                  textAlign: TextAlign.center,
                  style: LikhoFonts.title(size: 30, weight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  'Link ${_email.text.trim()} par bhej diya gaya hai.',
                  textAlign: TextAlign.center,
                  style: LikhoFonts.body(size: 15, color: UiColors.inkBody, height: 1.45),
                ),
                const SizedBox(height: 22),
                BigButton(label: 'Login par wapas', white: true, height: 70, fontSize: 21, onTap: () => widget.onLogIn(_email.text)),
              ],
            ),
          ),
      ],
    );
  }
}

/// envFly 1.4 s (delay .2 s): the mail card lifts, tilts and flies up-right,
/// shrinking and fading.
class _Envelope extends StatelessWidget {
  const _Envelope();

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(30 + 32, 0), // margin-left 30 from the centre line
    child: Entrance(
      delay: const Duration(milliseconds: 200),
      duration: const Duration(milliseconds: 1400),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: LikhoColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: GameColors.ink15, offset: Offset(0, 8), blurRadius: 20)],
        ),
        child: const Center(child: SymbolIcon(Symbols.mail_rounded, size: 38, fill: true, color: LikhoColors.secondary)),
      ),
      builder: (context, t, child) {
        const c = Cubic(.3, .6, .4, 1);
        final x = keyframes(t, const [(0, 0), (.3, -10), (1, 170)], c);
        final y = keyframes(t, const [(0, 0), (.3, -18), (1, -330)], c);
        final r = keyframes(t, const [(0, 0), (.3, -10), (1, 24)], c);
        final s = keyframes(t, const [(0, 1), (.3, 1.05), (1, .4)], c);
        final o = keyframes(t, const [(0, 1), (.3, 1), (1, 0)], c);
        return Opacity(
          opacity: o.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(x, y),
            child: Transform.rotate(
              angle: r * 3.14159265 / 180,
              child: Transform.scale(scale: s, child: child),
            ),
          ),
        );
      },
    ),
  );
}
