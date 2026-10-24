import 'package:dscvr/config/env.dart';
import 'package:dscvr/data/firestore_library_repository.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';

/// Three short steps: who you are, what you study, how DSCVR works.
/// Selected interests become starter categories in the library.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const roles = ['Student', 'Researcher', 'Engineer', 'Writer', 'Educator', 'Curious mind'];
  static const subjects = [
    'Computer Science', 'Machine Learning', 'Economics', 'Neuroscience', 'Psychology', 'Biology',
    'Physics', 'Mathematics', 'Philosophy', 'History', 'Finance', 'Medicine', 'Design', 'Law',
  ];

  int _step = 0;
  late final _name = TextEditingController(text: context.services.session.user.displayName == 'DSCVR User'
      ? ''
      : context.services.session.user.displayName);
  String _role = 'Student';
  final List<String> _interests = [];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final session = context.services.session;
    try {
      if (!Env.demo) {
        final repo = FirestoreLibraryRepository(uid: session.user.id);
        for (final (i, name) in _interests.take(8).indexed) {
          await repo.createCategory(name: name, colorIndex: i);
        }
      }
      await session.completeOnboarding(
        displayName: _name.text.trim().isEmpty ? session.user.displayName : _name.text.trim(),
        role: _role,
        interests: _interests,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        toast(context, 'Could not finish setup: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final canNext = switch (_step) {
      0 => _name.text.trim().isNotEmpty,
      1 => _interests.isNotEmpty,
      _ => true,
    };
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const DscvrMark(size: 30),
                  const Spacer(),
                  for (var i = 0; i < 3; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(left: 6),
                      width: i == _step ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= _step ? c.ink : c.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ]),
                const SizedBox(height: 40),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(key: ValueKey(_step), child: _body(c)),
                ),
                const SizedBox(height: 36),
                Row(children: [
                  if (_step > 0)
                    AppButton.ghost(onPressed: () => setState(() => _step--), child: const Text('Back')),
                  const Spacer(),
                  AppButton.primary(
                    onPressed: !canNext || _saving
                        ? null
                        : () => _step < 2 ? setState(() => _step++) : _finish(),
                    child: _saving
                        ? SizedBox(width: 16, height: 16, child: Spinner(size: 16, color: c.inverseInk))
                        : Text(_step < 2 ? 'Continue' : 'Open my library'),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(DscvrColors c) {
    switch (_step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Welcome to DSCVR', style: context.text.displaySmall),
          const SizedBox(height: 10),
          Text('A personal research library with an assistant that has actually read your sources.',
              style: AppTheme.sans(fontSize: 15, color: c.inkMuted, height: 1.55)),
          const SizedBox(height: 28),
          AppField(
            controller: _name,
            label: 'What should we call you?',
            hint: 'Your name',
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 22),
          Text('You are mostly a...', style: context.text.labelMedium),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in roles)
              AppChip(label: r, selected: _role == r, onTap: () => setState(() => _role = r)),
          ]),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What do you study?', style: context.text.displaySmall),
          const SizedBox(height: 10),
          Text('Each pick becomes a category in your library. You can rename or add more later.',
              style: AppTheme.sans(fontSize: 15, color: c.inkMuted, height: 1.55)),
          const SizedBox(height: 26),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in subjects)
              AppChip(
                label: s,
                selected: _interests.contains(s),
                leading: _interests.contains(s) ? ColorDot(CategoryPalette.of(_interests.indexOf(s))) : null,
                onTap: () => setState(() => _interests.contains(s) ? _interests.remove(s) : _interests.add(s)),
              ),
          ]),
        ]);
      default:
        final points = [
          (Ic.library, 'Your library', 'Categories hold topics, topics hold materials: papers, PDFs, articles, notes and lectures.'),
          (Ic.book, 'Read and annotate', 'A calm reader with margin notes. Select any passage to quote it or ask about it.'),
          (Ic.pinda, 'Pinda', 'Ask questions about a single paper, a topic, or your entire library. Pinda answers from your sources.'),
        ];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How it works', style: context.text.displaySmall),
          const SizedBox(height: 26),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: c.line)),
                  child: Icon(p.$1, size: 19, color: c.ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.$2, style: context.text.titleMedium),
                    const SizedBox(height: 4),
                    Text(p.$3, style: AppTheme.sans(fontSize: 14, color: c.inkMuted, height: 1.5)),
                  ]),
                ),
              ]),
            ),
        ]);
    }
  }
}
