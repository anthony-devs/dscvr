import 'package:dscvr/models/subjects.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';

/// Search across every subject, or add your own. Shows popular subjects
/// until the user types; any typed text can be added as a custom subject.
class SubjectSearch extends StatefulWidget {
  const SubjectSearch({super.key, required this.selected, required this.onToggle, this.autofocus = false, this.maxResults = 30});

  /// Labels currently selected.
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final bool autofocus;
  final int maxResults;

  @override
  State<SubjectSearch> createState() => _SubjectSearchState();
}

class _SubjectSearchState extends State<SubjectSearch> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool _isSelected(String label) => widget.selected.any((s) => s.toLowerCase() == label.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _q.text.trim();
    final results = q.isEmpty
        ? [for (final p in Subject.popular) Subject.lookup(p)!]
        : Subject.search(q, limit: widget.maxResults);
    final exact = q.isNotEmpty && results.any((s) => s.label.toLowerCase() == q.toLowerCase());
    // Selected subjects that aren't in the current list stay visible at the front.
    final extra = [for (final s in widget.selected) if (!results.any((r) => r.label.toLowerCase() == s.toLowerCase())) s];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _q,
        autofocus: widget.autofocus,
        onChanged: (_) => setState(() {}),
        onSubmitted: (v) {
          final t = v.trim();
          if (t.isEmpty) return;
          final match = Subject.lookup(t);
          widget.onToggle(match?.label ?? t);
          _q.clear();
          setState(() {});
        },
        textCapitalization: TextCapitalization.words,
        style: AppTheme.sans(fontSize: 15, color: c.ink),
        decoration: InputDecoration(
          hintText: 'Search 130+ subjects or type your own',
          prefixIcon: const Icon(Ic.search, size: 18),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
      ),
      const SizedBox(height: 14),
      if (q.isEmpty) ...[
        Text('Popular', style: AppTheme.sans(fontSize: 12, fontWeight: FontWeight.w600, color: c.inkFaint)),
        const SizedBox(height: 8),
      ],
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in extra) AppChip(label: s, selected: true, onTap: () => widget.onToggle(s)),
        for (final s in results)
          AppChip(
            label: s.label,
            selected: _isSelected(s.label),
            onTap: () => setState(() => widget.onToggle(s.label)),
          ),
        if (q.isNotEmpty && !exact)
          AppChip(
            label: 'Add "$q"',
            leading: const Icon(Ic.add, size: 13),
            selected: false,
            onTap: () {
              widget.onToggle(q);
              _q.clear();
              setState(() {});
            },
          ),
      ]),
      if (q.isNotEmpty && results.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('Not in our list yet. Add it as your own subject.', style: AppTheme.sans(fontSize: 13, color: c.inkMuted)),
        ),
    ]);
  }
}

/// A sheet to pick one subject to browse (Discover).
Future<String?> pickSubject(BuildContext context) => showAdaptiveSheet<String>(
      context,
      maxWidth: 620,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SheetHeader(title: 'Browse a subject', subtitle: 'Any field. Pick one, or type your own.'),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: SubjectSearch(selected: const [], autofocus: true, onToggle: (s) => Navigator.of(ctx).pop(s)),
          ),
        ),
      ]),
    );
