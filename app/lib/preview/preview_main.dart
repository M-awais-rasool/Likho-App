// Level preview for the admin panel (web only). Build it with
// `admin/scripts/build-preview.sh`; the admin page loads it in a phone
// frame (an iframe) and posts the level to show:
//
//   {"type": "likho-preview", "nonce": 3, "screen": "level" | "map",
//    "level": 37, "course": {…the course document, draft level included…}}
//
// The App controls page also sends "controls" (what GET /v1/config would
// answer, from its unsaved changes) and "plus" (the sample family has
// Likho Plus; default true), and asks for more screens: stories, room,
// profile, dashboard, settings, paywall, welcome, update, maintenance.
//
// as a JSON string. It answers {"type": "likho-preview-ready"} once it can
// take one, and {"type": "likho-preview-error", "message": "…"} when the
// course does not parse. Only messages from its own origin are read.
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../data/course_providers.dart';
import '../data/api/likho_api.dart';
import '../data/family.dart';
import '../data/media.dart';
import '../data/models/course_models.dart';
import '../data/repositories/course_repository.dart';
import '../design/tokens.dart';
import '../feedback/app_feedback.dart';
import '../feedback/game_feedback.dart';
import '../feedback/pencil_lines.dart';
import '../feedback/sound_engine.dart';
import '../screens/app_flow.dart';
import '../screens/gameplay/gameplay_screen.dart';
import '../screens/level_complete/level_complete_screen.dart';
import '../screens/level_intro/level_intro_screen.dart';
import '../screens/stories/episode_a_screen.dart';
import '../data/app_controls.dart';
import '../screens/common/team_screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PreviewApp(sound: JustAudioSoundEngine()));
}

/// What the admin page asked to show.
class PreviewRequest {
  const PreviewRequest({required this.nonce, required this.screen, required this.level, required this.course, this.controls, this.plus = true});
  final int nonce;
  final String screen; // level | map | …
  final int level;
  final Course course;

  /// The App controls to show the app with (null: the app's defaults).
  final AppControls? controls;
  final bool plus;
}

class PreviewApp extends StatefulWidget {
  const PreviewApp({super.key, required this.sound});
  final SoundEngine sound;

  @override
  State<PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<PreviewApp> {
  PreviewRequest? _request;
  String? _error;
  late final JSFunction _listener = _onMessage.toJS;

  @override
  void initState() {
    super.initState();
    web.window.addEventListener('message', _listener);
    _post({'type': 'likho-preview-ready'});
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _listener);
    super.dispose();
  }

  void _post(Map<String, Object?> msg) => web.window.parent?.postMessage(jsonEncode(msg).toJS, web.window.location.origin.toJS);

  void _onMessage(web.MessageEvent e) {
    if (e.origin != web.window.location.origin) return;
    final data = e.data;
    if (!data.isA<JSString>()) return;
    try {
      final msg = jsonDecode((data as JSString).toDart);
      if (msg is! Map<String, dynamic> || msg['type'] != 'likho-preview') return;
      final course = Course.fromJson(msg['course'] as Map<String, dynamic>);
      final level = (msg['level'] as num).toInt();
      if (!course.levels.any((l) => l.number == level)) throw FormatException('Level $level is not in the course');
      setState(() {
        _error = null;
        _request = PreviewRequest(
          nonce: (msg['nonce'] as num?)?.toInt() ?? 0,
          screen: msg['screen'] as String? ?? 'level',
          level: level,
          course: course,
          controls: msg['controls'] is Map ? AppControls.fromJson((msg['controls'] as Map).cast<String, dynamic>()) : null,
          plus: msg['plus'] != false,
        );
      });
    } catch (err) {
      setState(() => _error = '$err');
      _post({'type': 'likho-preview-error', 'message': '$err'});
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _request;
    if (r == null || _error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: likhoTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error ?? 'Waiting for a level…',
                textAlign: TextAlign.center,
                style: const TextStyle(color: LikhoColors.ink),
              ),
            ),
          ),
        ),
      );
    }
    // a fresh app per request: nothing carries over from the last preview
    // (the media manifest does: it is the same for every preview)
    return ProviderScope(
      key: ValueKey(r.nonce),
      overrides: [
        courseRepositoryProvider.overrideWithValue(_FixedCourse(r.course)),
        soundEngineProvider.overrideWithValue(widget.sound),
        familyProvider.overrideWith(() => DemoFamilyNotifier(_previewFamily(r.level, plus: r.plus))),
        if (r.controls case final c?) appControlsProvider.overrideWith(() => FixedControls(c)),
        // pictures and recordings from the API that serves the admin panel
        mediaProvider.overrideWithValue(_media),
        // Pencil's own lines (his coaching in the games), as in the app
        pencilVoiceProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        title: 'Likho preview',
        debugShowCheckedModeBanner: false,
        theme: likhoTheme(),
        home: switch (r.screen) {
          'map' => Builder(builder: AppFlow.mapScreen),
          'stories' => _StoryOpener(child: Builder(builder: AppFlow.mapScreen)),
          final s when s.startsWith('story-') => _StoryOpener(step: StepA.values.byName(s.substring(6)), child: Builder(builder: AppFlow.mapScreen)),
          'room' || 'profile' || 'dashboard' || 'settings' || 'paywall' || 'welcome' => _Jump(screen: r.screen, child: Builder(builder: AppFlow.mapScreen)),
          'update' => TeamScreen.update(onUpdate: () {}),
          'maintenance' => TeamScreen.maintenance(r.controls?.maintenance ?? const TeamNotice(), onRetry: () {}),
          _ => _LevelRun(level: r.course.level(r.level)),
        },
      ),
    );
  }
}

/// The sample child has finished every level before [level] (3 stars) and
/// has Likho Plus ([plus]), so the previewed level is open on the map.
FamilyState _previewFamily(int level, {bool plus = true}) {
  final demo = FamilyState.demo();
  final records = {...demo.records};
  records[demo.activeId] = demo.record.copyWith(levelStars: {for (var n = 1; n < level; n++) n: 3});
  return demo.copyWith(records: records, subscribed: plus);
}

class _FixedCourse implements CourseRepository {
  const _FixedCourse(this.course);
  final Course course;

  @override
  Future<Course> loadCourse() async => course;
}

/// Intro -> gameplay -> Level Complete, round and round (Next starts over).
class _LevelRun extends ConsumerStatefulWidget {
  const _LevelRun({required this.level});
  final CourseLevel level;

  @override
  ConsumerState<_LevelRun> createState() => _LevelRunState();
}

enum _Stage { intro, game, complete }

class _LevelRunState extends ConsumerState<_LevelRun> {
  _Stage _stage = _Stage.intro;
  int _run = 0;
  LevelOutcome? _outcome;

  void _go(_Stage s) => setState(() {
    _stage = s;
    _run++;
  });

  @override
  Widget build(BuildContext context) {
    final level = widget.level;
    final Widget screen = switch (_stage) {
      _Stage.intro => IntroFeedback(
        child: LevelIntroScreen(level: level, onDone: () => _go(_Stage.game)),
      ),
      _Stage.game => GameFeedback(
        level: level,
        child: GameplayScreen(
          level: level,
          onExit: () => _go(_Stage.intro),
          onFinished: (result) {
            _outcome = ref.read(familyProvider.notifier).recordResult(level.number, result.stars, seconds: 60);
            _go(_Stage.complete);
          },
        ),
      ),
      _Stage.complete => LevelCompleteScreen(level: level, outcome: _outcome!, onAgain: () => _go(_Stage.game), onNext: () => _go(_Stage.intro)),
    };
    return KeyedSubtree(key: ValueKey(_run), child: screen);
  }
}

/// The media of the API this preview is served from (same origin).
final _media = MediaStore(baseUrl: Uri.base.origin, files: const LocalFiles());

/// Opens [screen] over the map (AppFlowJump's QA shortcuts).
class _Jump extends StatefulWidget {
  const _Jump({required this.screen, required this.child});
  final String screen;
  final Widget child;

  @override
  State<_Jump> createState() => _JumpState();
}

class _JumpState extends State<_Jump> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppFlowJump.open(context, widget.screen);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Opens Stories over the map (the preview's "stories" screen), or story A
/// at one of its parts ("story-pick").
class _StoryOpener extends StatefulWidget {
  const _StoryOpener({required this.child, this.step});
  final Widget child;
  final StepA? step;

  @override
  State<_StoryOpener> createState() => _StoryOpenerState();
}

class _StoryOpenerState extends State<_StoryOpener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final step = widget.step;
      step == null ? AppFlow.openStories(context) : AppFlow.openStory(context, 'a', from: step);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
