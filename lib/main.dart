import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/tokens.dart';
import 'dev/dev_launch.dart';
import 'screens/app_flow.dart';
import 'screens/likho_route.dart';
import 'screens/splash_screen.dart';
import 'screens/world_map/world_map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final devLevel = await devLaunchLevel(); // debug-only QA shortcut, null in release
  runApp(ProviderScope(child: LikhoApp(devLevel: devLevel)));
}

class LikhoApp extends StatelessWidget {
  const LikhoApp({super.key, this.devLevel});

  final int? devLevel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Likho',
      debugShowCheckedModeBanner: false,
      theme: likhoTheme(),
      home: Builder(
        builder: (context) => devLevel != null ? DevLevelLauncher(level: devLevel!) : SplashScreen(
          // The prototype shows "Welcome" (sign-up flow) next; that is not in this
          // build's screen list, so Splash goes straight to the World Map.
          onDone: () => Navigator.of(context).pushReplacement(LikhoRoute<void>(
            rise: false,
            builder: (ctx) => WorldMapScreen(onOpenLevel: (n) => AppFlow.openLevel(ctx, n)),
          )),
        ),
      ),
    );
  }
}
