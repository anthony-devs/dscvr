import 'dart:math';

import 'package:dscvr/data/api.dart';
import 'package:dscvr/data/study_service.dart';
import 'package:dscvr/models/library.dart';
import 'package:dscvr/models/profession.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Turns the open item into flashcards, practice questions, a case brief or
/// an evidence summary. Results are kept, so reopening one is free.
class StudyPanel extends StatefulWidget {
  const StudyPanel({super.key, required this.item});
  final LibraryItem item;

  @override
  State<StudyPanel> createState() => _StudyPanelState();
}

class _StudyPanelState extends State<StudyPanel> {
  late final StudyService _svc =
      StudyService(api: context.services.api, uid: () => context.services.session.user.id);
  StudyKind? _kind;
  StudySet? _set;
  bool _loading = false;
  String? _error;
  bool _limit = false;

  bool get _looksLikeCase =>
      widget.item.source == 'uk_caselaw' || RegExp(r'\sv\.?\s', caseSensitive: false).hasMatch(widget.item.title);

  List<StudyKind> get _kinds {
    final p = context.services.session.user.profession;
    final health = widget.item.source == 'europepmc' || (p?.isHealth ?? false);
    final law = _looksLikeCase || p == Profession.law;
    return [
      if (law) StudyKind.brief,
      if (health && !law) StudyKind.evidence,
      StudyKind.flashcards,
      StudyKind.quiz,
      if (!law) StudyKind.brief,
      if (!health || law) StudyKind.evidence,
    ];
  }

  Future<void> _open(StudyKind k, {bool fresh = false}) async {
    setState(() {
      _kind = k;
      _set = null;
      _error = null;
      _limit = false;
      _loading = true;
    });
    try {
      final saved = fresh ? null : await _svc.saved(widget.item.id, k);
      final set = saved ?? await _svc.make(widget.item.id, k);
      if (mounted && _kind == k) setState(() => _set = set);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _limit = e.status == 429 && e.message.toLowerCase().contains('usage');
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_kind == null) {
      return ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 28), children: [
        Text('Study this', style: context.text.titleLarge),
        const SizedBox(height: 4),
        Text('Pinda builds these from this item only. Check anything important against the source.',
            style: AppTheme.sans(fontSize: 13, color: c.inkMuted, height: 1.45)),
        const SizedBox(height: 16),
        for (final k in _kinds)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ChoiceRow(title: k.label, subtitle: k.blurb, selected: false, onTap: () => _open(k)),
          ),
      ]);
    }
    final k = _kind!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
        child: Row(children: [
          AppIconButton(tooltip: 'All study tools', onPressed: () => setState(() => _kind = null), icon: const Icon(Ic.back, size: 18)),
          const SizedBox(width: 4),
          Expanded(child: Text(k.label, style: context.text.titleMedium)),
          if (_set != null)
            AppIconButton(tooltip: 'Make a new set', onPressed: () => _open(k, fresh: true), icon: const Icon(Ic.retry, size: 17)),
        ]),
      ),
      Divider(color: c.line, height: 1),
      Expanded(
        child: _loading
            ? Center(
                child: Semantics(
                  liveRegion: true,
                  label: 'Pinda is making ${k.label.toLowerCase()}',
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Spinner(size: 22),
                    const SizedBox(height: 12),
                    Text('Pinda is reading and writing your ${k.label.toLowerCase()}…',
                        style: AppTheme.sans(fontSize: 13, color: c.inkMuted)),
                  ]),
                ),
              )
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Semantics(liveRegion: true, child: Text(_error!, style: AppTheme.sans(fontSize: 14, color: c.ink, height: 1.5))),
                      const SizedBox(height: 14),
                      _limit
                          ? AppButton.primary(onPressed: () => context.go('/plans'), label: const Text('See plans'))
                          : AppButton.secondary(onPressed: () => _open(k), icon: const Icon(Ic.retry, size: 14), label: const Text('Try again')),
                    ]),
                  )
                : _set == null
                    ? const SizedBox.shrink()
                    : switch (k) {
                        StudyKind.flashcards => _Flashcards(cards: _set!.cards),
                        StudyKind.quiz => _Quiz(questions: _set!.questions),
                        StudyKind.brief => _Structured(data: _set!.data, sections: _briefSections),
                        StudyKind.evidence => _Structured(data: _set!.data, sections: _evidenceSections),
                      },
      ),
    ]);
  }

  static const _briefSections = [
    ('caseName', 'Case'), ('citation', 'Citation'), ('court', 'Court'), ('date', 'Date'), ('judges', 'Judges'),
    ('parties', 'Parties'), ('facts', 'Facts'), ('history', 'Procedural history'), ('issues', 'Issues'),
    ('holding', 'Holding'), ('ratio', 'Ratio decidendi'), ('obiter', 'Obiter dicta'), ('dissent', 'Dissent and concurrence'),
    ('outcome', 'Outcome'), ('statutes', 'Statutes'), ('casesCited', 'Cases cited'),
  ];

  static const _evidenceSections = [
    ('design', 'Study design'), ('level', 'Level of evidence'), ('population', 'Population'),
    ('intervention', 'Intervention or exposure'), ('comparison', 'Comparison'), ('outcomes', 'Outcomes'),
    ('findings', 'Findings'), ('limitations', 'Limitations'), ('practice', 'What it means'),
  ];
}

// ── Flashcards ─────────────────────────────────────────────────────────

class _Flashcards extends StatefulWidget {
  const _Flashcards({required this.cards});
  final List<Flashcard> cards;

  @override
  State<_Flashcards> createState() => _FlashcardsState();
}

class _FlashcardsState extends State<_Flashcards> {
  late List<Flashcard> _cards = widget.cards;
  int _i = 0;
  bool _back = false;
  final Set<int> _known = {};

  void _go(int d) => setState(() {
        _i = (_i + d).clamp(0, _cards.length - 1);
        _back = false;
      });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_cards.isEmpty) return const EmptyState(icon: Ic.notebook, title: 'No cards', message: 'Try making a new set.');
    final card = _cards[_i];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.space): () => setState(() => _back = !_back),
      },
      child: Focus(
        autofocus: true,
        child: ListView(padding: const EdgeInsets.all(18), children: [
          Row(children: [
            Text('Card ${_i + 1} of ${_cards.length}', style: context.text.labelSmall),
            const Spacer(),
            Text('${_known.length} known', style: context.text.labelSmall),
          ]),
          const SizedBox(height: 10),
          Pressable(
            onTap: () => setState(() => _back = !_back),
            semanticLabel: _back ? 'Answer: ${card.back}. Tap to see the question.' : 'Question: ${card.front}. Tap to see the answer.',
            child: ExcludeSemantics(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                constraints: const BoxConstraints(minHeight: 200),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: _back ? c.selection : c.surface,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(color: _back ? c.ink : c.line, width: _back ? 1.5 : 1),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_back ? 'Answer' : 'Question', style: context.text.labelSmall),
                  const SizedBox(height: 10),
                  Text(_back ? card.back : card.front,
                      style: AppTheme.serif(fontSize: _back ? 16 : 18, color: c.ink, height: 1.45, fontWeight: _back ? null : FontWeight.w600)),
                  if (!_back) ...[
                    const SizedBox(height: 14),
                    Text('Tap or press space to flip', style: AppTheme.sans(fontSize: 12, color: c.inkFaint)),
                  ],
                ]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            AppIconButton(tooltip: 'Previous card', onPressed: _i > 0 ? () => _go(-1) : null, icon: const Icon(Ic.back, size: 18)),
            const Spacer(),
            AppButton.ghost(
              size: BtnSize.sm,
              onPressed: () => setState(() {
                _known.contains(_i) ? _known.remove(_i) : _known.add(_i);
              }),
              label: Text(_known.contains(_i) ? 'Marked as known' : 'I know this'),
            ),
            AppButton.ghost(
              size: BtnSize.sm,
              onPressed: () => setState(() {
                _cards = [..._cards]..shuffle(Random());
                _i = 0;
                _back = false;
                _known.clear();
              }),
              label: const Text('Shuffle'),
            ),
            const Spacer(),
            AppIconButton(
                tooltip: 'Next card', onPressed: _i < _cards.length - 1 ? () => _go(1) : null, icon: const Icon(Ic.arrowRight, size: 18)),
          ]),
        ]),
      ),
    );
  }
}

// ── Practice questions ─────────────────────────────────────────────────

class _Quiz extends StatefulWidget {
  const _Quiz({required this.questions});
  final List<QuizQuestion> questions;

  @override
  State<_Quiz> createState() => _QuizState();
}

class _QuizState extends State<_Quiz> {
  int _i = 0;
  int? _picked;
  int _score = 0;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final qs = widget.questions;
    if (qs.isEmpty) return const EmptyState(icon: Ic.notebook, title: 'No questions', message: 'Try making a new set.');
    if (_done) {
      return ListView(padding: const EdgeInsets.all(22), children: [
        Semantics(
          liveRegion: true,
          child: Text('You scored $_score of ${qs.length}', style: context.text.headlineSmall),
        ),
        const SizedBox(height: 8),
        Text(_score == qs.length ? 'Full marks.' : 'Go back over the explanations for the ones you missed.',
            style: AppTheme.sans(fontSize: 14, color: c.inkMuted)),
        const SizedBox(height: 18),
        AppButton.primary(
          onPressed: () => setState(() {
            _i = 0;
            _picked = null;
            _score = 0;
            _done = false;
          }),
          label: const Text('Try again'),
        ),
      ]);
    }
    final q = qs[_i];
    final answered = _picked != null;
    return ListView(padding: const EdgeInsets.all(18), children: [
      Text('Question ${_i + 1} of ${qs.length}', style: context.text.labelSmall),
      const SizedBox(height: 8),
      Semantics(header: true, child: Text(q.question, style: AppTheme.serif(fontSize: 17, fontWeight: FontWeight.w600, color: c.ink, height: 1.45))),
      const SizedBox(height: 14),
      for (final (n, o) in q.options.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _Option(
            letter: String.fromCharCode(65 + n),
            text: o,
            state: !answered
                ? _OptState.idle
                : n == q.answer
                    ? _OptState.right
                    : n == _picked
                        ? _OptState.wrong
                        : _OptState.dim,
            onTap: answered
                ? null
                : () => setState(() {
                      _picked = n;
                      if (n == q.answer) _score++;
                    }),
          ),
        ),
      if (answered) ...[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (_picked == q.answer ? c.success : c.danger).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: (_picked == q.answer ? c.success : c.danger).withValues(alpha: 0.35)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_picked == q.answer ? 'Correct' : 'Not quite. The answer is ${String.fromCharCode(65 + q.answer)}.',
                  style: AppTheme.sans(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
              const SizedBox(height: 6),
              Text(q.explanation, style: AppTheme.sans(fontSize: 14, color: c.ink, height: 1.5)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton.primary(
            onPressed: () => setState(() {
              if (_i == qs.length - 1) {
                _done = true;
              } else {
                _i++;
                _picked = null;
              }
            }),
            label: Text(_i == qs.length - 1 ? 'See score' : 'Next question'),
          ),
        ),
      ],
    ]);
  }
}

enum _OptState { idle, right, wrong, dim }

class _Option extends StatelessWidget {
  const _Option({required this.letter, required this.text, required this.state, this.onTap});
  final String letter;
  final String text;
  final _OptState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, border) = switch (state) {
      _OptState.right => (c.success.withValues(alpha: 0.10), c.success),
      _OptState.wrong => (c.danger.withValues(alpha: 0.10), c.danger),
      _ => (c.surface, c.line),
    };
    final status = switch (state) { _OptState.right => ', correct answer', _OptState.wrong => ', your answer, incorrect', _ => '' };
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      semanticLabel: 'Option $letter: $text$status',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: border)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$letter.', style: AppTheme.sans(fontSize: 14, fontWeight: FontWeight.w700, color: c.inkMuted)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: AppTheme.sans(fontSize: 14, color: state == _OptState.dim ? c.inkMuted : c.ink, height: 1.45)),
            ),
            if (state == _OptState.right) Icon(Ic.check, size: 16, color: c.success),
          ]),
        ),
      ),
    );
  }
}

// ── Case brief / evidence summary ──────────────────────────────────────

class _Structured extends StatelessWidget {
  const _Structured({required this.data, required this.sections});
  final Map<String, dynamic> data;
  final List<(String, String)> sections;

  String _asText() {
    final b = StringBuffer();
    for (final (key, label) in sections) {
      final v = data[key];
      if (v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty)) continue;
      b.writeln(label.toUpperCase());
      if (v is List) {
        for (final x in v) {
          b.writeln('- $x');
        }
      } else {
        b.writeln(v);
      }
      b.writeln();
    }
    return b.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 28), children: [
      for (final (key, label) in sections)
        if (data[key] != null && !(data[key] is String && (data[key] as String).trim().isEmpty) && !(data[key] is List && (data[key] as List).isEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text(label, style: context.text.labelMedium)),
              const SizedBox(height: 5),
              if (data[key] is List)
                for (final x in data[key] as List)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.only(top: 8, right: 8), child: Container(width: 4, height: 4, color: c.inkMuted)),
                      Expanded(child: SelectableText('$x', style: AppTheme.sans(fontSize: 14, color: c.ink, height: 1.5))),
                    ]),
                  )
              else
                SelectableText('${data[key]}',
                    style: key == 'caseName'
                        ? AppTheme.serif(fontSize: 18, fontWeight: FontWeight.w600, color: c.ink, height: 1.35, fontStyle: FontStyle.italic)
                        : AppTheme.sans(fontSize: 14, color: c.ink, height: 1.55)),
            ]),
          ),
      const SizedBox(height: 4),
      Wrap(spacing: 8, children: [
        AppButton.secondary(
          size: BtnSize.sm,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _asText()));
            if (context.mounted) toast(context, 'Copied');
          },
          icon: const Icon(Ic.copy, size: 14),
          label: const Text('Copy'),
        ),
      ]),
      const SizedBox(height: 14),
      Text('Made by Pinda from this item. Not legal or medical advice.', style: AppTheme.sans(fontSize: 12, color: c.inkFaint)),
    ]);
  }
}
