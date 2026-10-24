import 'package:dscvr/config/env.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/screens/library/shelf_page.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    final settings = s.settings;
    final user = s.session.user;
    final c = context.colors;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => PageBody(maxWidth: 720, children: [
        const PageTitle('Settings'),
        const SizedBox(height: 28),
        _Section(title: 'Appearance', children: [
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
              child: Row(children: [
                Icon(Ic.textSize, size: 14, color: c.inkFaint),
                Expanded(
                  child: Slider(
                    value: settings.readerScale,
                    min: 0.85,
                    max: 1.4,
                    divisions: 11,
                    activeColor: c.ink,
                    inactiveColor: c.line,
                    onChanged: settings.setReaderScale,
                  ),
                ),
                Icon(Ic.textSize, size: 20, color: c.inkFaint),
              ]),
            ),
          ),
        ]),
        _Section(title: 'Pinda', children: [
          _Row(
            label: 'Answer style',
            description: 'Concise answers get to the point. Detailed answers explain and cite more.',
            child: Segmented<String>(
              options: const [('concise', 'Concise', null), ('detailed', 'Detailed', null)],
              value: settings.pindaStyle,
              onChanged: settings.setPindaStyle,
            ),
          ),
        ]),
        _Section(title: 'Account', children: [
          _Row(
            label: user.displayName,
            description: user.email,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: c.chip,
              child: Text(user.initials, style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
            ),
          ),
          if (!Env.demo) ...[
            _Row(
              label: 'Password',
              description: 'We will email you a reset link.',
              child: OutlinedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email);
                  if (context.mounted) toast(context, 'Reset link sent to ${user.email}');
                },
                child: const Text('Reset'),
              ),
            ),
            _Row(
              label: 'Sign out',
              child: OutlinedButton.icon(
                onPressed: () => s.session.signOut(),
                icon: const Icon(Ic.signOut, size: 16),
                label: const Text('Sign out'),
              ),
            ),
            _Row(
              label: 'Delete account',
              description: 'Removes your profile. Library data is deleted with it.',
              child: TextButton(
                onPressed: () async {
                  final ok = await confirm(context,
                      title: 'Delete your account?',
                      message: 'This permanently deletes your account. Firebase may ask you to sign in again first.');
                  if (!ok) return;
                  try {
                    await FirebaseAuth.instance.currentUser?.delete();
                  } on FirebaseAuthException catch (e) {
                    if (context.mounted) {
                      toast(context, e.code == 'requires-recent-login' ? 'Please sign out and in again, then retry.' : (e.message ?? 'Failed'));
                    }
                  }
                },
                child: Text('Delete', style: TextStyle(color: c.danger)),
              ),
            ),
          ],
        ]),
        _Section(title: 'About', children: [
          _Row(
            label: 'DSCVR',
            description: Env.demo ? 'Demo mode: sample data, nothing is saved.' : 'Free forever. No ads, no tracking, no algorithmic feed.',
            child: Text('1.0.0', style: context.text.labelMedium),
          ),
        ]),
      ]),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: context.text.titleLarge),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: c.line),
          ),
          child: Column(children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) Divider(color: c.line, height: 1),
              child,
            ],
          ]),
        ),
      ]),
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
    final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: context.text.titleSmall),
      if (description != null) ...[
        const SizedBox(height: 3),
        Text(description!, style: context.text.bodySmall),
      ],
    ]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: context.isCompact
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, const SizedBox(height: 10), child])
          : Row(children: [Expanded(child: left), const SizedBox(width: 16), child]),
    );
  }
}
