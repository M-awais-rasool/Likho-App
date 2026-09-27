import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SocialProvider { apple, google }

/// Parent account sign-in. Only parents have accounts; children never type
/// an email or password.
abstract class AuthRepository {
  Future<void> signUp(String email, String password);
  Future<void> logIn(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> socialSignIn(SocialProvider provider);
  Future<void> logOut();
}

/// The prototype's behaviour until the auth backend exists: every valid
/// request succeeds after a short wait.
class DemoAuthRepository implements AuthRepository {
  const DemoAuthRepository({this.delay = const Duration(milliseconds: 1200)});
  final Duration delay;

  @override
  Future<void> signUp(String email, String password) => Future.delayed(delay);
  @override
  Future<void> logIn(String email, String password) => Future.delayed(delay);
  @override
  Future<void> sendPasswordReset(String email) => Future.delayed(delay);
  @override
  Future<void> socialSignIn(SocialProvider provider) async {}
  @override
  Future<void> logOut() async {}
}

/// Form checks shared by sign up, login and forgot password.
abstract final class AuthValidator {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const minPassword = 6;

  static bool email(String v) => _email.hasMatch(v.trim());
  static bool password(String v) => v.length >= minPassword;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => const DemoAuthRepository());

/// The signed-in parent (null = signed out / guest).
@immutable
class AuthSession {
  const AuthSession({this.email});
  final String? email;
  bool get signedIn => email != null;
}

class AuthNotifier extends Notifier<AuthSession> {
  @override
  AuthSession build() => const AuthSession();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> signUp(String email, String password) async {
    await _repo.signUp(email.trim(), password);
    state = AuthSession(email: email.trim());
  }

  Future<void> logIn(String email, String password) async {
    await _repo.logIn(email.trim(), password);
    state = AuthSession(email: email.trim());
  }

  Future<void> socialSignIn(SocialProvider p) async {
    await _repo.socialSignIn(p);
    state = AuthSession(email: p == SocialProvider.apple ? 'parent@icloud.com' : 'parent@gmail.com');
  }

  Future<void> sendPasswordReset(String email) => _repo.sendPasswordReset(email.trim());

  Future<void> logOut() async {
    await _repo.logOut();
    state = const AuthSession();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthSession>(AuthNotifier.new);
