import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/family.dart';
import 'design/tokens.dart';
import 'dev/dev_launch.dart';
import 'feedback/app_feedback.dart';
import 'feedback/haptics.dart';
import 'feedback/sfx.dart';
import 'feedback/sound_engine.dart';
import 'screens/app_flow.dart';
import 'screens/app_shell.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_artLicenses);
  // debug-only QA shortcuts, null in release
  final devLevel = await devLaunchLevel();
  final devScreen = devLevel == null ? await devLaunchScreen() : null;
  // sound effects + haptics (tests keep the silent defaults); the splash
  // and answer sounds load now so their first play is instant
  final sound = JustAudioSoundEngine();
  unawaited(sound.preload(Sfx.warm));
  runApp(ProviderScope(
    overrides: [
      soundEngineProvider.overrideWithValue(sound),
      hapticsProvider.overrideWithValue(const SystemHaptics()),
      // QA shortcuts show the sample family and never touch the account
      if (devLevel != null || devScreen != null) familyProvider.overrideWith(DemoFamilyNotifier.new),
    ],
    child: LikhoApp(devLevel: devLevel, devScreen: devScreen),
  ));
}

/// Licences of art bundled with the app, for Flutter's licence page: the
/// course illustrations are Microsoft's Fluent Emoji (MIT).
Stream<LicenseEntry> _artLicenses() async* {
  yield LicenseEntryWithLineBreaks(['Fluent Emoji (course pictures)'], await rootBundle.loadString('assets/licenses/fluent-emoji.txt'));
}

class LikhoApp extends StatelessWidget {
  const LikhoApp({super.key, this.devLevel, this.devScreen});

  final int? devLevel;
  final String? devScreen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Likho',
      debugShowCheckedModeBanner: false,
      theme: likhoTheme(),
      navigatorKey: AppFlow.navigatorKey,
      navigatorObservers: [AppFlow.observer],
      builder: (context, child) => AppShell(navigatorKey: AppFlow.navigatorKey, child: child!),
      home: Builder(
        builder: (context) => devLevel != null
            ? DevLevelLauncher(level: devLevel!)
            : devScreen != null
                ? DevScreenLauncher(screen: devScreen!)
                // Splash -> Who's playing when signed in, otherwise Welcome
                : SplashScreen(onDone: () => AppFlow.afterSplash(context)),
      ),
    );
  }
}
