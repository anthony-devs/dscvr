import 'dart:async';

import 'package:dscvr/config/env.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// One stop on a page tour. A step with no [target] is a centred card, used to
/// introduce the page; a step whose target is not on screen right now is skipped.
class TourStep {
  const TourStep(this.title, this.body, {this.target});
  final String? target;
  final String title;
  final String body;
}

/// The tour for each page, in plain words. Targets are marked in the page with [TourTarget].
const Map<String, List<TourStep>> pageTours = {
  'recent': [
    TourStep('Home', 'This is where you pick up. What you read lately is here, with shortcuts for what to do next.'),
    TourStep('Quick actions', 'The things people do most: ask Pinda, upload a PDF, start a focus session, add a voice note. They change with your edition.',
        target: 'recent.actions'),
    TourStep('Continue reading', 'Anything you opened and did not finish waits here. Tap one to go straight back to where you stopped.', target: 'recent.continue'),
    TourStep('Recently opened', 'Your latest material. Tap a card to read it, or open the library to see everything.', target: 'recent.recent'),
    TourStep('Add material', 'Papers, PDFs, links, YouTube lectures or notes. Add them here and Pinda can read them too.', target: 'shell.add'),
    TourStep('Move around', 'Library, Discover, Pinda and your other pages are always one tap away.', target: 'shell.nav'),
  ],
  'library': [
    TourStep('Your library', 'Everything you save lives here, in categories and topics, like shelves. Pinda only answers from what you save.'),
    TourStep('New category and reading list', 'Make a category for each subject or course. The reading list holds what you plan to read next.', target: 'library.actions'),
    TourStep('Your shelves', 'Tap a category to open it, then group material into topics inside it.', target: 'library.shelves'),
    TourStep('Add material', 'Save a paper, PDF, link or note from here.', target: 'shell.add'),
  ],
  'shelf': [
    TourStep('A shelf', 'This is one category or topic. Everything saved under it is listed here, and you can ask Pinda about just this shelf.'),
    TourStep('Add material', 'New items you add from here go straight onto this shelf.', target: 'shell.add'),
    TourStep('Ask Pinda', 'Pinda can answer questions about only the material on this shelf.', target: 'shell.pinda'),
  ],
  'discover': [
    TourStep('Discover', 'Find free research from many sources at once, then save it to your library or read it right here.'),
    TourStep('Search', 'Type a topic, an author or an idea. Results come from arXiv, PubMed, Crossref, OpenAlex and more, and each one shows where it came from.',
        target: 'discover.search'),
    TourStep('Narrow it down', 'Pick a source, show only papers with a free PDF, or turn on guidelines only for clinical work.', target: 'discover.filters'),
    TourStep('Latest in your subjects', 'Tap a subject to see what is new in it. Use More subjects to add others.', target: 'discover.subjects'),
    TourStep('Law reports', 'Law students: pick a country to open its free law libraries with your search ready.', target: 'discover.law'),
    TourStep('Results', 'Tap a result to read the abstract, save it, open its PDF or cite it.', target: 'discover.results'),
  ],
  'pinda': [
    TourStep('Pinda', 'Pinda is your research assistant. Ask in your own words and the answers come from your saved material, with sources.'),
    TourStep('Ask anything', 'Type here and press Enter. Shift and Enter starts a new line.', target: 'pinda.input'),
    TourStep('Ask by voice', 'Tap the microphone and speak your question.', target: 'pinda.mic'),
    TourStep('What Pinda reads', 'Choose your whole library, one category, one topic or a single reading. Smaller scope, sharper answers.', target: 'pinda.scope'),
    TourStep('Read replies aloud', 'Turn this on and every answer is spoken as it arrives.', target: 'pinda.speaker'),
  ],
  'alerts': [
    TourStep('Alerts', 'Pinda checks your subjects every morning and leaves new papers, guidelines and judgments here.'),
    TourStep('What it watches', 'These are the subjects Pinda follows for you. Change them in Settings.', target: 'alerts.about'),
    TourStep('Check now', 'Look for new items straight away, then mark them read when you are done.', target: 'alerts.actions'),
  ],
  'settings': [
    TourStep('Settings', 'Make DSCVR comfortable and set up your field. Most changes apply straight away.'),
    TourStep('Appearance', 'Light, dark or follow your device.', target: 'settings.appearance'),
    TourStep('Accessibility', 'Text size, easier fonts, line spacing, high contrast, reduced motion and read-aloud speed.', target: 'settings.accessibility'),
    TourStep('Your field', 'Tell DSCVR what you study or practise so search, Pinda and alerts fit you.', target: 'settings.your field and subjects'),
    TourStep('Data and offline', 'Low data mode keeps pages light on slow or costly connections.', target: 'settings.data and offline'),
    TourStep('Help', 'Replay the full app tour any time.', target: 'settings.help'),
  ],
  'reader': [
    TourStep('Reading', 'Read here, then ask Pinda, take notes or study what you read.'),
    TourStep('Listen', 'Have the text read aloud. Speed is in Settings.', target: 'reader.listen'),
    TourStep('Cite', 'Copy a citation in APA, Harvard, Vancouver, OSCOLA and more, or export to a reference manager.', target: 'reader.cite'),
    TourStep('Pinda, notes and study', 'Switch tabs to ask Pinda about this reading, keep notes, or make flashcards, practice questions and case briefs.', target: 'reader.tabs'),
  ],
  'reports': [
    TourStep('Reports', 'Ask Pinda to write a structured report from your material, then edit it and export it.'),
    TourStep('New report', 'Start one from the button at the top of the page, or from the home shortcuts.'),
  ],
  'sessions': [
    TourStep('Sessions', 'Focus sessions track a block of reading and give you a summary at the end. Group sessions let a team read together.'),
  ],
  'team': [
    TourStep('Team', 'Create an organisation or join one with an invite code to share a library and billing.'),
  ],
  'plans': [
    TourStep('Plans', 'Compare plans and upgrade when you need more. Free is free, and nothing is charged without your confirmation.'),
  ],
};

/// Which tour a route belongs to, or null when it has none.
String? tourKeyFor(String location) {
  final seg = Uri.parse(location).pathSegments;
  if (seg.isEmpty) return 'recent';
  return switch (seg.first) {
    'recent' || 'reading-list' => 'recent',
    'library' => 'library',
    'c' => 'shelf',
    'm' || 'read' => 'reader',
    final k when pageTours.containsKey(k) => k,
    _ => null,
  };
}

/// Marks a widget so a page tour can point at it. Cheap, and invisible otherwise.
class TourTarget extends StatefulWidget {
  const TourTarget({super.key, required this.id, required this.child});
  final String id;
  final Widget child;

  static final Map<String, GlobalKey> _keys = {};
  static GlobalKey? keyOf(String id) => _keys[id];

  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    TourTarget._keys[widget.id] = _key;
  }

  @override
  void didUpdateWidget(TourTarget old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      if (TourTarget._keys[old.id] == _key) TourTarget._keys.remove(old.id);
      TourTarget._keys[widget.id] = _key;
    }
  }

  @override
  void dispose() {
    if (TourTarget._keys[widget.id] == _key) TourTarget._keys.remove(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.child);
}

bool _onScreen(String id) {
  final ctx = TourTarget.keyOf(id)?.currentContext;
  final box = ctx?.findRenderObject();
  return box is RenderBox && box.attached && box.hasSize && box.size.width > 0 && box.size.height > 0;
}

OverlayEntry? _open;

/// Runs the tour for [pageKey] over the current page. Returns false if there is none.
bool startPageTour(BuildContext context, String? pageKey, {bool markSeen = true}) {
  final script = pageKey == null ? null : pageTours[pageKey];
  if (script == null || _open != null) return false;
  final steps = [for (final s in script) if (s.target == null || _onScreen(s.target!)) s];
  if (steps.isEmpty) return false;
  final services = Services.of(context);
  if (markSeen) services.settings.markPageTourSeen(pageKey!);
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  void close() {
    entry.remove();
    entry.dispose();
    if (_open == entry) _open = null;
  }

  entry = OverlayEntry(builder: (_) => _CoachOverlay(steps: steps, onClose: close, reduceMotion: services.settings.reduceMotion));
  _open = entry;
  overlay.insert(entry);
  return true;
}

class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({required this.steps, required this.onClose, required this.reduceMotion});
  final List<TourStep> steps;
  final VoidCallback onClose;
  final bool reduceMotion;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay> {
  int _i = 0;
  Rect? _rect;
  final _focus = FocusNode();

  TourStep get _step => widget.steps[_i];

  @override
  void initState() {
    super.initState();
    _measure();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _measure() async {
    final id = _step.target;
    final ctx = id == null ? null : TourTarget.keyOf(id)?.currentContext;
    if (ctx == null) {
      setState(() => _rect = null);
      return;
    }
    try {
      await Scrollable.ensureVisible(ctx,
          alignment: 0.3, duration: widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 260), curve: Curves.easeOut);
    } catch (_) {}
    if (!mounted) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = TourTarget.keyOf(id!)?.currentContext?.findRenderObject();
      if (box is RenderBox && box.attached) {
        final topLeft = box.localToGlobal(Offset.zero);
        setState(() => _rect = topLeft & box.size);
      } else {
        setState(() => _rect = null);
      }
    });
  }

  void _go(int to) {
    if (to < 0) return;
    if (to >= widget.steps.length) {
      widget.onClose();
      return;
    }
    setState(() {
      _i = to;
      _rect = null;
    });
    _measure();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = MediaQuery.sizeOf(context);
    final last = _i == widget.steps.length - 1;
    final hole = _rect?.inflate(6);
    final cardW = (size.width - 32).clamp(240.0, 360.0);
    const cardH = 210.0;
    double left, top;
    if (hole == null) {
      left = (size.width - cardW) / 2;
      top = (size.height - cardH) / 2;
    } else {
      left = hole.left.clamp(16.0, size.width - cardW - 16);
      final below = hole.bottom + 14;
      final above = hole.top - 14 - cardH;
      if (below + cardH <= size.height - 16) {
        top = below;
      } else if (above >= 16) {
        top = above;
      } else {
        top = size.height - cardH - 16;
      }
    }
    final card = Container(
      width: cardW,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: floatingSurface(c, radius: 18, translucent: false),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          liveRegion: true,
          container: true,
          label: 'Step ${_i + 1} of ${widget.steps.length}. ${_step.title}. ${_step.body}',
          child: ExcludeSemantics(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(_step.title, style: AppTheme.sans(fontSize: 16.5, fontWeight: FontWeight.w700, color: c.ink))),
                Text('${_i + 1} / ${widget.steps.length}', style: AppTheme.sans(fontSize: 12, color: c.inkFaint)),
              ]),
              const SizedBox(height: 6),
              Text(_step.body, style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted, height: 1.5)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          AppButton.ghost(size: BtnSize.sm, onPressed: widget.onClose, child: Text(last ? 'Close' : 'Skip')),
          const Spacer(),
          if (_i > 0) AppButton.ghost(size: BtnSize.sm, onPressed: () => _go(_i - 1), child: const Text('Back')),
          const SizedBox(width: 6),
          AppButton.primary(size: BtnSize.sm, onPressed: () => _go(_i + 1), child: Text(last ? 'Done' : 'Next')),
        ]),
      ]),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(_i + 1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(_i - 1),
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Stack(children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: CustomPaint(painter: _ScrimPainter(hole: hole, color: Colors.black.withValues(alpha: c.isDark ? 0.62 : 0.5), ring: c.ink)),
              ),
            ),
          ),
          Positioned(left: left, top: top, child: Material(type: MaterialType.transparency, child: card)),
        ]),
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.hole, required this.color, required this.ring});
  final Rect? hole;
  final Color color;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    if (hole == null) {
      canvas.drawPath(full, Paint()..color = color);
      return;
    }
    final r = RRect.fromRectAndRadius(hole!, const Radius.circular(14));
    canvas.drawPath(Path.combine(PathOperation.difference, full, Path()..addRRect(r)), Paint()..color = color);
    canvas.drawRRect(r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole || old.color != color;
}

/// Help button that starts the tour for [pageKey].
class PageTourButton extends StatelessWidget {
  const PageTourButton({super.key, required this.pageKey, this.size = 32});
  final String? pageKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (pageKey == null || !pageTours.containsKey(pageKey)) return const SizedBox.shrink();
    return RoundIconButton(icon: Ic.question, tooltip: 'Tour this page', size: size, onTap: () => startPageTour(context, pageKey));
  }
}

/// Starts a page's tour once, the first time it is opened on a device, after the welcome tour.
class PageTourGate extends StatefulWidget {
  const PageTourGate({super.key, required this.pageKey, required this.child});
  final String? pageKey;
  final Widget child;

  @override
  State<PageTourGate> createState() => _PageTourGateState();
}

class _PageTourGateState extends State<PageTourGate> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(PageTourGate old) {
    super.didUpdateWidget(old);
    if (old.pageKey != widget.pageKey) _schedule();
  }

  void _schedule() {
    _t?.cancel();
    final key = widget.pageKey;
    if (key == null || Env.demo) return;
    _t = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      final s = Services.of(context);
      if (!s.settings.tourSeen || s.settings.pageTourSeen(key) || !s.session.user.onboarded) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      startPageTour(context, key);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
