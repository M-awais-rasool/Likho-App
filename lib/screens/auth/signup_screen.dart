import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../common/kid_widgets.dart';
import 'auth_widgets.dart';

/// 03 Sign up (+ 04 "Sign up · Email" when [emailOpen]), from the prototype.
///
/// Apple / Google sign in at once; "Email se" opens the email form. The form
/// checks the email and a 6+ letter password, waits for the account, shows
/// a green check and Pencil cheering, then [onDone] (Who's playing).
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({
    super.key,
    required this.onBack,
    required this.onDone,
    required this.onLogIn,
    required this.onTerms,
    this.emailOpen = false,
    this.email = '',
  });

  final VoidCallback onBack, onDone, onTerms;
  final ValueChanged<String> onLogIn;
  final bool emailOpen;
  final String email;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  late final _email = TextEditingController(text: widget.email);
  final _pw = TextEditingController();
  late bool _emailOpen = widget.emailOpen;
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
    if (!AuthValidator.email(_email.text)) return setState(() => _err = AuthError.email);
    if (!AuthValidator.password(_pw.text)) return setState(() => _err = AuthError.password);
    setState(() {
      _err = AuthError.none;
      _loading = true;
    });
    await ref.read(authProvider.notifier).signUp(_email.text, _pw.text);
    if (!mounted) return;
    setState(() => _loading = false);
    _finish(const Duration(milliseconds: 900));
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      onBack: widget.onBack,
      children: [
        AuthHeader(
          title: 'Parent account banayein',
          subtitle: 'Bache ko email ya password ki zaroorat nahi.',
          mascot: authMascotState(ok: _ok, passwordFocus: _pwFocus, error: _err),
        ),
        if (!_emailOpen)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                SocialButton.apple(onTap: () => _social(SocialProvider.apple)),
                const SizedBox(height: 12),
                SocialButton.google(onTap: () => _social(SocialProvider.google)),
                const SizedBox(height: 12),
                SocialButton.email(onTap: () => setState(() => _emailOpen = true)),
              ],
            ),
          )
        else
          RiseIn(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthField(
                    controller: _email,
                    label: 'Email',
                    hint: 'aap@email.com',
                    error: _err == AuthError.email ? 'Sahi email likhein, maslan naam@gmail.com' : null,
                    onChanged: (_) => _err != AuthError.none ? setState(() => _err = AuthError.none) : null,
                  ),
                  const SizedBox(height: 14),
                  AuthField(
                    controller: _pw,
                    label: 'Password',
                    hint: 'Kam az kam 6 huroof',
                    password: true,
                    error: _err == AuthError.password ? 'Password kam az kam 6 huroof ka ho' : null,
                    onFocus: (f) => setState(() => _pwFocus = f),
                    onChanged: (_) => _err != AuthError.none ? setState(() => _err = AuthError.none) : null,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 18),
                  SubmitButton(label: 'Account banayein', loading: _loading, ok: _ok, onTap: _submit),
                ],
              ),
            ),
          ),
        const Spacer(),
        _Terms(onTap: widget.onTerms),
        Center(
          child: TextLink(text: 'Pehle se account hai? Login', onTap: () => widget.onLogIn(_email.text)),
        ),
      ],
    );
  }
}

class _Terms extends StatelessWidget {
  const _Terms({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = LikhoFonts.body(size: 13, color: LikhoColors.inkMuted, height: 1.5);
    // the prototype's <a> tags: bold, in the browser's link blue
    final bold = LikhoFonts.body(size: 13, weight: FontWeight.w800, color: UiColors.link, height: 1.5);
    return GestureDetector(
      onTap: onTap,
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'Aage barh kar aap hamari '),
            TextSpan(text: 'Privacy Policy', style: bold),
            const TextSpan(text: ' aur '),
            TextSpan(text: 'Terms', style: bold),
            const TextSpan(text: ' se mutafiq hain.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
