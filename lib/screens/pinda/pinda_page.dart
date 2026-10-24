import 'package:dscvr/models/pinda.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/screens/pinda/pinda_chat.dart';
import 'package:dscvr/state/pinda_controller.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';

/// Full-page Pinda: conversation history on the left, chat on the right,
/// with a scope picker (whole library, a category or a topic).
class PindaPage extends StatefulWidget {
  const PindaPage({super.key, this.conversationId});
  final String? conversationId;

  @override
  State<PindaPage> createState() => _PindaPageState();
}

class _PindaPageState extends State<PindaPage> {
  late final PindaController _ctl;

  @override
  void initState() {
    super.initState();
    final s = context.services;
    _ctl = PindaController(
      repo: s.repo,
      service: s.pinda,
      context: const PindaContext.general(),
      styleOf: () => s.settings.pindaStyle,
      conversationId: widget.conversationId,
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  List<PindaContext> _scopes() {
    final lib = context.library;
    return [
      const PindaContext.general(),
      for (final cat in lib.categories) ...[
        PindaContext(scope: PindaScope.category, id: cat.id, label: cat.name),
        for (final t in lib.topicsOf(cat.id)) PindaContext(scope: PindaScope.topic, id: t.id, label: '${cat.name} / ${t.name}'),
      ],
    ];
  }

  Widget _scopePicker() {
    final c = context.colors;
    return ListenableBuilder(
      listenable: _ctl,
      builder: (context, _) => PopupMenuButton<PindaContext>(
        tooltip: 'What Pinda reads',
        onSelected: _ctl.setContext,
        itemBuilder: (_) => [
          for (final s in _scopes())
            PopupMenuItem(
              value: s,
              height: 38,
              child: Row(children: [
                SizedBox(width: 22, child: s == _ctl.context ? const Icon(Ic.check, size: 15) : null),
                Icon(s.scope == PindaScope.general ? Ic.library : (s.scope == PindaScope.topic ? Ic.folderOpen : Ic.folder),
                    size: 15, color: c.inkMuted),
                const SizedBox(width: 8),
                Flexible(child: Text(s.scope == PindaScope.general ? 'Whole library' : s.label, overflow: TextOverflow.ellipsis)),
              ]),
            ),
        ],
        child: IgnorePointer(
          child: PillButton(
            label: _ctl.context.scope == PindaScope.general ? 'Whole library' : _ctl.context.label,
            icon: Ic.folder,
            trailing: Icon(Ic.caretDown, size: 12, color: c.inkMuted),
            onTap: () {},
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.fromLTRB(context.isCompact ? 12 : 24, 4, context.isCompact ? 8 : 24, 8),
      child: Row(children: [
        _scopePicker(),
        const Spacer(),
        if (context.isCompact)
          IconButton(
            tooltip: 'History',
            onPressed: () => showModalBottomSheet(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              builder: (ctx) => SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.7,
                child: _History(controller: _ctl, onPicked: () => Navigator.pop(ctx)),
              ),
            ),
            icon: Icon(Ic.chats, size: 19, color: c.inkMuted),
          ),
        ListenableBuilder(
          listenable: _ctl,
          builder: (context, _) => _ctl.messages.isEmpty
              ? const SizedBox.shrink()
              : TextButton.icon(onPressed: _ctl.newConversation, icon: const Icon(Ic.add, size: 15), label: const Text('New chat')),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chat = PindaChat(controller: _ctl, compact: context.isCompact, header: _header());
    if (context.isCompact) return chat;
    return Row(children: [
      Container(
        width: 260,
        decoration: BoxDecoration(border: Border(right: BorderSide(color: c.line))),
        child: _History(controller: _ctl),
      ),
      Expanded(child: chat),
    ]);
  }
}

class _History extends StatelessWidget {
  const _History({required this.controller, this.onPicked});
  final PindaController controller;
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final repo = context.services.repo;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(children: [
          Text('Conversations', style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
          const Spacer(),
          IconButton(
            tooltip: 'New chat',
            onPressed: () {
              controller.newConversation();
              onPicked?.call();
            },
            icon: const Icon(Ic.add, size: 16),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<List<Conversation>>(
          stream: repo.watchConversations(),
          builder: (context, snap) {
            final list = snap.data ?? const <Conversation>[];
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Your conversations with Pinda will appear here.', style: context.text.bodySmall),
              );
            }
            return ListenableBuilder(
              listenable: controller,
              builder: (context, _) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final conv = list[i];
                  final active = conv.id == controller.conversationId;
                  return Material(
                    color: active ? c.selection : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.sm),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      onTap: () {
                        controller.openConversation(conv);
                        onPicked?.call();
                      },
                      onLongPress: () async {
                        final ok = await confirm(context, title: 'Delete conversation?', message: conv.title);
                        if (ok) {
                          if (conv.id == controller.conversationId) controller.newConversation();
                          await repo.deleteConversation(conv.id);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(conv.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.sans(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: c.ink)),
                          const SizedBox(height: 3),
                          Text(
                            '${conv.context.scope == PindaScope.general ? 'Library' : conv.context.label}  ·  ${relativeTime(conv.updatedAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelSmall,
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]);
  }
}
