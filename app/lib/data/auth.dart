import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api/api_client.dart';
import 'api/likho_api.dart';
import 'family.dart';

/// Gets a Google ID token on the phone (Google Sign-In).
abstract interface class GoogleIdentity {
  /// The token, or null when the parent closed the Google sheet.
  Future<String?> idToken();
  Future<void> signOut();
}

/// Google Sign-In with Likho's OAuth clients (Google Cloud project "Likho").
/// The server client ID is the Web client: Android returns an ID token for
/// it, which the backend accepts (GOOGLE_CLIENT_IDS). Android itself is
/// matched by package name + signing SHA-1 (one Android client per key:
/// debug, upload, Play app signing). Client IDs are public, not secrets.
/// Both can be replaced at build time:
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=…apps.googleusercontent.com
///   --dart-define=GOOGLE_IOS_CLIENT_ID=…apps.googleusercontent.com (iOS: not set up yet)
class GoogleSignInIdentity implements GoogleIdentity {
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '816545304415-8r86g90icsijfbt7gn258b8mt85vldmk.apps.googleusercontent.com',
  );

  Future<void>? _init;
  Future<void> _ready() => _init ??= GoogleSignIn.instance.initialize(
    clientId: iosClientId.isEmpty ? null : iosClientId,
    serverClientId: serverClientId.isEmpty ? null : serverClientId,
  );

  @override
  Future<String?> idToken() async {
    await _ready();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw const ApiException(0, 'google_no_token', 'Google did not return an ID token');
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _ready();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}

/// Debug builds before Google is set up: `--dart-define=LIKHO_DEV_EMAIL=me@x.com`
/// signs in as that user through the backend's DEV_LOGIN (`dev:<email>`).
class DevIdentity implements GoogleIdentity {
  const DevIdentity(this.email);
  final String email;
  @override
  Future<String?> idToken() async => 'dev:$email';
  @override
  Future<void> signOut() async {}
}

/// The shared test account for trying the app before release: "Test User"
/// on the Welcome screen signs in as [email] through the backend's
/// DEV_LOGIN, then everything works as for a Google account (the same
/// sign-in call, session, children, progress and settings on the server).
///
/// Shown in debug and profile builds; a release build shows it only with
/// `--dart-define=LIKHO_TEST_LOGIN=true`. Another address:
/// `--dart-define=LIKHO_TEST_EMAIL=someone@example.com`. The backend must
/// run with DEV_LOGIN=true (never in production).
abstract final class TestUser {
  static const email = String.fromEnvironment('LIKHO_TEST_EMAIL', defaultValue: 'test.user@likho.app');
  static const enabled = !kReleaseMode || bool.fromEnvironment('LIKHO_TEST_LOGIN');

  /// What the app sends instead of a Google ID token.
  static String get idToken => 'dev:$email';
}

final googleIdentityProvider = Provider<GoogleIdentity>((ref) {
  const dev = String.fromEnvironment('LIKHO_DEV_EMAIL');
  if (kDebugMode && dev.isNotEmpty) return const DevIdentity(dev);
  return GoogleSignInIdentity();
});

enum AuthStatus { restoring, signedOut, signedIn }

/// Who is signed in. [me] = the account as the server last sent it
/// (GET /v1/me shape); the family's live state is in familyProvider.
@immutable
class AuthState {
  const AuthState(this.status, {this.me, this.expired = false});
  final AuthStatus status;
  final Map<String, dynamic>? me;

  /// Signed out by the server, not by the parent (show "sign in again").
  final bool expired;

  bool get signedIn => status == AuthStatus.signedIn;
}

/// The last account snapshot, so a signed-in phone opens offline too.
abstract final class MeSnapshot {
  static const file = 'me.json';

  static Future<void> save(LocalFiles files, Map<String, dynamic> me) => files.write(file, jsonEncode(me));

  static Future<Map<String, dynamic>?> load(LocalFiles files) async {
    final text = await files.read(file);
    if (text == null) return null;
    try {
      return (jsonDecode(text) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }
}

/// Google is the only way in: no sign-up, no passwords. The first
/// "Continue with Google" creates the account, later ones continue it.
class AuthNotifier extends Notifier<AuthState> {
  final Completer<void> _ready = Completer();

  /// Completes once the saved session has been checked at start-up.
  Future<void> get ready => _ready.future;

  LikhoApi get _api => ref.read(apiProvider);
  LocalFiles get _files => ref.read(localFilesProvider);

  @override
  AuthState build() {
    ref.read(apiClientProvider).onSessionLost = _sessionLost;
    Future.microtask(_restore);
    return const AuthState(AuthStatus.restoring);
  }

  /// Async work can finish after the app (or a test) is gone.
  void _set(AuthState s) {
    if (ref.mounted) state = s;
  }

  Future<void> _restore() async {
    try {
      final client = ref.read(apiClientProvider);
      if (!await client.restore()) {
        _set(const AuthState(AuthStatus.signedOut));
        return;
      }
      Map<String, dynamic>? me;
      try {
        me = await _api.me();
        await MeSnapshot.save(_files, me);
      } on ApiException catch (e) {
        if (!e.offline) rethrow;
        me = await MeSnapshot.load(_files); // offline: last known account
      }
      _set(me == null ? const AuthState(AuthStatus.signedOut) : AuthState(AuthStatus.signedIn, me: me));
    } catch (e) {
      debugPrint('Auth restore: $e');
      _set(const AuthState(AuthStatus.signedOut));
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  /// "Continue with Google". Returns whether the account is new, or null
  /// when the parent cancelled. Throws [ApiException] on failure.
  Future<bool?> signInWithGoogle() async {
    final token = await ref.read(googleIdentityProvider).idToken();
    if (token == null) return null;
    return _signIn(token);
  }

  /// "Test User": signs in as [TestUser.email], exactly like Google does
  /// (the backend finds or makes that account). Returns whether it is new.
  Future<bool> signInAsTestUser() => _signIn(TestUser.idToken);

  Future<bool> _signIn(String idToken) async {
    final r = await _api.signInWithGoogle(idToken, device: defaultTargetPlatform.name);
    final me = (r['me'] as Map).cast<String, dynamic>();
    await MeSnapshot.save(_files, me);
    _set(AuthState(AuthStatus.signedIn, me: me));
    return r['isNewAccount'] == true;
  }

  /// Signs out (FamilyNotifier.logOut first sends finished levels still
  /// waiting).
  Future<void> logOut() async {
    await _api.logout();
    await _forget();
  }

  /// Deletes the account on the server, then signs out. Throws on failure.
  Future<void> deleteAccount() async {
    await _api.deleteAccount();
    await _forget();
  }

  Future<void> _forget({bool expired = false}) async {
    await ref.read(googleIdentityProvider).signOut();
    await _files.delete(MeSnapshot.file);
    await _files.delete(FamilyNotifier.outboxFile);
    _set(AuthState(AuthStatus.signedOut, expired: expired));
  }

  /// The server ended the session (signed out elsewhere, account deleted…).
  void _sessionLost() {
    if (ref.mounted && state.signedIn) unawaited(_forget(expired: true));
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
