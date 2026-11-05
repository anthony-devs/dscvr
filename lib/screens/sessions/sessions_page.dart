import 'package:dscvr/data/api.dart';
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

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '${h}h ${m}m';
  return '${d.inMinutes}m';
}

/// Focus sessions (solo, timed) and live sessions (group, real time).
class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  late final Stream<List<FocusSession>> _history = context.services.repo.watchSessions();
  late final Stream<List<Room>> _rooms = context.services.sessions.watchMyRooms();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final edition = context.services.session.user.edition;
    final noun = edition.sessionNoun;
    return PageBody(maxWidth: 1000, children: [
      const SizedBox(height: 18),
      const PageTitle('Sessions'),
      const SizedBox(height: 6),
      Text(
        edition == Edition.students
            ? 'Study in focused blocks, alone or with your group. Every session ends with a recap.'
            : 'Work in focused blocks, alone or live with collaborators. Every session ends with a recap.',
        style: AppTheme.sans(fontSize: 14.5, color: c.inkMuted, height: 1.5),
      ),
      const SizedBox(height: 24),
      LayoutBuilder(builder: (context, box) {
        final cards = [
          _ActionCard(
            icon: Ic.timer,
            title: 'Start a focus session',
            body: 'Pick what to read, set a timer, take notes. Pinda writes a recap when you finish.',
            cta: 'Start focusing',
            onTap: () => startFocusFlow(context),
          ),
          _ActionCard(
            icon: Ic.live,
            title: 'Start a live session',
            body: 'Invite people with a code. Share papers, chat and run a shared timer together.',
            cta: 'Go live',
            onTap: () => createRoomFlow(context),
          ),
          _ActionCard(
            icon: Ic.signIn,
            title: 'Join a live session',
            body: 'Got a 6-character code from someone? Join their $noun.',
            cta: 'Enter code',
            onTap: () => joinRoomFlow(context),
          ),
        ];
        if (box.maxWidth < 720) {
          return Column(children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)]);
        }
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, c) in cards.indexed) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: c)],
          ]),
        );
      }),
      const SizedBox(height: 30),
      StreamBuilder<List<Room>>(
        stream: _rooms,
        builder: (context, snap) {
          final live = (snap.data ?? const <Room>[]).where((r) => r.live).toList();
          if (live.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionLabel('Live now', count: live.length),
            const SizedBox(height: 8),
            for (final r in live)
              _Row(
                icon: Ic.live,
                title: r.title,
                subtitle: 'Hosted by ${r.hostName}  ·  ${r.memberUids.length} in the room  ·  code ${r.code}',
                accent: c.success,
                onTap: () => context.push('/rooms/${r.id}'),
              ),
            const SizedBox(height: 24),
          ]);
        },
      ),
      StreamBuilder<List<FocusSession>>(
        stream: _history,
        builder: (context, snap) {
          final list = snap.data ?? const <FocusSession>[];
          final active = list.where((s) => s.active).toList();
          final done = list.where((s) => !s.active).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (active.isNotEmpty) ...[
              const SectionLabel('In progress'),
              const SizedBox(height: 8),
              for (final s in active)
                _Row(
                  icon: Ic.timer,
                  title: s.title,
                  subtitle: 'Started ${relativeTime(s.startedAt)}  ·  ${s.itemIds.length} sources',
                  accent: c.success,
                  onTap: () => context.push('/sessions/${s.id}'),
                ),
              const SizedBox(height: 24),
            ],
            SectionLabel('History', count: done.length),
            const SizedBox(height: 8),
            if (done.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Finished sessions and their recaps will show up here.', style: context.text.bodySmall),
              )
            else
              for (final s in done)
                _Row(
                  icon: s.roomId != null ? Ic.team : Ic.check,
                  title: s.title,
                  subtitle: '${formatDuration(s.duration)}  ·  ${relativeTime(s.startedAt)}${s.summary.isNotEmpty ? '  ·  recap ready' : ''}',
                  onTap: () => context.push('/sessions/${s.id}'),
                ),
          ]);
        },
      ),
    ]);
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.body, required this.cta, required this.onTap});
  final IconData icon;
  final String title;
  final String body;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      scale: 0.985,
      onTap: onTap,
      builder: (context, hovered, pressed, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: hovered ? c.surface : c.surfaceMuted,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: hovered ? c.inkFaint : c.line),
        ),
        child: child,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(Radii.md)),
          child: Icon(icon, size: 19, color: c.inverseInk),
        ),
        const SizedBox(height: 14),
        Text(title, style: context.text.titleMedium),
        const SizedBox(height: 6),
        Text(body, style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted, height: 1.5)),
        const SizedBox(height: 14),
        Row(children: [
          Text(cta, style: AppTheme.sans(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.ink)),
          const SizedBox(width: 6),
          Icon(Ic.arrowRight, size: 15, color: c.ink),
        ]),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.subtitle, required this.onTap, this.accent});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      scale: 0.99,
      onTap: onTap,
      builder: (context, hovered, pressed, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hovered ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: hovered ? c.line : Colors.transparent),
        ),
        child: child,
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: accent ?? c.inkMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.ink)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall),
          ]),
        ),
        Icon(Ic.caretRight, size: 15, color: c.inkFaint),
      ]),
    );
  }
}

// ── Flows ────────────────────────────────────────────────────────────

/// Asks what to focus on, creates the session and opens it.
Future<void> startFocusFlow(BuildContext context, {List<String> itemIds = const []}) async {
  final services = context.services;
  final router = GoRouter.of(context);
  final result = await showAdaptiveSheet<(String, int, List<String>)>(
    context,
    maxWidth: 600,
    builder: (_) => _FocusSetup(initial: itemIds),
  );
  if (result == null) return;
  final (title, minutes, ids) = result;
  final session = FocusSession(
    id: services.repo.newId(),
    title: title,
    itemIds: ids,
    plannedMinutes: minutes,
    startedAt: DateTime.now(),
  );
  await services.repo.saveSession(session);
  router.push('/sessions/${session.id}');
}

class _FocusSetup extends StatefulWidget {
  const _FocusSetup({required this.initial});
  final List<String> initial;

  @override
  State<_FocusSetup> createState() => _FocusSetupState();
}

class _FocusSetupState extends State<_FocusSetup> {
  final _title = TextEditingController();
  int _minutes = 25;
  late final Set<String> _ids = {...widget.initial};

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lib = context.library;
    final items = lib.recent.take(30).toList();
    final noun = context.services.session.user.edition.sessionNoun;
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader(title: 'New focus session', subtitle: 'A timed $noun with a recap at the end.'),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: AppField(controller: _title, autofocus: true, label: 'What are you working on?', hint: 'e.g. Chapter 4 revision'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in const [25, 50, 90])
              AppChip(label: '$m min', selected: _minutes == m, onTap: () => setState(() => _minutes = m)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
          child: Text('Sources to work from (optional)', style: context.text.labelMedium),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final it in items)
                Pressable(
                  scale: 0.99,
                  onTap: () => setState(() => _ids.contains(it.id) ? _ids.remove(it.id) : _ids.add(it.id)),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                    decoration: BoxDecoration(
                      color: _ids.contains(it.id) ? c.selection : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: Row(children: [
                      Icon(_ids.contains(it.id) ? Ic.done : Ic.forKind(it.kind), size: 17, color: _ids.contains(it.id) ? c.ink : c.inkMuted),
                      const SizedBox(width: 10),
                      Expanded(child: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(fontSize: 13.5, color: c.ink))),
                    ]),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            AppButton.ghost(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            AppButton.primary(
              onPressed: () => Navigator.pop(context, (_title.text.trim().isEmpty ? 'Focus session' : _title.text.trim(), _minutes, _ids.toList())),
              icon: const Icon(Ic.timer, size: 15),
              label: Text('Start $_minutes min'),
            ),
          ]),
        ),
      ]),
    );
  }
}

Future<void> createRoomFlow(BuildContext context) async {
  final services = context.services;
  final router = GoRouter.of(context);
  final title = TextEditingController();
  final topic = TextEditingController();
  final ok = await showAdaptiveSheet<bool>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SheetHeader(title: 'Start a live session', subtitle: 'You get a code to share. Anyone with it can join.'),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: AppField(controller: title, autofocus: true, label: 'Session name', hint: 'e.g. Thursday reading group'),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
        child: AppField(controller: topic, label: 'Topic (optional)', hint: 'e.g. Efficient transformers'),
      ),
      Padding(
        padding: const EdgeInsets.all(24),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          AppButton.ghost(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          const SizedBox(width: 8),
          AppButton.primary(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Ic.live, size: 15), label: const Text('Go live')),
        ]),
      ),
    ]),
  );
  if (ok != true) return;
  try {
    final id = await services.sessions.createRoom(
      title: title.text.trim().isEmpty ? 'Live session' : title.text.trim(),
      topic: topic.text.trim(),
      hostName: services.session.user.displayName,
    );
    router.push('/rooms/$id');
  } catch (e) {
    if (context.mounted) toast(context, "Couldn't start the session", description: '$e');
  }
}

Future<void> joinRoomFlow(BuildContext context) async {
  final services = context.services;
  final router = GoRouter.of(context);
  final code = TextEditingController();
  final ok = await showAdaptiveSheet<bool>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SheetHeader(title: 'Join a live session', subtitle: 'Enter the 6-character code you were sent.'),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: AppField(
          controller: code,
          autofocus: true,
          label: 'Code',
          hint: 'e.g. K7Q2XP',
          textCapitalization: TextCapitalization.characters,
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(24),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          AppButton.ghost(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          const SizedBox(width: 8),
          AppButton.primary(onPressed: () => Navigator.pop(ctx, true), child: const Text('Join')),
        ]),
      ),
    ]),
  );
  if (ok != true) return;
  try {
    final id = await services.sessions.joinRoom(code.text.trim());
    router.push('/rooms/$id');
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message);
  }
}
