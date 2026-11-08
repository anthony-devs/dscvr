import 'package:dscvr/screens/tour/page_tour.dart';
import 'package:dscvr/config/env.dart';
import 'package:dscvr/models/edition.dart';
import 'package:dscvr/models/profession.dart';
import 'package:dscvr/state/settings_controller.dart';
import 'package:dscvr/widgets/subject_picker.dart';
import 'package:dscvr/models/workspace.dart';
import 'package:dscvr/screens/tour/app_tour.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/screens/library/shelf_page.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/models/plan.dart';
import 'package:dscvr/screens/plans/plans_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Stream<List<DeviceSession>> _devices = context.services.sessions.watchDevices(context.services.session.user.id);
  late final Future<String> _thisDevice = context.services.sessions.deviceId();

  Future<void> _editSubjects(BuildContext context) async {
    final session = context.services.session;
    final picked = [...session.user.interests];
    final saved = await showAdaptiveSheet<bool>(
      context,
      maxWidth: 620,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(title: 'Subjects you follow', subtitle: 'They show first in Discover and drive your alerts.'),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (picked.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final p in picked) AppChip(label: p, selected: true, onTap: () => set(() => picked.remove(p)))],
                      ),
                      const SizedBox(height: 16),
                    ],
                    SubjectSearch(
                      selected: picked,
                      onToggle: (v) => set(() {
                        final i = picked.indexWhere((x) => x.toLowerCase() == v.toLowerCase());
                        i >= 0 ? picked.removeAt(i) : picked.add(v);
                      }),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: Row(
                children: [
                  const Spacer(),
                  AppButton.ghost(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  AppButton.primary(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await session.setInterests(picked);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final settings = s.settings;
    final c = context.colors;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, s.session]),
      builder: (context, _) {
        final user = s.session.user;
        return PageBody(
          maxWidth: 720,
          children: [
            const PageTitle('Settings'),
            const SizedBox(height: 28),
            _Section(
              title: 'Appearance',
              children: [
                _Row(
                  label: 'Theme',
                  child: Segmented<ThemeMode>(
                    options: const [
                      (ThemeMode.light, 'Light', Ic.sun),
                      (ThemeMode.dark, 'Dark', Ic.moon),
                      (ThemeMode.system, 'System', Ic.system),
                    ],
                    value: settings.themeMode,
                    onChanged: settings.setThemeMode,
                  ),
                ),
                _Row(
                  label: 'Reading size',
                  description: 'Text size in the reader and note editor.',
                  child: SizedBox(
                    width: 220,
                    child: Row(
                      children: [
                        Icon(Ic.textSize, size: 14, color: c.inkFaint),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppSlider(
                            value: settings.readerScale,
                            min: 0.85,
                            max: 1.4,
                            onChanged: settings.setReaderScale,
                            label: 'Reading size',
                            valueLabel: (v) => '${(v * 100).round()} percent',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Ic.textSize, size: 20, color: c.inkFaint),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Accessibility',
              children: [
                _Row(
                  label: 'Text size',
                  description: 'All text in the app, on top of your device setting.',
                  child: SizedBox(
                    width: 220,
                    child: Row(
                      children: [
                        Text('A', style: AppTheme.sans(fontSize: 12, color: c.inkMuted)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppSlider(
                            value: settings.textScale,
                            min: 0.9,
                            max: 1.6,
                            step: 0.1,
                            onChanged: (v) => settings.setTextScale((v * 10).round() / 10),
                            label: 'Text size',
                            valueLabel: (v) => '${(v * 100).round()} percent',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('A', style: AppTheme.sans(fontSize: 20, color: c.inkMuted)),
                      ],
                    ),
                  ),
                ),
                _Row(
                  label: 'Font',
                  description: settings.font.blurb,
                  child: SizedBox(
                    width: 230,
                    child: AppSelect<ReadingFont>(
                      options: [for (final f in ReadingFont.values) SelectOption(f, f.label, subtitle: f.blurb)],
                      value: settings.font,
                      onChanged: settings.setFont,
                    ),
                  ),
                ),
                _Row(
                  label: 'Line spacing',
                  description: 'More space between lines of paragraphs.',
                  child: SizedBox(
                    width: 220,
                    child: AppSlider(
                      value: settings.lineSpacing,
                      min: 1.0,
                      max: 1.5,
                      step: 0.1,
                      onChanged: (v) => settings.setLineSpacing((v * 10).round() / 10),
                      label: 'Line spacing',
                      valueLabel: (v) => '${(v * 100).round()} percent',
                    ),
                  ),
                ),
                _Row(
                  label: 'High contrast',
                  description: 'Darker text and stronger borders.',
                  child: AppSwitch(value: settings.highContrast, onChanged: settings.setHighContrast, label: 'High contrast'),
                ),
                _Row(
                  label: 'Reduce motion',
                  description: 'Turns off sliding and springing animations.',
                  child: AppSwitch(value: settings.reduceMotion, onChanged: settings.setReduceMotion, label: 'Reduce motion'),
                ),
                _Row(
                  label: 'Read-aloud speed',
                  description: 'For Listen in the reader and Pinda\'s spoken answers.',
                  child: SizedBox(
                    width: 220,
                    child: Row(
                      children: [
                        Text('Slow', style: AppTheme.sans(fontSize: 12, color: c.inkMuted)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppSlider(
                            value: settings.speechRate,
                            min: 0.5,
                            max: 2.0,
                            step: 0.25,
                            onChanged: (v) => settings.setSpeechRate((v * 4).round() / 4),
                            label: 'Read-aloud speed',
                            valueLabel: (v) => '${v.toStringAsFixed(2)} times',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('Fast', style: AppTheme.sans(fontSize: 12, color: c.inkMuted)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppButton.ghost(
                      size: BtnSize.sm,
                      onPressed: settings.resetAccessibility,
                      label: const Text('Reset to defaults'),
                    ),
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Your field and subjects',
              children: [
                _Row(
                  label: 'Field',
                  description: 'Sets your starting sources and study tools, and how Pinda talks about your subject.',
                  child: SizedBox(
                    width: 230,
                    child: AppSelect<Profession>(
                      placeholder: 'Choose your field',
                      options: [for (final p in Profession.values) SelectOption(p, p.label, subtitle: p.blurb)],
                      value: user.profession,
                      onChanged: (p) => s.session.setProfession(p),
                    ),
                  ),
                ),
                _Row(
                  label: 'Subjects you follow',
                  description: user.interests.isEmpty ? 'None yet.' : user.interests.join(', '),
                  child: AppButton.secondary(
                    onPressed: () => _editSubjects(context),
                    icon: const Icon(Ic.edit, size: 14),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Alerts',
              children: [
                _Row(
                  label: 'New in my subjects',
                  description: 'Once a day, DSCVR checks your subjects for new papers, guidelines and judgments.',
                  child: AppSwitch(
                    value: user.alertsOn,
                    label: 'Alerts for new items in my subjects',
                    onChanged: (v) async {
                      await s.session.setAlerts(enabled: v, email: user.alertsEmail);
                      if (v && context.mounted) {
                        try {
                          final r = await s.api.post('/alerts/check');
                          final n = (r['new'] as num?)?.toInt() ?? 0;
                          if (context.mounted) {
                            toast(
                              context,
                              n > 0 ? '$n new items in your inbox' : 'Alerts are on',
                              description: 'Find them under Alerts in the sidebar.',
                            );
                          }
                        } catch (_) {}
                      }
                    },
                  ),
                ),
                _Row(
                  label: 'Email me a digest',
                  description: 'A short email when there is something new. Off by default.',
                  child: AppSwitch(
                    value: user.alertsEmail,
                    label: 'Email digest',
                    onChanged: user.alertsOn ? (v) => s.session.setAlerts(enabled: true, email: v) : null,
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Data and offline',
              children: [
                _Row(
                  label: 'Low data mode',
                  description: 'Fewer results per page, no pictures, nothing loads until you ask. Good on slow or costly connections.',
                  child: AppSwitch(value: settings.lowData, onChanged: settings.setLowData, label: 'Low data mode'),
                ),
                const _Row(
                  label: 'Offline',
                  description:
                      'Your library, notes and Pinda conversations stay readable without a connection, and changes sync when you are back online. '
                      'PDFs you have opened once stay in your browser cache.',
                  child: SizedBox.shrink(),
                ),
              ],
            ),
            _Section(
              title: 'Help',
              children: [
                _Row(
                  label: 'App tour',
                  description: 'A one-minute walk through your library, Discover, Pinda, alerts and accessibility.',
                  child: AppButton.secondary(onPressed: () => showAppTour(context), child: const Text('Take the tour')),
                ),
                _Row(
                  label: 'Page tours',
                  description: 'Every page explains itself the first time you open it. Tap the ? at the top of a page to replay it, or show them all again.',
                  child: AppButton.secondary(
                    onPressed: () {
                      settings.resetTours();
                      toast(context, 'Page tours will show again');
                    },
                    child: const Text('Show again'),
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Pinda',
              children: [
                _Row(
                  label: 'Answer style',
                  description: 'Concise answers get to the point. Detailed answers explain and cite more.',
                  child: Segmented<String>(
                    options: const [('concise', 'Concise', null), ('detailed', 'Detailed', null)],
                    value: settings.pindaStyle,
                    onChanged: settings.setPindaStyle,
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Plan and usage',
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: ListenableBuilder(
                    listenable: s.plans,
                    builder: (context, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        UsageCard(info: s.plans.info, compact: context.isCompact),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppButton.secondary(
                            onPressed: () => context.go('/plans'),
                            icon: const Icon(Ic.crown, size: 15),
                            label: Text(s.plans.info.plan == Plan.free ? 'See plans' : 'Manage plan'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Edition',
              children: [
                if (user.inOrg)
                  _Row(
                    label: Edition.enterprise.label,
                    description: 'Your usage is billed to your organisation.',
                    child: AppButton.secondary(
                      onPressed: () => context.go('/team'),
                      icon: const Icon(Ic.team, size: 15),
                      label: const Text('Team'),
                    ),
                  )
                else ...[
                  _Row(
                    label: user.edition.label,
                    description: user.edition == Edition.enterprise
                        ? 'Create or join an organisation to finish setting up.'
                        : 'Free. Tailors your home screen, Pinda and reports.',
                    child: Segmented<Edition>(
                      options: const [(Edition.students, 'Students', Ic.students), (Edition.researchers, 'Researchers', Ic.researchers)],
                      value: user.edition == Edition.students ? Edition.students : Edition.researchers,
                      onChanged: (e) async {
                        await s.session.setEdition(e);
                        if (context.mounted) {
                          toast(context, 'Switched to ${e.label}');
                        }
                      },
                    ),
                  ),
                  _Row(
                    label: Edition.enterprise.label,
                    description: 'A shared organisation for your team, billed by usage.',
                    child: AppButton.secondary(
                      onPressed: () => context.go('/team'),
                      icon: const Icon(Ic.enterprise, size: 15),
                      label: const Text('Set up'),
                    ),
                  ),
                ],
              ],
            ),
            _Section(
              title: 'Signed-in devices',
              children: [
                StreamBuilder<List<DeviceSession>>(
                  stream: _devices,
                  builder: (context, snap) {
                    final list = snap.data ?? const <DeviceSession>[];
                    return FutureBuilder<String>(
                      future: _thisDevice,
                      builder: (context, me) => Column(
                        children: [
                          for (final (i, d) in list.indexed) ...[
                            if (i > 0) Divider(color: c.line, height: 1),
                            _Row(
                              label: d.id == me.data || (Env.demo && i == 0) ? '${d.label} (this device)' : d.label,
                              description: 'Signed in ${relativeTime(d.signedInAt)}  ·  active ${relativeTime(d.lastActiveAt)}',
                              child: d.id == me.data || (Env.demo && i == 0)
                                  ? Icon(d.platform == 'web' ? Ic.globe : Ic.devices, size: 18, color: c.inkMuted)
                                  : AppButton.ghost(
                                      onPressed: Env.demo ? null : () => s.sessions.revokeDevice(user.id, d.id),
                                      child: const Text('Sign out'),
                                    ),
                            ),
                          ],
                          if (list.length > 1 && !Env.demo) ...[
                            Divider(color: c.line, height: 1),
                            _Row(
                              label: 'Sign out everywhere else',
                              description: 'Every other device is signed out within seconds.',
                              child: AppButton.secondary(
                                onPressed: () async {
                                  final ok = await confirm(
                                    context,
                                    title: 'Sign out other devices?',
                                    message: 'You stay signed in here.',
                                    action: 'Sign out others',
                                  );
                                  if (!ok) return;
                                  await s.sessions.revokeOthers(user.id);
                                  if (context.mounted) {
                                    toast(context, 'Other devices signed out');
                                  }
                                },
                                child: const Text('Sign out others'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            _Section(
              title: 'Account',
              children: [
                _Row(
                  label: user.displayName,
                  description: user.email,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: c.chip,
                    child: Text(
                      user.initials,
                      style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink),
                    ),
                  ),
                ),
                if (!Env.demo) ...[
                  _Row(
                    label: 'Password',
                    description: 'We will email you a reset link.',
                    child: AppButton.secondary(
                      onPressed: () async {
                        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email);
                        if (context.mounted) {
                          toast(context, 'Reset link sent to ${user.email}');
                        }
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  _Row(
                    label: 'Sign out',
                    child: AppButton.secondary(
                      onPressed: () => s.session.signOut(),
                      icon: const Icon(Ic.signOut, size: 16),
                      label: const Text('Sign out'),
                    ),
                  ),
                  _Row(
                    label: 'Delete account',
                    description: 'Removes your profile. Library data is deleted with it.',
                    child: AppButton.ghost(
                      onPressed: () async {
                        final ok = await confirm(
                          context,
                          title: 'Delete your account?',
                          message: 'This permanently deletes your account. Firebase may ask you to sign in again first.',
                        );
                        if (!ok) return;
                        try {
                          await FirebaseAuth.instance.currentUser?.delete();
                        } on FirebaseAuthException catch (e) {
                          if (context.mounted) {
                            toast(
                              context,
                              e.code == 'requires-recent-login' ? 'Please sign out and in again, then retry.' : (e.message ?? 'Failed'),
                            );
                          }
                        }
                      },
                      child: Text('Delete', style: TextStyle(color: c.danger)),
                    ),
                  ),
                ],
              ],
            ),
            _Section(
              title: 'About',
              children: [
                _Row(
                  label: 'DSCVR',
                  description: Env.demo ? 'Demo mode: sample data, nothing is saved.' : 'Your research desk, everywhere.',
                  child: Text('1.1.0', style: context.text.labelMedium),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TourTarget(
      id: 'settings.${title.toLowerCase()}',
      child: Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.text.titleLarge),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: c.line),
            ),
            child: Column(
              children: [
                for (final (i, child) in children.indexed) ...[if (i > 0) Divider(color: c.line, height: 1), child],
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child, this.description});
  final String label;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.titleSmall),
        if (description != null) ...[const SizedBox(height: 3), Text(description!, style: context.text.bodySmall)],
      ],
    );
    // Switches sit beside their label even on phones; wider controls go below.
    final inline = child is AppSwitch || (child is SizedBox && (child as SizedBox).width == 0);
    final stack = context.isCompact && !inline;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: stack
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, const SizedBox(height: 10), child])
          : Row(
              children: [
                Expanded(child: left),
                const SizedBox(width: 16),
                child,
              ],
            ),
    );
  }
}
