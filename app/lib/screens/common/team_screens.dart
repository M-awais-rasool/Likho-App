import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/app_controls.dart';
import '../../design/tokens.dart';
import '../../mascot/mascot.dart';
import 'kid_widgets.dart';
import 'pencil_figure.dart';

/// Screens the team puts over the whole app (App controls): "please
/// update" for an app older than they allow, and the maintenance screen.
/// Both look like the offline screen: Pencil, a title, a line, one button.
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key, required this.state, required this.title, required this.text, required this.button, required this.icon, required this.onTap, this.busy = false});

  final MascotState state;
  final String title, text, button;
  final IconData icon;
  final VoidCallback onTap;
  final bool busy;

  /// An app older than [AppControls.minVersion].
  factory TeamScreen.update({required VoidCallback onUpdate}) => TeamScreen(
    key: const ValueKey('team-update'),
    state: MascotState.wow,
    title: 'Time for an update!',
    text: 'A new Likho is ready with fresh fun inside. Ask a grown-up to update the app.',
    button: 'Update Likho',
    icon: Symbols.system_update_rounded,
    onTap: onUpdate,
  );

  /// The maintenance screen with the team's words.
  factory TeamScreen.maintenance(TeamNotice n, {required VoidCallback onRetry, bool busy = false}) => TeamScreen(
    key: const ValueKey('team-maintenance'),
    state: MascotState.sleepy,
    title: n.title.isEmpty ? "We'll be right back" : n.title,
    text: n.text,
    button: 'Try again',
    icon: Symbols.refresh_rounded,
    onTap: onRetry,
    busy: busy,
  );

  @override
  Widget build(BuildContext context) => StatusBar(
    child: Material(
      color: LikhoColors.background,
      child: MaxWidth(
        width: 440,
        child: ScrollFill(
          padding: EdgeInsets.fromLTRB(24, frameTop(context, 96), 24, 44),
          child: Column(
            children: [
              PencilFigure(width: 150, height: 210, state: state, holdEnd: true),
              const SizedBox(height: 22),
              Text(title, textAlign: TextAlign.center, style: LikhoFonts.title(size: 32, weight: FontWeight.w800).copyWith(height: 1.12)),
              const SizedBox(height: 10),
              Text(text, textAlign: TextAlign.center, style: LikhoFonts.body(size: 17, color: UiColors.inkBody, height: 1.45)),
              const Spacer(),
              BigButton(
                label: button,
                icon: busy ? null : icon,
                leading: busy ? const ButtonSpinner() : null,
                height: 76,
                onTap: busy ? null : onTap,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
