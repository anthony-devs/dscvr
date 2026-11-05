import 'package:dscvr/config/env.dart';
import 'package:dscvr/models/edition.dart';
import 'package:dscvr/models/workspace.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/screens/library/shelf_page.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Stream<List<DeviceSession>> _devices = context.services.sessions
      .watchDevices(context.services.session.user.id);
  late final Future<String> _thisDevice = context.services.sessions.deviceId();

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final settings = s.settings;
    final user = s.session.user;
    final c = context.colors;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => PageBody(
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
            title: 'Pinda',
            children: [
              _Row(
                label: 'Answer style',
                description:
                    'Concise answers get to the point. Detailed answers explain and cite more.',
                child: Segmented<String>(
                  options: const [
                    ('concise', 'Concise', null),
                    ('detailed', 'Detailed', null),
                  ],
                  value: settings.pindaStyle,
                  onChanged: settings.setPindaStyle,
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
                    options: const [
                      (Edition.students, 'Students', Ic.students),
                      (Edition.researchers, 'Researchers', Ic.researchers),
                    ],
                    value: user.edition == Edition.students
                        ? Edition.students
                        : Edition.researchers,
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
                  description:
                      'A shared organisation for your team, billed by usage.',
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
                            label: d.id == me.data || (Env.demo && i == 0)
                                ? '${d.label} (this device)'
                                : d.label,
                            description:
                                'Signed in ${relativeTime(d.signedInAt)}  ·  active ${relativeTime(d.lastActiveAt)}',
                            child: d.id == me.data || (Env.demo && i == 0)
                                ? Icon(
                                    d.platform == 'web' ? Ic.globe : Ic.devices,
                                    size: 18,
                                    color: c.inkMuted,
                                  )
                                : AppButton.ghost(
                                    onPressed: Env.demo
                                        ? null
                                        : () => s.sessions.revokeDevice(
                                            user.id,
                                            d.id,
                                          ),
                                    child: const Text('Sign out'),
                                  ),
                          ),
                        ],
                        if (list.length > 1 && !Env.demo) ...[
                          Divider(color: c.line, height: 1),
                          _Row(
                            label: 'Sign out everywhere else',
                            description:
                                'Every other device is signed out within seconds.',
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
                    style: AppTheme.sans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                ),
              ),
              if (!Env.demo) ...[
                _Row(
                  label: 'Password',
                  description: 'We will email you a reset link.',
                  child: AppButton.secondary(
                    onPressed: () async {
                      await FirebaseAuth.instance.sendPasswordResetEmail(
                        email: user.email,
                      );
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
                  description:
                      'Removes your profile. Library data is deleted with it.',
                  child: AppButton.ghost(
                    onPressed: () async {
                      final ok = await confirm(
                        context,
                        title: 'Delete your account?',
                        message:
                            'This permanently deletes your account. Firebase may ask you to sign in again first.',
                      );
                      if (!ok) return;
                      try {
                        await FirebaseAuth.instance.currentUser?.delete();
                      } on FirebaseAuthException catch (e) {
                        if (context.mounted) {
                          toast(
                            context,
                            e.code == 'requires-recent-login'
                                ? 'Please sign out and in again, then retry.'
                                : (e.message ?? 'Failed'),
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
                description: Env.demo
                    ? 'Demo mode: sample data, nothing is saved.'
                    : 'Your research desk, everywhere.',
                child: Text('1.0.0', style: context.text.labelMedium),
              ),
            ],
          ),
        ],
      ),
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
    return Padding(
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
                for (final (i, child) in children.indexed) ...[
                  if (i > 0) Divider(color: c.line, height: 1),
                  child,
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
        if (description != null) ...[
          const SizedBox(height: 3),
          Text(description!, style: context.text.bodySmall),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: context.isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [left, const SizedBox(height: 10), child],
            )
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
