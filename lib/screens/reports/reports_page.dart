import 'package:dscvr/models/edition.dart';
import 'package:dscvr/models/workspace.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/screens/library/shelf_page.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// All of the user's reports.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final Stream<List<Report>> _reports = context.services.repo.watchReports();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final edition = context.services.session.user.edition;
    return StreamBuilder<List<Report>>(
      stream: _reports,
      builder: (context, snap) {
        final reports = snap.data ?? const <Report>[];
        return PageBody(maxWidth: 980, children: [
          const SizedBox(height: 18),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const PageTitle('Reports'),
                const SizedBox(height: 6),
                Text(
                  edition == Edition.students
                      ? 'Turn your readings into study notes and summaries, with every point traced to a source.'
                      : 'Draft literature reviews, summaries and comparisons from your sources, then edit and export.',
                  style: AppTheme.sans(fontSize: 14.5, color: c.inkMuted, height: 1.5),
                ),
              ]),
            ),
            if (!context.isCompact) ...[
              const SizedBox(width: 16),
              AppButton.primary(
                onPressed: () => showNewReport(context),
                icon: const Icon(Ic.add, size: 16),
                label: const Text('New report'),
              ),
            ],
          ]),
          if (context.isCompact) ...[
            const SizedBox(height: 14),
            AppButton.primary(onPressed: () => showNewReport(context), icon: const Icon(Ic.add, size: 16), label: const Text('New report')),
          ],
          const SizedBox(height: 26),
          if (snap.connectionState == ConnectionState.waiting && reports.isEmpty)
            const PageSpinner()
          else if (reports.isEmpty)
            EmptyState(
              icon: Ic.report,
              title: 'No reports yet',
              message: 'Pick a few sources and Pinda drafts a cited report you can edit and export.',
              action: AppButton.secondary(onPressed: () => showNewReport(context), child: const Text('Start a report')),
            )
          else ...[
            SectionLabel('Your reports', count: reports.length),
            const SizedBox(height: 8),
            for (final r in reports) _ReportRow(report: r),
          ],
        ]);
      },
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final preview = report.body
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty && !l.startsWith('#') && !l.startsWith('|'), orElse: () => 'Empty draft');
    return Pressable(
      scale: 0.99,
      onTap: () => context.push('/reports/${report.id}'),
      builder: (context, hovered, pressed, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hovered ? c.surface : c.surfaceMuted,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.line),
        ),
        child: child,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(Radii.md)),
          child: Icon(Ic.report, size: 19, color: c.ink),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(report.title, style: AppTheme.serif(fontSize: 17, fontWeight: FontWeight.w600, color: c.ink)),
            const SizedBox(height: 4),
            Text(preview.replaceAll(RegExp(r'[*_`>\[\]]'), ''), maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
            const SizedBox(height: 8),
            Text(
              [report.kind.label, '${report.sourceIds.length} source${report.sourceIds.length == 1 ? '' : 's'}', '${report.wordCount} words', relativeTime(report.updatedAt)]
                  .join('  ·  '),
              style: context.text.labelSmall,
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Collects a report's type, title, sources and instructions, then opens
/// the editor, which drafts it.
Future<void> showNewReport(BuildContext context, {List<String> sourceIds = const []}) async {
  final services = context.services;
  final router = GoRouter.of(context);
  final report = await showAdaptiveSheet<Report>(
    context,
    maxWidth: 640,
    builder: (_) => _NewReportSheet(initial: sourceIds),
  );
  if (report == null) return;
  await services.repo.saveReport(report);
  router.push('/reports/${report.id}?draft=1');
}

class _NewReportSheet extends StatefulWidget {
  const _NewReportSheet({required this.initial});
  final List<String> initial;

  @override
  State<_NewReportSheet> createState() => _NewReportSheetState();
}

class _NewReportSheetState extends State<_NewReportSheet> {
  late ReportKind _kind = context.services.session.user.edition.reportKinds.first;
  final _title = TextEditingController();
  final _instructions = TextEditingController();
  final _filter = TextEditingController();
  late final Set<String> _sources = {...widget.initial};

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    _filter.dispose();
    super.dispose();
  }

  void _create() {
    final now = DateTime.now();
    Navigator.pop(
      context,
      Report(
        id: context.services.repo.newId(),
        title: _title.text.trim().isEmpty ? _kind.label : _title.text.trim(),
        kind: _kind,
        sourceIds: _sources.toList(),
        instructions: _instructions.text.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lib = context.library;
    final edition = context.services.session.user.edition;
    final q = _filter.text.trim().toLowerCase();
    final items = lib.recent.where((i) => q.isEmpty || i.title.toLowerCase().contains(q)).take(60).toList();
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SheetHeader(title: 'New report', subtitle: 'Pinda drafts it from the sources you pick. Every claim is cited.'),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in edition.reportKinds)
              AppChip(label: k.label, selected: _kind == k, onTap: () => setState(() => _kind = k)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Text(_kind.description, style: context.text.bodySmall),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: AppField(controller: _title, label: 'Title', hint: _kind.label),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: AppField(
            controller: _instructions,
            label: 'Instructions (optional)',
            hint: 'e.g. Focus on methods. Keep it under 800 words.',
            maxLines: 3,
            minLines: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
          child: Row(children: [
            Text('Sources', style: context.text.labelMedium),
            const SizedBox(width: 8),
            CountBadge(_sources.length),
            const Spacer(),
            if (_sources.isNotEmpty)
              AppButton.ghost(size: BtnSize.sm, onPressed: () => setState(_sources.clear), child: const Text('Clear')),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AppField(
            controller: _filter,
            hint: 'Filter your library',
            prefixIcon: const Icon(Ic.search, size: 16),
            onChanged: (_) => setState(() {}),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Add papers or notes to your library first.', style: context.text.bodySmall),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final it = items[i];
                    final on = _sources.contains(it.id);
                    return Pressable(
                      scale: 0.99,
                      onTap: () => setState(() => on ? _sources.remove(it.id) : _sources.add(it.id)),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                        decoration: BoxDecoration(
                          color: on ? c.selection : Colors.transparent,
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Row(children: [
                          Icon(on ? Ic.done : Ic.forKind(it.kind), size: 17, color: on ? c.ink : c.inkMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(it.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(fontSize: 13.5, color: c.ink)),
                          ),
                          if (it.year != null) Text('${it.year}', style: context.text.labelSmall),
                        ]),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            if (_sources.length > 40)
              Expanded(child: Text('Pick 40 or fewer.', style: AppTheme.sans(fontSize: 12.5, color: c.danger)))
            else
              const Spacer(),
            AppButton.ghost(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            AppButton.primary(
              onPressed: _sources.isEmpty || _sources.length > 40 ? null : _create,
              icon: const Icon(Ic.pinda, size: 15),
              label: const Text('Draft with Pinda'),
            ),
          ]),
        ),
      ]),
    );
  }
}
