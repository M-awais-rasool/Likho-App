import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/tokens.dart';
import 'dev/dev_launch.dart';
import 'screens/app_flow.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // debug-only QA shortcuts, null in release
  final devLevel = await devLaunchLevel();
  final devScreen = devLevel == null ? await devLaunchScreen() : null;
  runApp(ProviderScope(child: LikhoApp(devLevel: devLevel, devScreen: devScreen)));
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
      navigatorObservers: [AppFlow.observer],
      home: Builder(
        builder: (context) => devLevel != null
            ? DevLevelLauncher(level: devLevel!)
            : devScreen != null
                ? DevScreenLauncher(screen: devScreen!)
                // Splash -> Welcome (sign up / login / try first), as in the prototype
                : SplashScreen(onDone: () => Navigator.of(context).pushReplacement(AppFlow.welcomeRoutePage())),
      ),
    );
  }
}
