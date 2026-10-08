import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/data/api/likho_api.dart';
import 'package:likho/game/level_resume.dart';
import 'package:likho/game/level_session.dart';
import 'package:fake_async/fake_async.dart';

import 'fake_backend.dart';
import 'test_course.dart';

void main() {
  test('pick level: wrong -> hint + mistake, right -> next round, last -> finished', () {
    fakeAsync((clock) {
      final level = onlyRounds(testCourse.level(5), (r) => r is PickRound); // the letter L's picks
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(levelSessionProvider(level), (_, _) {});
      final s = c.read(levelSessionProvider(level).notifier);
      PickRound r() => c.read(levelSessionProvider(level)).current as PickRound;
      int right() => r().options.indexWhere((o) => o.label == r().answer);
      int wrong() => r().options.indexWhere((o) => o.label != r().answer);

      s.pick(wrong());
      var st = c.read(levelSessionProvider(level));
      expect(st.feedback, RoundFeedback.wrong);
      expect(st.mistakes, 1);
      expect(st.hint, isTrue);
      clock.elapse(GameTiming.afterWrong);
      expect(c.read(levelSessionProvider(level)).feedback, RoundFeedback.none);

      for (var i = 0; i < level.rounds.length; i++) {
        expect(c.read(levelSessionProvider(level)).round, i);
        s.pick(right());
        expect(c.read(levelSessionProvider(level)).correct, isTrue);
        s.pick(wrong()); // ignored while celebrating
        clock.elapse(GameTiming.afterCorrect);
      }
      st = c.read(levelSessionProvider(level));
      expect(st.finished, isTrue);
      expect(st.stars, starsFor(1, rounds: level.rounds.length)); // one mistake
      sub.close();
    });
  });

  test('order level: tiles must go in order', () {
    fakeAsync((clock) {
      final level = onlyRounds(testCourse.level(5), (r) => r is OrderRound); // ABC order
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(levelSessionProvider(level), (_, _) {});
      final s = c.read(levelSessionProvider(level).notifier);
      final order = c.read(levelSessionProvider(level)).tiles;
      final wrongFirst = order.indexWhere((t) => t != 0);
      s.placeTile(wrongFirst);
      expect(c.read(levelSessionProvider(level)).mistakes, 1);
      clock.elapse(GameTiming.afterWrong);
      for (var k = 0; k < order.length; k++) {
        s.placeTile(order.indexOf(k));
      }
      clock.elapse(GameTiming.orderSettle);
      expect(c.read(levelSessionProvider(level)).correct, isTrue);
      sub.close();
    });
  });

  test('spell: each accepted drawing fills one letter', () {
    fakeAsync((clock) {
      final level = onlyRounds(levelWith((r) => r is WriteRound && r.mode == WriteMode.spell), (r) => r is WriteRound && r.mode == WriteMode.spell);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(levelSessionProvider(level), (_, _) {});
      final s = c.read(levelSessionProvider(level).notifier);
      final word = (c.read(levelSessionProvider(level)).current as WriteRound).word!;
      for (var i = 0; i < word.length - 1; i++) {
        s.submitWriting(WritingVerdict.accepted);
        expect(c.read(levelSessionProvider(level)).spellFilled, i + 1);
        expect(c.read(levelSessionProvider(level)).correct, isFalse);
      }
      s.submitWriting(WritingVerdict.accepted);
      expect(c.read(levelSessionProvider(level)).correct, isTrue);
      sub.close();
    });
  });

  test('story choices are remembered across rounds', () {
    fakeAsync((clock) {
      final level = levelWith((r) => r is PickRound && r.choiceKey != null); // My Story
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(levelSessionProvider(level), (_, _) {});
      final s = c.read(levelSessionProvider(level).notifier);
      s.pick(1); // any option is right
      clock.elapse(GameTiming.afterCorrect);
      expect(c.read(levelSessionProvider(level)).choices, {'who': 'robot'});
      expect(c.read(levelSessionProvider(level)).mistakes, 0);
      sub.close();
    });
  });

  test('hunt: every matching letter must be found, a wrong one is a mistake', () {
    fakeAsync((clock) {
      final level = onlyRounds(levelWith((r) => r is HuntRound), (r) => r is HuntRound);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(levelSessionProvider(level), (_, _) {});
      final s = c.read(levelSessionProvider(level).notifier);
      final r = level.rounds.first as HuntRound;
      final targets = [for (var i = 0; i < r.grid.length; i++) if (r.grid[i] == r.target) i];
      s.tapCell(r.grid.indexWhere((x) => x != r.target));
      expect(c.read(levelSessionProvider(level)).mistakes, 1);
      clock.elapse(GameTiming.afterWrong);
      for (final (k, i) in targets.indexed) {
        s.tapCell(i);
        s.tapCell(i); // the same letter twice counts once
        expect(c.read(levelSessionProvider(level)).found.length, k + 1);
        expect(c.read(levelSessionProvider(level)).correct, k == targets.length - 1);
      }
      sub.close();
    });
  });

  test('resume: a level goes on from a saved round, with its mistakes', () {
    fakeAsync((clock) {
      final level = testCourse.level(5);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final sub = c.listen(levelSessionProvider(level), (_, _) {});
      final s = c.read(levelSessionProvider(level).notifier);
      s.resumeAt(level.rounds.length); // past the end: ignored
      expect(c.read(levelSessionProvider(level)).round, 0);
      s.resumeAt(7, mistakes: 2);
      final st = c.read(levelSessionProvider(level));
      expect((st.round, st.mistakes), (7, 2));
      s.resumeAt(3); // only before the first answer
      expect(c.read(levelSessionProvider(level)).round, 7);
      sub.close();
    });
  });

  test('halfway: long levels cheer at the first round of their second half', () {
    final long = testCourse.level(5);
    expect(SessionState(level: long, round: long.rounds.length ~/ 2).isHalfway, isTrue);
    expect(SessionState(level: long, round: 1).isHalfway, isFalse);
    final short = onlyRounds(long, (r) => r is PickRound);
    expect([for (var i = 0; i < short.rounds.length; i++) SessionState(level: short, round: i).isHalfway], everyElement(isFalse));
  });

  test('resume points are kept on the phone, per child, and dropped when the level changes', () async {
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    final files = MemoryFiles();
    ProviderContainer open() {
      final c = ProviderContainer(overrides: [localFilesProvider.overrideWithValue(files)]);
      addTearDown(c.dispose);
      c.read(levelResumeProvider);
      return c;
    }

    final level = testCourse.level(5);
    final a = open();
    await settle();
    a.read(levelResumeProvider.notifier).save('kid', level, round: 6, mistakes: 1, choices: {'who': 'cat'});
    await settle();
    expect(files.files[LevelResume.file], contains('"round":6'));

    final b = open(); // the app opened again
    await settle();
    final store = b.read(levelResumeProvider.notifier);
    final p = store.pointFor('kid', level);
    expect((p?.round, p?.mistakes), (6, 1));
    expect(p?.choices, {'who': 'cat'});
    expect(store.pointFor('other-kid', level), isNull);
    expect(store.pointFor('kid', onlyRounds(level, (r) => r is PickRound)), isNull, reason: 'the level has other rounds now');
    store.clear('kid', level);
    expect(store.pointFor('kid', level), isNull);
  });
}
