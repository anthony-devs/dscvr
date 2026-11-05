import 'dart:async';
import 'dart:math' as math;

import 'package:dscvr/data/api.dart';
import 'package:dscvr/models/workspace.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/screens/sessions/sessions_page.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/markdown_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A running (or finished) focus session.
class FocusPage extends StatefulWidget {
  const FocusPage({super.key, required this.sessionId});
  final String sessionId;

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  late final Stream<List<FocusSession>> _stream = context.services.repo.watchSessions();
  final _notes = TextEditingController();
  Timer? _tick;
  Timer? _save;
  bool _notesLoaded = false;
  bool _ending = false;
  bool _chimed = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _save?.cancel();
    _notes.dispose();
    super.dispose();
  }

  void _notesChanged(FocusSession s) {
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 800), () {
      context.services.repo.saveSession(s.copyWith(notes: _notes.text)).catchError((_) {});
    });
  }

  Future<void> _end(FocusSession s) async {
    final ok = await confirm(context, title: 'End this session?', message: 'Pinda will write a recap from your notes and sources.', action: 'End and recap', destructive: false);
    if (!ok || !mounted) return;
    setState(() => _ending = true);
    final services = context.services;
    final ended = s.copyWith(notes: _notes.text, endedAt: DateTime.now());
    await services.repo.saveSession(ended);
    try {
      final summary = await services.sessions.summarize(
        title: ended.title,
        duration: ended.duration,
        notes: ended.notes,
        itemIds: ended.itemIds,
      );
      await services.repo.saveSession(ended.copyWith(summary: summary));
    } on ApiException catch (e) {
      if (mounted) toast(context, 'Session saved without a recap', description: e.message);
    } finally {
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StreamBuilder<List<FocusSession>>(
      stream: _stream,
      builder: (context, snap) {
        final s = (snap.data ?? const <FocusSession>[]).where((x) => x.id == widget.sessionId).firstOrNull;
        if (s == null) {
          return Scaffold(
            backgroundColor: c.background,
            appBar: AppBar(leading: _back()),
            body: snap.hasData
                ? const EmptyState(icon: Ic.timer, title: 'Session not found', message: 'It may have been deleted.')
                : const PageSpinner(),
          );
        }
        if (!_notesLoaded) {
          _notesLoaded = true;
          _notes.text = s.notes;
        }
        final planned = Duration(minutes: s.plannedMinutes);
        final elapsed = s.duration;
        final remaining = planned - elapsed;
        final over = remaining.isNegative;
        if (over && s.active && !_chimed) {
          _chimed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) toast(context, 'Time is up', description: 'Wrap up and end the session for your recap.');
          });
        }
        final lib = context.library;
        final items = [for (final id in s.itemIds) lib.item(id)].nonNulls.toList();
        final pad = context.isCompact ? 16.0 : 40.0;
        final mm = (remaining.abs().inMinutes).toString().padLeft(2, '0');
        final ss = (remaining.abs().inSeconds % 60).toString().padLeft(2, '0');

        return Scaffold(
          backgroundColor: c.background,
          appBar: AppBar(
            leading: _back(),
            title: Text(s.active ? 'Focus session' : 'Session recap', style: AppTheme.sans(fontSize: 13.5, fontWeight: FontWeight.w500, color: c.inkMuted)),
            actions: [
              if (s.active)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: AppButton.primary(
                    size: BtnSize.sm,
                    onPressed: _ending ? null : () => _end(s),
                    icon: const Icon(Ic.stopCircle, size: 15),
                    label: const Text('End session'),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppIconButton(
                    tooltip: 'Delete',
                    onPressed: () async {
                      final ok = await confirm(context, title: 'Delete this session?', message: s.title);
                      if (!ok || !context.mounted) return;
                      await context.services.repo.deleteSession(s.id);
                      if (context.mounted) context.go('/sessions');
                    },
                    icon: const Icon(Ic.trash, size: 18),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, 8, pad, 80),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(s.title, style: context.isCompact ? context.text.displaySmall : context.text.displayMedium),
                  const SizedBox(height: 6),
                  Text(
                    s.active
                        ? 'Started ${relativeTime(s.startedAt)}  ·  ${s.plannedMinutes} minute block'
                        : '${formatDuration(s.duration)}  ·  ${relativeTime(s.startedAt)}',
                    style: context.text.labelSmall,
                  ),
                  const SizedBox(height: 26),
                  if (s.active)
                    Center(
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: CustomPaint(
                          painter: _RingPainter(
                            progress: (elapsed.inSeconds / math.max(planned.inSeconds, 1)).clamp(0.0, 1.0),
                            track: c.line,
                            fill: over ? c.danger : c.ink,
                          ),
                          child: Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Text('${over ? '+' : ''}$mm:$ss',
                                  style: AppTheme.serif(fontSize: 46, fontWeight: FontWeight.w600, color: over ? c.danger : c.ink)),
                              Text(over ? 'over time' : 'remaining', style: context.text.labelSmall),
                            ]),
                          ),
                        ),
                      ),
                    )
                  else if (_ending || s.summary.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.line)),
                      child: Row(children: [
                        if (_ending) const Spinner(size: 16) else Icon(Ic.info, size: 16, color: c.inkMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_ending ? 'Pinda is writing your recap...' : 'No recap for this session.',
                              style: AppTheme.sans(fontSize: 14, color: c.inkMuted)),
                        ),
                      ]),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.line)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Ic.pinda, size: 16, color: c.ink),
                          const SizedBox(width: 8),
                          Text('Recap', style: context.text.titleMedium),
                        ]),
                        const SizedBox(height: 10),
                        MarkdownView(s.summary),
                      ]),
                    ),
                  const SizedBox(height: 28),
                  if (items.isNotEmpty) ...[
                    SectionLabel('Sources', count: items.length),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final it in items) PillButton(label: it.title.length > 48 ? '${it.title.substring(0, 48)}...' : it.title, icon: Ic.forKind(it.kind), onTap: () => context.push('/m/${it.id}')),
                    ]),
                    const SizedBox(height: 24),
                  ],
                  const SectionLabel('Notes'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.line)),
                    child: TextField(
                      controller: _notes,
                      readOnly: !s.active,
                      onChanged: (_) => _notesChanged(s),
                      maxLines: null,
                      minLines: 8,
                      style: AppTheme.sans(fontSize: 14.5, color: c.ink, height: 1.6),
                      decoration: const InputDecoration(
                        hintText: 'Jot down ideas, questions and quotes as you go...',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _back() => AppIconButton(
        tooltip: 'Back',
        icon: const Icon(Ic.back, size: 20),
        onPressed: () => context.canPop() ? context.pop() : context.go('/sessions'),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.fill});
  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(6), 0, math.pi * 2, false, stroke..color = track);
    canvas.drawArc(rect.deflate(6), -math.pi / 2, math.pi * 2 * progress, false, stroke..color = fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.fill != fill || old.track != track;
}
