import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/family.dart';
import '../../design/tokens.dart';
import '../auth/google_button.dart';
import '../common/kid_widgets.dart';
import 'parent_widgets.dart';

/// 21 Settings, from the prototype: account, children, play options,
/// subscription and help.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({
    super.key,
    required this.onBack,
    required this.onLogOut,
    required this.onManageChildren,
    required this.onPlan,
    required this.onHelp,
    required this.onDeleteAccount,
  });

  final VoidCallback onBack, onLogOut, onManageChildren, onPlan, onHelp, onDeleteAccount;

  /// Shown when nobody is signed in (sample data in tests / dev tools).
  static const demoEmail = 'parent@likho.app';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyProvider);
    final email = family.account?.email ?? demoEmail;
    final s = family.settings;
    void set(AppSettings Function(AppSettings) f) => ref.read(familyProvider.notifier).updateSettings(f);
    const chevron = SymbolIcon(Symbols.chevron_right_rounded, size: 24, color: UiColors.chevron);
    Widget card(List<Widget> rows) => ParentCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      radius: 18,
      soft: false,
      child: Column(children: rows),
    );
    return ParentPage(
      gap: 8,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ParentHeader(icon: Symbols.arrow_back_rounded, onTap: onBack, title: 'Settings'),
        ),
        const SectionLabel('Account'),
        card([
          SettingsRow(
            label: 'Email',
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                email,
                overflow: TextOverflow.ellipsis,
                style: LikhoFonts.parent(size: 15, weight: FontWeight.w600, color: UiColors.inkLabel),
              ),
            ),
          ),
          SettingsRow(
            label: 'Sign in',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GoogleDot(size: 18),
                const SizedBox(width: 8),
                Text('Google', style: LikhoFonts.parent(size: 15, weight: FontWeight.w600, color: UiColors.inkLabel)),
              ],
            ),
          ),
          SettingsRow(
            label: 'Logout',
            trailing: const SymbolIcon(Symbols.logout_rounded, size: 24, color: UiColors.chevron),
            onTap: onLogOut,
          ),
          SettingsRow(label: 'Delete account', labelColor: UiColors.danger, trailing: chevron, onTap: onDeleteAccount, last: true),
        ]),
        const SectionLabel('Children'),
        card([SettingsRow(label: 'Manage profiles', trailing: chevron, onTap: onManageChildren, last: true)]),
        const SectionLabel('Play'),
        card([
          SettingsRow(
            label: 'Session',
            height: null,
            trailing: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: 200,
                child: SegmentedMinutes(
                  compact: true,
                  value: s.sessionMinutes,
                  options: AppSettings.sessionOptions,
                  onChanged: (m) => set((x) => x.copyWith(sessionMinutes: m)),
                ),
              ),
            ),
          ),
          SettingsRow(
            label: 'Music',
            trailing: ParentSwitch(
              value: s.music,
              onChanged: (v) => set((x) => x.copyWith(music: v)),
            ),
          ),
          SettingsRow(
            label: 'Sound effects & voice',
            trailing: ParentSwitch(
              value: s.sfx,
              onChanged: (v) => set((x) => x.copyWith(sfx: v)),
            ),
          ),
          SettingsRow(
            label: 'Vibration',
            trailing: ParentSwitch(
              value: s.haptics,
              onChanged: (v) => set((x) => x.copyWith(haptics: v)),
            ),
          ),
          SettingsRow(
            label: 'Left-handed mode',
            trailing: ParentSwitch(
              value: s.leftHanded,
              onChanged: (v) => set((x) => x.copyWith(leftHanded: v)),
            ),
          ),
          SettingsRow(
            label: 'Reduce motion',
            last: true,
            trailing: ParentSwitch(
              value: s.reduceMotion,
              onChanged: (v) => set((x) => x.copyWith(reduceMotion: v)),
            ),
          ),
        ]),
        const SectionLabel('Subscription'),
        card([
          SettingsRow(
            label: 'Plan',
            onTap: onPlan,
            last: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  family.subscribed ? 'Likho Plus · trial' : 'Free plan',
                  style: LikhoFonts.parent(size: 15, weight: FontWeight.w600, color: UiColors.inkLabel),
                ),
                const SizedBox(width: 4),
                chevron,
              ],
            ),
          ),
        ]),
        const SectionLabel('Help'),
        card([
          SettingsRow(label: 'FAQ', trailing: chevron, onTap: onHelp),
          SettingsRow(label: 'Contact us', trailing: chevron, onTap: onHelp),
          SettingsRow(label: 'Privacy policy', trailing: chevron, onTap: onHelp, last: true),
        ]),
      ],
    );
  }
}
