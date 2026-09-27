import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/models/course_models.dart';
import 'package:likho/game/level_session.dart';
import 'package:fake_async/fake_async.dart';

import 'test_course.dart';

void main() {
  test('pick level: wrong -> hint + mistake, right -> next round, last -> finished', () {
    fakeAsync((clock) {
      final level = testCourse.level(1); // Balloon Pop: 5 pick rounds
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
      expect(st.stars, 2); // one mistake
      sub.close();
    });
  });

  test('order level: tiles must go in order', () {
    fakeAsync((clock) {
      final level = testCourse.level(2); // Alphabet Train
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
      final level = testCourse.level(18); // Wake the Bear: spell dog, sun, ...
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
      final level = testCourse.level(35); // My Story
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
}
