import 'dart:async';

import 'package:dscvr/models/library.dart';
import 'package:dscvr/models/workspace.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// A live group session: who's here, a shared timer, shared papers and chat.
class RoomPage extends StatefulWidget {
  const RoomPage({super.key, required this.roomId});
  final String roomId;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late final _svc = context.services.sessions;
  late final String _me = context.services.session.user.id;
  late final String _name = context.services.session.user.displayName;
  late final Stream<Room?> _room = _svc.watchRoom(widget.roomId);
  late final Stream<List<RoomMember>> _members = _svc.watchMembers(widget.roomId);
  late final Stream<List<RoomMessage>> _messages = _svc.watchMessages(widget.roomId);
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _heartbeat;
  Timer? _tick;
  final DateTime _joinedAt = DateTime.now();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _beat();
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) => _beat());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _beat() => _svc.heartbeat(widget.roomId, _name).catchError((_) {});

  @override
  void dispose() {
    _heartbeat?.cancel();
    _tick?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    _input.clear();
    await _svc.send(widget.roomId, name: _name, text: t);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
    });
  }

  Future<void> _share() async {
    final lib = context.library;
    final item = await showAdaptiveSheet<LibraryItem>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SheetHeader(title: 'Share a paper', subtitle: 'Everyone in the session sees its title and link.'),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 8, 12, 20), children: [
            for (final it in lib.recent.where((i) => i.kind != MaterialKind.note).take(40))
              ListTile(
                dense: true,
                leading: Icon(Ic.forKind(it.kind), size: 18),
                title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(it.authorLine, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(ctx, it),
              ),
          ]),
        ),
      ]),
    );
    if (item == null) return;
    await _svc.sharePaper(widget.roomId, item, sharedBy: _name);
    await _svc.send(widget.roomId, name: _name, text: 'Shared "${item.title}"');
  }

  /// Saves this session (and its chat) to the member's own history with a recap.
  Future<void> _saveToHistory(Room room, List<RoomMessage> messages) async {
    if (_saved) return;
    _saved = true;
    final s = context.services;
    final transcript = messages.map((m) => '${m.name}: ${m.text}').join('\n');
    final session = FocusSession(
      id: s.repo.newId(),
      title: room.title,
      notes: room.papers.map((p) => '- ${p.title}${p.url != null ? ' (${p.url})' : ''}').join('\n'),
      startedAt: _joinedAt,
      roomId: room.id,
    ).copyWith(endedAt: DateTime.now());
    await s.repo.saveSession(session);
    try {
      final summary = await s.sessions.summarize(
        title: room.title,
        duration: session.duration,
        notes: '${room.topic}\n${session.notes}',
        itemIds: const [],
        transcript: transcript,
      );
      await s.repo.saveSession(session.copyWith(summary: summary));
    } catch (_) {}
  }

  Future<void> _leave(Room room, List<RoomMessage> messages) async {
    final host = room.hostUid == _me;
    final ok = await confirm(
      context,
      title: host ? 'End this session for everyone?' : 'Leave this session?',
      message: 'A recap is saved to your session history.',
      action: host ? 'End session' : 'Leave',
    );
    if (!ok || !mounted) return;
    final router = GoRouter.of(context);
    unawaited(_saveToHistory(room, messages));
    if (host) {
      await _svc.endRoom(room.id);
    } else {
      await _svc.leaveRoom(room.id);
    }
    router.go('/sessions');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StreamBuilder<Room?>(
      stream: _room,
      builder: (context, roomSnap) {
        final room = roomSnap.data;
        if (room == null) {
          return Scaffold(
            backgroundColor: c.background,
            appBar: AppBar(leading: _back()),
            body: roomSnap.connectionState == ConnectionState.waiting
                ? const PageSpinner()
                : const EmptyState(icon: Ic.live, title: 'Session unavailable', message: "It ended, or you're not a member."),
          );
        }
        return StreamBuilder<List<RoomMessage>>(
          stream: _messages,
          builder: (context, msgSnap) {
            final messages = msgSnap.data ?? const <RoomMessage>[];
            final isHost = room.hostUid == _me;
            final focusLeft = room.focusUntil?.difference(DateTime.now());
            final focusing = focusLeft != null && !focusLeft.isNegative;

            final side = _SidePane(
              room: room,
              members: _members,
              isHost: isHost,
              focusLeft: focusing ? focusLeft : null,
              onShare: _share,
              onFocus: (m) => _svc.startFocus(room.id, m),
              onStopFocus: () => _svc.stopFocus(room.id),
            );
            final chat = _Chat(
              messages: messages,
              me: _me,
              input: _input,
              scroll: _scroll,
              onSend: _send,
              enabled: room.live,
            );

            return Scaffold(
              backgroundColor: c.background,
              appBar: AppBar(
                leading: _back(),
                titleSpacing: 0,
                title: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: room.live ? c.success : c.inkFaint, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Flexible(child: Text(room.title, overflow: TextOverflow.ellipsis, style: context.text.titleMedium)),
                ]),
                actions: [
                  if (room.live)
                    PillButton(
                      label: room.code,
                      icon: Ic.copy,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: room.code));
                        toast(context, 'Code copied', description: 'Send it to anyone you want to join.');
                      },
                    ),
                  const SizedBox(width: 8),
                  if (room.live)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: AppButton.secondary(
                        size: BtnSize.sm,
                        onPressed: () => _leave(room, messages),
                        child: Text(isHost ? 'End' : 'Leave'),
                      ),
                    ),
                ],
              ),
              body: context.isCompact
                  ? DefaultTabController(
                      length: 2,
                      child: Column(children: [
                        TabBar(tabs: const [Tab(text: 'Chat'), Tab(text: 'Room')], labelColor: c.ink, indicatorColor: c.ink, dividerColor: c.line),
                        Expanded(child: TabBarView(children: [chat, SingleChildScrollView(child: side)])),
                      ]),
                    )
                  : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: chat),
                      Container(
                        width: 340,
                        decoration: BoxDecoration(color: c.surface, border: Border(left: BorderSide(color: c.line))),
                        child: SingleChildScrollView(child: side),
                      ),
                    ]),
            );
          },
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

class _SidePane extends StatelessWidget {
  const _SidePane({
    required this.room,
    required this.members,
    required this.isHost,
    required this.focusLeft,
    required this.onShare,
    required this.onFocus,
    required this.onStopFocus,
  });

  final Room room;
  final Stream<List<RoomMember>> members;
  final bool isHost;
  final Duration? focusLeft;
  final VoidCallback onShare;
  final ValueChanged<int> onFocus;
  final VoidCallback onStopFocus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (room.topic.isNotEmpty) ...[
          Text('Topic', style: context.text.labelMedium),
          const SizedBox(height: 4),
          Text(room.topic, style: AppTheme.sans(fontSize: 14, color: c.ink, height: 1.45)),
          const SizedBox(height: 20),
        ],
        Text('Shared timer', style: context.text.labelMedium),
        const SizedBox(height: 8),
        if (focusLeft != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(Radii.lg)),
            child: Row(children: [
              Icon(Ic.timer, size: 18, color: c.inverseInk),
              const SizedBox(width: 10),
              Text(
                '${focusLeft!.inMinutes.toString().padLeft(2, '0')}:${(focusLeft!.inSeconds % 60).toString().padLeft(2, '0')}',
                style: AppTheme.serif(fontSize: 26, fontWeight: FontWeight.w600, color: c.inverseInk),
              ),
              const SizedBox(width: 8),
              Text('focus', style: AppTheme.sans(fontSize: 13, color: c.inverseInk.withValues(alpha: 0.7))),
              const Spacer(),
              if (isHost)
                AppButton.ghost(size: BtnSize.sm, onPressed: onStopFocus, child: Text('Stop', style: TextStyle(color: c.inverseInk))),
            ]),
          )
        else if (isHost)
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in const [15, 25, 50]) PillButton(label: '$m min', icon: Ic.timer, onTap: () => onFocus(m)),
          ])
        else
          Text('The host can start a timer for everyone.', style: context.text.bodySmall),
        const SizedBox(height: 22),
        StreamBuilder<List<RoomMember>>(
          stream: members,
          builder: (context, snap) {
            final list = snap.data ?? const <RoomMember>[];
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text('People', style: context.text.labelMedium),
                const SizedBox(width: 8),
                CountBadge(list.where((m) => m.online).length),
              ]),
              const SizedBox(height: 8),
              for (final m in list)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Stack(clipBehavior: Clip.none, children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: c.chip,
                        child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase(), style: AppTheme.sans(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink)),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(color: m.online ? c.success : c.inkFaint, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 1.5)),
                        ),
                      ),
                    ]),
                    const SizedBox(width: 10),
                    Expanded(child: Text(m.name, style: AppTheme.sans(fontSize: 13.5, color: c.ink))),
                    if (m.uid == room.hostUid) Text('Host', style: context.text.labelSmall),
                  ]),
                ),
            ]);
          },
        ),
        const SizedBox(height: 22),
        Row(children: [
          Text('Shared papers', style: context.text.labelMedium),
          const SizedBox(width: 8),
          CountBadge(room.papers.length),
          const Spacer(),
          if (room.live) AppButton.ghost(size: BtnSize.sm, onPressed: onShare, icon: const Icon(Ic.add, size: 14), label: const Text('Share')),
        ]),
        const SizedBox(height: 6),
        if (room.papers.isEmpty)
          Text('Share a paper from your library so everyone can open it.', style: context.text.bodySmall)
        else
          for (final p in room.papers)
            Pressable(
              scale: 0.99,
              onTap: p.url == null ? null : () => launchUrl(Uri.parse(p.url!), mode: LaunchMode.externalApplication),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.serif(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
                  const SizedBox(height: 2),
                  Text(
                    [if (p.year != null) '${p.year}', if (p.authors.isNotEmpty) p.authors.take(2).join(', '), 'shared by ${p.sharedBy}'].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall,
                  ),
                ]),
              ),
            ),
      ]),
    );
  }
}

class _Chat extends StatelessWidget {
  const _Chat({required this.messages, required this.me, required this.input, required this.scroll, required this.onSend, required this.enabled});
  final List<RoomMessage> messages;
  final String me;
  final TextEditingController input;
  final ScrollController scroll;
  final VoidCallback onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(children: [
      Expanded(
        child: messages.isEmpty
            ? const EmptyState(icon: Ic.chats, title: 'Say hello', message: 'Messages here are seen by everyone in the session.')
            : ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[i];
                  final mine = m.uid == me;
                  final showName = i == 0 || messages[i - 1].uid != m.uid;
                  return Padding(
                    padding: EdgeInsets.only(top: showName ? 10 : 2),
                    child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                      if (showName && !mine) Padding(padding: const EdgeInsets.only(bottom: 3, left: 4), child: Text(m.name, style: context.text.labelSmall)),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                          decoration: BoxDecoration(
                            color: mine ? c.ink : c.surfaceMuted,
                            borderRadius: BorderRadius.circular(Radii.lg),
                            border: mine ? null : Border.all(color: c.line),
                          ),
                          child: Text(m.text, style: AppTheme.sans(fontSize: 14, color: mine ? c.inverseInk : c.ink, height: 1.45)),
                        ),
                      ),
                    ]),
                  );
                },
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Row(children: [
          Expanded(
            child: AppField(
              controller: input,
              hint: enabled ? 'Message everyone' : 'This session has ended',
              textInputAction: TextInputAction.send,
              onSubmitted: enabled ? (_) => onSend() : null,
            ),
          ),
          const SizedBox(width: 8),
          AppIconButton(filled: true, size: 40, tooltip: 'Send', onPressed: enabled ? onSend : null, icon: const Icon(Ic.arrowUp, size: 17)),
        ]),
      ),
    ]);
  }
}
