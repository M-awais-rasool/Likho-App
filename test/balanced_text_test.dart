import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/screens/gameplay/widgets/game_bits.dart';

// The test font draws every glyph (and space) as a square of fontSize.
const _style = TextStyle(fontFamily: 'FlutterTest', fontSize: 10, height: 1);

Future<RenderBalancedText> _lay(WidgetTester tester, String text, double width) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: BalancedText(text, style: _style)),
      ),
    ),
  );
  return tester.renderObject<RenderBalancedText>(find.byType(BalancedText));
}

void main() {
  testWidgets('fills the box and keeps a short text on one line', (tester) async {
    final r = await _lay(tester, 'aa bb', 200);
    expect(r.size, const Size(200, 10));
    expect(r.debugLineWidths, [50]);
  });

  testWidgets('balances lines like text-wrap: balance', (tester) async {
    // at 100 px: "aa bb cc" / "dd"; balanced: "aa bb" / "cc dd"
    final r = await _lay(tester, 'aa bb cc dd', 100);
    expect(r.debugLineWidths, [50, 50]);
    expect(r.size.height, 20);
  });

  testWidgets('never breaks a word that is wider than the box', (tester) async {
    final r = await _lay(tester, 'abcdefghij', 50);
    expect(r.size.width, 50); // the box keeps its width, the word overflows
    expect(r.debugLineWidths, [100]);
    expect(tester.takeException(), isNull);
  });
}
