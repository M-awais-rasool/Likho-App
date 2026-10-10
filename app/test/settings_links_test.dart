import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likho/data/family.dart';
import 'package:likho/data/links.dart';
import 'package:likho/design/tokens.dart';
import 'package:likho/screens/parent/settings_screen.dart';

/// Play needs the privacy policy inside the app: the Settings row opens
/// likho.io/privacy (the Help rows still say "coming soon").
void main() {
  testWidgets('the Privacy policy row opens the privacy page, not Help', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var privacy = 0, help = 0;
    await t.pumpWidget(
      ProviderScope(
        overrides: [familyProvider.overrideWith(DemoFamilyNotifier.new)],
        child: MaterialApp(
          theme: likhoTheme(),
          home: SettingsScreen(
            onBack: () {},
            onLogOut: () {},
            onManageChildren: () {},
            onPlan: () {},
            onHelp: () => help++,
            onPrivacy: () => privacy++,
            onDeleteAccount: () {},
          ),
        ),
      ),
    );
    await t.pump();
    final row = find.text('Privacy policy');
    await t.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
    await t.tap(row);
    await t.pump();
    expect((privacy, help), (1, 0));
    expect(LikhoLinks.privacy.toString(), 'https://likho.io/privacy/');
  });
}
