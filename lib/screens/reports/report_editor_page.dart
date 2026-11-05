import 'dart:async';

import 'package:dscvr/config/env.dart';
import 'package:dscvr/data/api.dart';
import 'package:dscvr/models/workspace.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/download/download.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/markdown_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

enum _Mode { preview, edit }

/// Writes and edits one report. Pinda drafts it from the chosen sources;
/// the author edits the Markdown and exports it.
class ReportEditorPage extends StatefulWidget {
  const ReportEditorPage({super.key, required this.reportId, this.draftOnOpen = false});
  final String reportId;
  final bool draftOnOpen;

  @override
  State<ReportEditorPage> createState() => _ReportEditorPageState();
}

class _ReportEditorPageState extends State<ReportEditorPage> {
  Report? _report;
  final _title = TextEditingController();
  final _body = TextEditingController();
  _Mode _mode = _Mode.preview;
  StreamSubscription<String>? _draft;
  String? _error;
  Timer? _saveTimer;
  bool _dirty = false;

  bool get _drafting => _draft != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await context.services.repo.getReport(widget.reportId);
    if (!mounted) return;
    setState(() {
      _report = r;
      _title.text = r?.title ?? '';
      _body.text = r?.body ?? '';
      if (r != null && r.body.isEmpty) _mode = _Mode.preview;
    });
    if (r != null && widget.draftOnOpen && r.body.isEmpty) _startDraft();
  }

  @override
  void dispose() {
    _draft?.cancel();
    _saveTimer?.cancel();
    if (_dirty) _saveNow();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _changed() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _saveNow);
  }

  Future<void> _saveNow() async {
    final r = _report;
    if (r == null) return;
    _dirty = false;
    final updated = r.copyWith(title: _title.text.trim().isEmpty ? r.title : _title.text.trim(), body: _body.text);
    _report = updated;
    await context.services.repo.saveReport(updated).catchError((_) {});
  }

  Stream<String> _stream(Report r) {
    if (Env.demo) return _demoDraft(r);
    return context.services.api.stream('/reports/draft', {
      'kind': r.kind.wire,
      'title': _title.text.trim(),
      'instructions': r.instructions,
      'itemIds': r.sourceIds,
    });
  }

  Future<void> _startDraft() async {
    final r = _report;
    if (r == null || _drafting) return;
    if (_body.text.trim().isNotEmpty) {
      final ok = await confirm(context,
          title: 'Replace this draft?', message: 'Pinda will write a fresh draft. Your current text will be replaced.', action: 'Redraft');
      if (!ok || !mounted) return;
    }
    final buffer = StringBuffer();
    setState(() {
      _error = null;
      _mode = _Mode.preview;
      _body.text = '';
    });
    _draft = _stream(r).listen(
      (delta) {
        buffer.write(delta);
        _body.text = buffer.toString();
        setState(() {});
      },
      onError: (Object e) {
        setState(() {
          _draft = null;
          _error = e is ApiException ? e.message : 'Pinda could not finish the draft.';
        });
        _changed();
      },
      onDone: () {
        setState(() => _draft = null);
        _changed();
      },
      cancelOnError: true,
    );
    setState(() {});
  }

  void _stopDraft() {
    _draft?.cancel();
    setState(() => _draft = null);
    _changed();
  }

  String get _fileName {
    final safe = _title.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').replaceAll(' ', '-');
    return '${safe.isEmpty ? 'report' : safe}.md';
  }

  void _export(String how) {
    final text = _body.text;
    switch (how) {
      case 'download':
        downloadText(_fileName, text);
        toast(context, 'Downloaded $_fileName');
      case 'copy':
        Clipboard.setData(ClipboardData(text: text));
        toast(context, 'Report copied', description: 'Paste it into Google Docs, Word or Notion.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = _report;
    if (r == null) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(leading: _back()),
        body: const PageSpinner(),
      );
    }
    final lib = context.library;
    final sources = [for (final id in r.sourceIds) lib.item(id)].whereType<Object>().length;
    final pad = context.isCompact ? 16.0 : 40.0;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: _back(),
        titleSpacing: 0,
        title: Text(r.kind.label, style: AppTheme.sans(fontSize: 13.5, fontWeight: FontWeight.w500, color: c.inkMuted)),
        actions: [
          if (!context.isCompact)
            Segmented<_Mode>(
              options: const [(_Mode.preview, 'Preview', Ic.eye), (_Mode.edit, 'Edit', Ic.edit)],
              value: _mode,
              onChanged: _drafting ? (_) {} : (m) => setState(() => _mode = m),
            ),
          const SizedBox(width: 6),
          _drafting
              ? AppButton.secondary(onPressed: _stopDraft, size: BtnSize.sm, icon: const Icon(Ic.stop, size: 14), label: const Text('Stop'))
              : AppButton.secondary(
                  onPressed: _startDraft,
                  size: BtnSize.sm,
                  icon: const Icon(Ic.pinda, size: 14),
                  label: Text(_body.text.trim().isEmpty ? 'Draft' : 'Redraft'),
                ),
          MenuButton<String>(
            tooltip: 'Export',
            title: 'Export',
            onSelected: _export,
            entries: () => [
              if (canDownload) const MenuEntry(value: 'download', label: 'Download Markdown (.md)', icon: Ic.download),
              const MenuEntry(value: 'copy', label: 'Copy as Markdown', icon: Ic.copy),
            ],
            child: const IgnorePointer(child: AppIconButton(tooltip: 'Export', onPressed: null, icon: Icon(Ic.export, size: 19))),
          ),
          MenuButton<String>(
            tooltip: 'More',
            onSelected: (v) async {
              if (v == 'delete') {
                final ok = await confirm(context, title: 'Delete this report?', message: r.title);
                if (!ok || !context.mounted) return;
                _dirty = false;
                await context.services.repo.deleteReport(r.id);
                if (context.mounted) context.go('/reports');
              }
            },
            entries: () => const [MenuEntry(value: 'delete', label: 'Delete report', icon: Ic.trash, destructive: true)],
            child: const IgnorePointer(child: AppIconButton(tooltip: 'More', onPressed: null, icon: Icon(Ic.more, size: 20))),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 12, pad, 80),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _title,
                onChanged: (_) => _changed(),
                style: context.isCompact ? context.text.displaySmall : context.text.displayMedium,
                decoration: const InputDecoration(
                  hintText: 'Report title',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                PillButton(
                  label: '$sources source${sources == 1 ? '' : 's'}',
                  icon: Ic.library,
                  onTap: () => _showSources(r),
                ),
                if (r.instructions.isNotEmpty) PillButton(label: 'Instructions', icon: Ic.info, onTap: () => toast(context, r.instructions)),
                Text('${_wordCount()} words', style: context.text.labelSmall),
                if (_drafting)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Spinner(size: 13),
                    const SizedBox(width: 8),
                    Text('Pinda is writing...', style: context.text.labelSmall),
                  ]),
              ]),
              if (context.isCompact) ...[
                const SizedBox(height: 12),
                Segmented<_Mode>(
                  options: const [(_Mode.preview, 'Preview', Ic.eye), (_Mode.edit, 'Edit', Ic.edit)],
                  value: _mode,
                  expand: true,
                  onChanged: _drafting ? (_) {} : (m) => setState(() => _mode = m),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: c.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(Ic.warning, size: 16, color: c.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: AppTheme.sans(fontSize: 13, color: c.ink))),
                    AppButton.ghost(onPressed: _startDraft, icon: const Icon(Ic.retry, size: 14), label: const Text('Retry')),
                  ]),
                ),
              ],
              const SizedBox(height: 22),
              Divider(color: c.line, height: 1),
              const SizedBox(height: 22),
              if (_mode == _Mode.edit)
                TextField(
                  controller: _body,
                  onChanged: (_) {
                    _changed();
                    setState(() {});
                  },
                  maxLines: null,
                  minLines: 18,
                  style: AppTheme.mono(fontSize: 13.5, color: c.ink).copyWith(height: 1.6),
                  decoration: const InputDecoration(
                    hintText: '# Title\n\nWrite in Markdown...',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                )
              else if (_body.text.trim().isEmpty && !_drafting)
                EmptyState(
                  icon: Ic.report,
                  title: 'Empty draft',
                  message: 'Let Pinda write a first draft from your sources, or switch to Edit and start writing.',
                  action: AppButton.primary(onPressed: _startDraft, icon: const Icon(Ic.pinda, size: 15), label: const Text('Draft with Pinda')),
                )
              else
                SelectionArea(child: MarkdownView(_body.text, serifBody: true)),
            ]),
          ),
        ),
      ),
    );
  }

  int _wordCount() {
    final t = _body.text.trim();
    return t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
  }

  Widget _back() => AppIconButton(
        tooltip: 'Back',
        icon: const Icon(Ic.back, size: 20),
        onPressed: () => context.canPop() ? context.pop() : context.go('/reports'),
      );

  void _showSources(Report r) {
    final lib = context.library;
    showAdaptiveSheet<void>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SheetHeader(title: 'Sources', subtitle: 'Pinda only uses these for this report.'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(children: [
            for (final (i, id) in r.sourceIds.indexed)
              if (lib.item(id) case final it?)
                ListTile(
                  dense: true,
                  leading: Text('[${i + 1}]', style: ctx.text.labelMedium),
                  title: Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(it.authorLine, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/m/${it.id}');
                  },
                ),
          ]),
        ),
      ]),
    );
  }

  Stream<String> _demoDraft(Report r) async* {
    final lib = context.library;
    final titles = [for (final id in r.sourceIds) lib.item(id)?.title].whereType<String>().toList();
    final text = '''# ${_title.text.trim().isEmpty ? r.kind.label : _title.text.trim()}

## Overview

This preview draft was written from ${titles.length} source${titles.length == 1 ? '' : 's'} in your library [1]. In the live app, Pinda reads each source in full before writing.

## Key points

- The sources agree on the central claim, though they measure it differently [1].
- ${titles.length > 1 ? 'The second source adds evidence from a different setting [2].' : 'Add a second source to compare evidence.'}
- Neither reports results beyond the original benchmark.

## Gaps

More replication on independent data would strengthen the conclusion.

## Sources

${[for (final (i, t) in titles.indexed) '[${i + 1}] $t'].join('\n')}
''';
    for (final word in text.split(' ')) {
      await Future<void>.delayed(const Duration(milliseconds: 14));
      yield '$word ';
    }
  }
}
