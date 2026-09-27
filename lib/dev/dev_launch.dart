import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/course_providers.dart';
import '../screens/app_flow.dart';

/// Debug-only deep link for QA: opens level N directly instead of Splash.
/// Set it with the environment variable LIKHO_LEVEL=N, or by writing N into
/// the app's Documents/likho_dev_level file (the iOS simulator does not
/// always pass environment variables):
///   echo 8 > "$(xcrun simctl get_app_container booted com.likho.likho data)/Documents/likho_dev_level"
/// Always null in release builds.
Future<int?> devLaunchLevel() async {
  if (!kDebugMode) return null;
  try {
    final env = int.tryParse(Platform.environment['LIKHO_LEVEL'] ?? '');
    if (env != null) return env;
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/likho_dev_level');
    if (!f.existsSync()) return null;
    return int.tryParse(f.readAsStringSync().trim());
  } catch (_) {
    return null;
  }
}

/// Debug-only deep link to any screen (see [AppFlowJump.screens]), e.g.
///   echo room > "$(xcrun simctl get_app_container booted com.likho.likho data)/Documents/likho_dev_screen"
/// or LIKHO_SCREEN=room. Always null in release builds.
Future<String?> devLaunchScreen() async {
  if (!kDebugMode) return null;
  try {
    final env = Platform.environment['LIKHO_SCREEN'];
    if (env != null && env.isNotEmpty) return env;
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/likho_dev_screen');
    if (!f.existsSync()) return null;
    final s = f.readAsStringSync().trim();
    return s.isEmpty ? null : s;
  } catch (_) {
    return null;
  }
}

/// Opens [level] on top of the World Map as soon as the course is loaded.
class DevLevelLauncher extends ConsumerStatefulWidget {
  const DevLevelLauncher({super.key, required this.level});
  final int level;

  @override
  ConsumerState<DevLevelLauncher> createState() => _DevLevelLauncherState();
}

class _DevLevelLauncherState extends ConsumerState<DevLevelLauncher> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(courseProvider).value != null;
    if (loaded && !_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AppFlow.openLevel(context, widget.level, skipIntro: true);
      });
    }
    return AppFlow.mapScreen(context);
  }
}

/// Opens [screen] on top of the World Map as soon as the course is loaded.
class DevScreenLauncher extends ConsumerStatefulWidget {
  const DevScreenLauncher({super.key, required this.screen});
  final String screen;

  @override
  ConsumerState<DevScreenLauncher> createState() => _DevScreenLauncherState();
}

class _DevScreenLauncherState extends ConsumerState<DevScreenLauncher> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(courseProvider).value != null;
    if (loaded && !_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.screen != 'map') AppFlowJump.open(context, widget.screen);
      });
    }
    return AppFlow.mapScreen(context);
  }
}
