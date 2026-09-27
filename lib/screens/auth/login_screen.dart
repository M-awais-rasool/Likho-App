import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../feedback/app_feedback.dart';
import '../../design/tokens.dart';
import '../common/kid_widgets.dart';
import 'auth_widgets.dart';

/// 04 Login, from the prototype: email + password (checked like sign up),
/// "Password bhool gaye?", or Apple / Google. Success -> [onDone].
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.onBack, required this.onDone, required this.onSignUp, required this.onForgot, this.email = ''});

  final VoidCallback onBack, onDone;
  final ValueChanged<String> onSignUp, onForgot;
  final String email;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final _email = TextEditingController(text: widget.email);
  final _pw = TextEditingController();
  AuthError _err = AuthError.none;
  bool _loading = false, _ok = false, _pwFocus = false;
  Timer? _next;

  @override
  void dispose() {
    _next?.cancel();
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  void _finish(Duration after) {
    ref.read(feedbackProvider).done();
    setState(() => _ok = true);
    _next = Timer(after, () {
      if (mounted) widget.onDone();
    });
  }

  Future<void> _social(SocialProvider p) async {
    if (_ok) return;
    await ref.read(authProvider.notifier).socialSignIn(p);
    if (mounted) _finish(const Duration(milliseconds: 800));
  }

  Future<void> _submit() async {
    if (_loading || _ok) return;
    FocusScope.of(context).unfocus();
    final fb = ref.read(feedbackProvider);
    if (!AuthValidator.email(_email.text)) {
      fb.nope();
      return setState(() => _err = AuthError.email);
    }
    if (!AuthValidator.password(_pw.text)) {
      fb.nope();
      return setState(() => _err = AuthError.password);
    }
    setState(() {
      _err = AuthError.none;
      _loading = true;
    });
    await ref.read(authProvider.notifier).logIn(_email.text, _pw.text);
    if (!mounted) return;
    setState(() => _loading = false);
    _finish(const Duration(milliseconds: 900));
  }

  void _clearError(String _) {
    if (_err != AuthError.none) setState(() => _err = AuthError.none);
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      onBack: widget.onBack,
      children: [
        AuthHeader(
          title: 'Wapas khush aamdeed!',
          subtitle: 'Parent account mein login karein.',
          mascot: authMascotState(ok: _ok, passwordFocus: _pwFocus, error: _err),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                controller: _email,
                label: 'Email',
                hint: 'aap@email.com',
                error: _err == AuthError.email ? 'Sahi email likhein' : null,
                onChanged: _clearError,
              ),
              const SizedBox(height: 14),
              AuthField(
                controller: _pw,
                label: 'Password',
                hint: 'Password',
                password: true,
                error: _err == AuthError.password ? 'Password kam az kam 6 huroof ka ho' : null,
                onFocus: (f) => setState(() => _pwFocus = f),
                onChanged: _clearError,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextLink(
                  text: 'Password bhool gaye?',
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  style: LikhoFonts.body(size: 14, weight: FontWeight.w700, color: UiColors.link),
                  onTap: () => widget.onForgot(_email.text),
                ),
              ),
              const SizedBox(height: 14),
              SubmitButton(label: 'Login', loading: _loading, ok: _ok, onTap: _submit),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: Divider(height: 1.5, thickness: 1.5, color: GameColors.ink10)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'ya',
                      style: LikhoFonts.body(size: 13, weight: FontWeight.w700, color: UiColors.inkHint),
                    ),
                  ),
                  const Expanded(child: Divider(height: 1.5, thickness: 1.5, color: GameColors.ink10)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SocialButton.apple(label: 'Apple', height: 58, fontSize: 16, radius: 18, onTap: () => _social(SocialProvider.apple)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SocialButton.google(label: 'Google', height: 58, fontSize: 16, radius: 18, onTap: () => _social(SocialProvider.google)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        Center(
          child: TextLink(text: 'Naya account? Shuru karein', onTap: () => widget.onSignUp(_email.text)),
        ),
      ],
    );
  }
}
