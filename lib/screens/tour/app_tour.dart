import 'package:dscvr/config/env.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class _Step {
  const _Step(this.icon, this.title, this.body, {this.route, this.action});
  final IconData? icon;
  final String title;
  final String body;
  final String? route;
  final String? action;
}

const _steps = <_Step>[
  _Step(null, 'Meet Pinda',
      'DSCVR is your research library. Pinda is the pangolin who reads with you. This takes about a minute, and you can replay it any time from Settings.'),
  _Step(Ic.library, 'Your library',
      'Collect papers, PDFs, links and notes in categories and topics. Everything stays readable offline, and Pinda only answers from what you have saved.',
      route: '/library', action: 'Open library'),
  _Step(Ic.discover, 'Discover',
      'One search covers arXiv, PubMed, Crossref, OpenAlex and more, and every result shows its source. Tap a subject to see what is new. Law students pick a country to open its free law reports.',
      route: '/discover', action: 'Open Discover'),
  _Step(Ic.report, 'Read, listen and study',
      'Open any paper or PDF to read it here. Ask Pinda about a passage, have it read aloud, cite it in your style, or switch to Study for flashcards, practice questions and case briefs.'),
  _Step(Ic.pinda, 'Ask Pinda',
      'Chat about your whole library or one reading. Pinda is built by the DSCVR team, answers with sources, and says so when it does not know.',
      route: '/pinda', action: 'Ask Pinda'),
  _Step(Ic.lightning, 'Alerts',
      'Pick your subjects and Pinda checks every morning for new work, then leaves it in your inbox. Email is optional.',
      route: '/alerts', action: 'Set up alerts'),
  _Step(Ic.settings, 'Make it comfortable',
      'Settings has text size, easier-to-read fonts, high contrast, reduced motion, read-aloud speed, low data mode and your field. Screen readers and the keyboard work everywhere.',
      route: '/settings', action: 'Open Settings'),
];

/// Opens the app tour. Marks it as seen on this device however it is closed.
Future<void> showAppTour(BuildContext context) async {
  final settings = Services.of(context).settings;
  await showAdaptiveSheet<void>(context, maxWidth: 460, builder: (ctx) => _TourCard(parent: context));
  settings.setTourSeen(true);
}

class _TourCard extends StatefulWidget {
  const _TourCard({required this.parent});
  final BuildContext parent;

  @override
  State<_TourCard> createState() => _TourCardState();
}

class _TourCardState extends State<_TourCard> {
  int _i = 0;

  void _go(int to) => setState(() => _i = to.clamp(0, _steps.length - 1));

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final step = _steps[_i];
    final last = _i == _steps.length - 1;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => last ? _close() : _go(_i + 1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(_i - 1),
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Semantics(
                  label: 'Step ${_i + 1} of ${_steps.length}',
                  excludeSemantics: true,
                  child: Row(children: [
                    for (var k = 0; k < _steps.length; k++)
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: k == _steps.length - 1 ? 0 : 5),
                          decoration: BoxDecoration(
                            color: k <= _i ? c.ink : c.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              AppButton.ghost(size: BtnSize.sm, onPressed: _close, child: Text(last ? 'Close' : 'Skip')),
            ]),
            const SizedBox(height: 22),
            Semantics(
              liveRegion: true,
              container: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (step.icon == null)
                  const Center(child: PindaFigure(width: 150))
                else
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: c.selection, borderRadius: BorderRadius.circular(16)),
                    child: Icon(step.icon, size: 24, color: c.ink),
                  ),
                const SizedBox(height: 18),
                Text(step.title, style: AppTheme.sans(fontSize: 22, fontWeight: FontWeight.w700, color: c.ink, height: 1.2)),
                const SizedBox(height: 8),
                Text(step.body, style: AppTheme.sans(fontSize: 14.5, color: c.inkMuted, height: 1.55)),
              ]),
            ),
            const SizedBox(height: 22),
            Row(children: [
              if (_i > 0) AppButton.ghost(onPressed: () => _go(_i - 1), child: const Text('Back')),
              const Spacer(),
              if (step.route != null) ...[
                AppButton.secondary(
                  onPressed: () {
                    final route = step.route!;
                    final parent = widget.parent;
                    _close();
                    if (parent.mounted) parent.go(route);
                  },
                  child: Text(step.action ?? 'Open'),
                ),
                const SizedBox(width: 8),
              ],
              AppButton.primary(onPressed: last ? _close : () => _go(_i + 1), child: Text(last ? 'Done' : (_i == 0 ? 'Start' : 'Next'))),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Shows the tour once, the first time someone reaches the library on a device.
class TourGate extends StatefulWidget {
  const TourGate({super.key, required this.child});
  final Widget child;

  @override
  State<TourGate> createState() => _TourGateState();
}

class _TourGateState extends State<TourGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      final s = Services.of(context);
      if (!Env.demo && !s.settings.tourSeen && s.session.user.onboarded && ModalRoute.of(context)?.isCurrent == true) {
        showAppTour(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
