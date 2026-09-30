import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/api/api_client.dart';
import 'package:likho/data/auth.dart';
import 'package:likho/data/course_providers.dart';
import 'package:likho/data/family.dart';
import 'package:likho/data/progress.dart';
import 'package:likho/data/shop_items.dart';
import 'package:likho/design/tokens.dart';

import 'fake_backend.dart';
import 'test_course.dart';

/// The app's data layer against an in-memory API: each child's progress
/// lives on the server, changes show at once and are sent in the background.
void main() {
  late FakeBackend backend;
  late MemoryFiles files;
  late MemoryTokenStore tokens; // the phone's keychain
  late ProviderContainer c;

  ProviderContainer app() {
    final container = ProviderContainer(overrides: fakeBackendOverrides(backend, files: files, tokens: tokens));
    addTearDown(container.dispose);
    container.listen(familyProvider, (_, _) {}); // keep it alive like the app does
    return container;
  }

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    backend = FakeBackend();
    files = MemoryFiles();
    tokens = MemoryTokenStore();
    c = app();
    await c.read(authProvider.notifier).ready;
  });

  test('first Google sign-in creates the account; the next one continues it', () async {
    expect(await c.read(authProvider.notifier).signInWithGoogle(), isTrue);
    expect(c.read(familyProvider).online, isTrue);
    expect(c.read(familyProvider).account!.email, 'ammi@gmail.com');
    await c.read(familyProvider.notifier).logOut();
    expect(c.read(familyProvider).guest, isTrue);
    expect(await c.read(authProvider.notifier).signInWithGoogle(), isFalse);
  });

  test('the test user signs in like a Google account and keeps its data after logging out', () async {
    expect(await c.read(authProvider.notifier).signInAsTestUser(), isTrue, reason: 'first time: a new account');
    expect(backend.idTokens.single, 'dev:${TestUser.email}');
    expect(c.read(authProvider).signedIn, isTrue);
    expect(c.read(familyProvider).online, isTrue);
    await c.read(familyProvider.notifier).addChild(name: 'Tester', age: 6, color: LikhoColors.primary);
    await settle();
    final n = c.read(familyProvider.notifier);
    n.recordResult(1, 3, seconds: 40);
    await settle();

    await n.logOut();
    expect(c.read(authProvider).signedIn, isFalse);
    expect(tokens.token, isNull, reason: 'the session is gone from the phone');

    expect(await c.read(authProvider.notifier).signInAsTestUser(), isFalse, reason: 'the same account again');
    await settle();
    expect(backend.idTokens, ['dev:${TestUser.email}', 'dev:${TestUser.email}']);
    final family = c.read(familyProvider);
    expect(family.profiles.single.name, 'Tester');
    expect(c.read(progressProvider).levelStars[1], 3);
  });

  test('a finished level shows at once and the server keeps it (sent once)', () async {
    backend.addChild('Ayaan', levels: {'1': 3, '2': 2}, stars: 9);
    await c.read(authProvider.notifier).signInWithGoogle();
    final n = c.read(familyProvider.notifier);
    final o = n.recordResult(3, 2, seconds: 95);
    expect((o.gain, o.firstTime), (4, true));
    expect(c.read(progressProvider).stars, 13, reason: 'shown before the server answers');
    await settle();
    expect(backend.children.single['stars'], 13);
    expect(((backend.children.single['progress'] as Map)[appCourseId] as Map)['levelStars']['3'], 2);
    expect(backend.calls.where((x) => x.endsWith('/courses/$appCourseId/results')).length, 1);
    expect(files.files[FamilyNotifier.outboxFile], '[]', reason: 'nothing left to send');
  });

  test('offline: results wait on the phone and are sent later, once', () async {
    backend.addChild('Zara');
    await c.read(authProvider.notifier).signInWithGoogle();
    backend.offline = true;
    final n = c.read(familyProvider.notifier);
    n.recordResult(1, 3);
    n.recordResult(2, 1);
    await settle();
    expect(c.read(progressProvider).stars, 5 + 3);
    expect(files.files[FamilyNotifier.outboxFile], contains('"level":2'));

    backend.offline = false;
    await n.flush();
    expect(backend.children.single['stars'], 8);
    await n.flush(); // nothing twice
    expect(backend.calls.where((x) => x.endsWith('/results')).length, 2);
  });

  test('results still waiting survive an app restart', () async {
    backend.addChild('Zara');
    await c.read(authProvider.notifier).signInWithGoogle();
    backend.offline = true;
    c.read(familyProvider.notifier).recordResult(1, 2);
    await settle();

    // "restart": same phone files and saved session, server still has 0 stars
    expect(backend.children.single['stars'], 0);
    backend.offline = false;
    final again = app();
    await again.read(authProvider.notifier).ready;
    expect(again.read(authProvider).signedIn, isTrue);
    await settle();
    expect(backend.children.single['stars'], 4);
    expect(again.read(progressProvider).stars, 4);
  });

  test('a level the server refuses is undone from the server\'s data', () async {
    backend.addChild('Zara');
    await c.read(authProvider.notifier).signInWithGoogle();
    c.read(familyProvider.notifier).recordResult(5, 3); // locked on the server
    await settle();
    expect(c.read(familyProvider).record.levelStars, isEmpty);
    expect(c.read(progressProvider).stars, 0);
  });

  test('room: a purchase the server refuses is undone with a message', () async {
    backend.addChild('Zara', stars: 20);
    await c.read(authProvider.notifier).signInWithGoogle();
    final n = c.read(familyProvider.notifier);
    expect(n.tapItem(ShopItem.byId('party')!), isTrue);
    expect(c.read(familyProvider).record.stars, 12);
    await settle();
    expect(backend.children.single['stars'], 12);

    backend.children.single['stars'] = 0; // spent on another phone
    expect(n.tapItem(ShopItem.byId('plant')!), isTrue);
    expect(c.read(familyProvider).record.room, contains('plant'), reason: 'shown at once');
    await settle();
    expect(c.read(familyProvider).record.room, isNot(contains('plant')));
    expect(c.read(familyProvider).record.stars, 0, reason: 'the server\'s count');
    expect(c.read(syncMessageProvider)?.text, isNotNull);
  });

  test('children and settings are saved on the server', () async {
    await c.read(authProvider.notifier).signInWithGoogle();
    final n = c.read(familyProvider.notifier);
    await n.addChild(name: ' Sara ', age: 7, color: LikhoColors.primary);
    expect(backend.children.single['name'], 'Sara');
    expect(c.read(familyProvider).active.id, backend.children.single['id']);
    n.updateSettings((s) => s.copyWith(sessionMinutes: 5, music: false));
    await settle();
    expect((backend.settings['sessionMinutes'], backend.settings['music']), (5, false));
    await n.subscribe();
    expect(c.read(familyProvider).subscribed, isTrue);
  });

  test('the course comes from the API and is kept for next time', () async {
    final files2 = MemoryFiles();
    final a = ProviderContainer(overrides: fakeBackendOverrides(backend, files: files2, realCourse: true));
    addTearDown(a.dispose);
    final course = await a.read(courseProvider.future);
    expect(course.levels.length, testCourse.levels.length);
    expect(files2.files['course.$appCourseId.etag'], '"v1"');

    backend.offline = true; // next launch without internet: the saved copy
    final b = ProviderContainer(overrides: fakeBackendOverrides(backend, files: files2, realCourse: true));
    addTearDown(b.dispose);
    expect((await b.read(courseProvider.future)).levels.length, testCourse.levels.length);
  });
}
