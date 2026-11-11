import 'dart:math';

import 'package:dscvr/data/api.dart';
import 'package:dscvr/data/sharing_service.dart';
import 'package:dscvr/models/library.dart';
import 'package:dscvr/models/sharing.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/markdown_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// What someone sees when they open a share link (/s/:id): a read-only view
/// of the shared category or topic, with "Save a copy" when the link allows it.
class SharedPage extends StatefulWidget {
  const SharedPage({super.key, required this.linkId});
  final String linkId;

  @override
  State<SharedPage> createState() => _SharedPageState();
}

class _SharedPageState extends State<SharedPage> {
  late Future<SharedCollection> _future = _load();
  bool _saving = false;
  String? _savedCategoryId;

  Future<SharedCollection> _load() => openSharedLink(context.services.api, widget.linkId);

  void _home() => context.go('/recent');

  /// Copies the collection into the viewer's own library as a new category.
  Future<void> _saveCopy(SharedCollection shared) async {
    final lib = context.library;
    setState(() => _saving = true);
    try {
      final cat = await lib.repo.createCategory(
        name: shared.name,
        description: shared.description,
        colorIndex: lib.nextCategoryColor(),
      );
      final topicIds = <String, String>{};
      for (final (id, name) in shared.topics) {
        final t = await lib.repo.createTopic(categoryId: cat.id, name: name, colorIndex: Random().nextInt(CardPalette.length));
        topicIds[id] = t.id;
      }
      final copyable = shared.items.where((i) => !i.privateFile).toList();
      final now = DateTime.now();
      for (final i in copyable) {
        await lib.repo.saveItem(LibraryItem(
          id: lib.repo.newId(),
          kind: MaterialKind.parse(i.kind == 'pdf' ? 'paper' : i.kind),
          title: i.title,
          categoryId: cat.id,
          topicId: topicIds[i.topicId],
          authors: i.authors,
          year: i.year,
          url: i.url,
          pdfUrl: i.pdfUrl,
          summary: i.summary,
          content: i.content,
          thumbnailUrl: i.thumbnailUrl,
          siteName: i.siteName,
          source: i.source,
          externalId: i.externalId,
          colorIndex: Random().nextInt(CardPalette.length),
          createdAt: now,
          updatedAt: now,
        ));
      }
      if (!mounted) return;
      setState(() => _savedCategoryId = cat.id);
      final skipped = shared.items.length - copyable.length;
      toast(
        context,
        'Saved to your library',
        description: skipped > 0
            ? '$skipped uploaded file${skipped == 1 ? ' was' : 's were'} not copied. Ask ${shared.ownerName} for ${skipped == 1 ? 'it' : 'them'}.'
            : '${copyable.length} item${copyable.length == 1 ? '' : 's'} in "${shared.name}".',
      );
    } catch (e) {
      if (mounted) toast(context, "Couldn't save a copy. Try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _open(SharedItem item) {
    final url = item.openUrl;
    if (item.kind == 'note' || (url == null && item.content.isNotEmpty)) {
      showAdaptiveSheet<void>(
        context,
        maxWidth: 680,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SheetHeader(title: item.title),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: MarkdownView(item.content.isEmpty ? item.summary : item.content, serifBody: true),
              ),
            ),
          ]),
        ),
      );
    } else if (url != null) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: AppIconButton(tooltip: 'Go to your library', icon: const Icon(Ic.back, size: 20), onPressed: _home),
        titleSpacing: 0,
        title: Text('Shared with you', style: context.text.titleMedium),
      ),
      body: FutureBuilder<SharedCollection>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const PageSpinner();
          if (snap.hasError || !snap.hasData) {
            final e = snap.error;
            final gone = e is ApiException && (e.status == 404 || e.status == 403);
            return EmptyState(
              icon: gone ? Ic.lock : Ic.linkSimple,
              title: gone ? "This link can't be opened" : "Couldn't load this link",
              message: e is ApiException ? e.message : 'Check your connection and try again.',
              action: gone
                  ? AppButton.secondary(onPressed: _home, child: const Text('Go to your library'))
                  : AppButton.secondary(onPressed: () => setState(() => _future = _load()), child: const Text('Try again')),
            );
          }
          final shared = snap.data!;
          final topicNames = {for (final (id, name) in shared.topics) id: name};
          return ListView(
            padding: EdgeInsets.symmetric(horizontal: context.isCompact ? 16 : 32, vertical: 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      shared.mine
                          ? 'This is what people see when they open your link.'
                          : '${shared.ownerName} shared this ${shared.type} with you.',
                      style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted),
                    ),
                    const SizedBox(height: 8),
                    Text(shared.name, style: context.isCompact ? context.text.displaySmall : context.text.displayMedium),
                    if (shared.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(shared.description, style: AppTheme.sans(fontSize: 14.5, color: c.inkMuted, height: 1.5)),
                    ],
                    const SizedBox(height: 16),
                    Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text('${shared.items.length} item${shared.items.length == 1 ? '' : 's'}', style: context.text.labelMedium),
                      if (_savedCategoryId != null)
                        AppButton.secondary(
                          size: BtnSize.sm,
                          onPressed: () => context.go('/c/$_savedCategoryId'),
                          icon: const Icon(Ic.check, size: 14),
                          label: const Text('Open your copy'),
                        )
                      else if (shared.canFork && !shared.mine && shared.items.isNotEmpty)
                        AppButton.primary(
                          size: BtnSize.sm,
                          onPressed: _saving ? null : () => _saveCopy(shared),
                          loading: _saving,
                          icon: const Icon(Ic.gitFork, size: 14),
                          label: const Text('Save a copy to my library'),
                        ),
                    ]),
                    const SizedBox(height: 18),
                    if (shared.items.isEmpty)
                      const EmptyState(icon: Ic.folder, title: 'Nothing here yet', message: 'The owner has not added anything to this collection.')
                    else
                      for (final i in shared.items) _SharedRow(item: i, topic: topicNames[i.topicId], onOpen: () => _open(i)),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SharedRow extends StatelessWidget {
  const _SharedRow({required this.item, required this.onOpen, this.topic});
  final SharedItem item;
  final String? topic;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final kind = MaterialKind.parse(item.kind);
    final canOpen = item.openUrl != null || item.content.isNotEmpty;
    final meta = [
      kind.label,
      if (item.authors.isNotEmpty) item.authors.length > 3 ? '${item.authors.take(3).join(', ')} and others' : item.authors.join(', '),
      if (item.year != null) '${item.year}',
      if (item.siteName != null && item.siteName!.isNotEmpty) item.siteName!,
      ?topic,
    ].join('  ·  ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 12),
          child: Icon(Ic.forKind(kind), size: 18, color: c.inkMuted),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, style: AppTheme.sans(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink, height: 1.35)),
            const SizedBox(height: 4),
            Text(meta, style: context.text.labelSmall),
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.summary, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted, height: 1.5)),
            ],
            if (item.privateFile) ...[
              const SizedBox(height: 6),
              Text('A file the owner uploaded. Only they can open it.', style: AppTheme.sans(fontSize: 12.5, color: c.inkFaint)),
            ],
          ]),
        ),
        if (canOpen) ...[
          const SizedBox(width: 12),
          PillButton(label: item.kind == 'note' ? 'Read' : 'Open', icon: item.kind == 'note' ? Ic.book : Ic.linkSimple, onTap: onOpen),
        ],
      ]),
    );
  }
}
