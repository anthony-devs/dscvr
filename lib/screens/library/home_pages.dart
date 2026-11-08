import 'package:dscvr/screens/tour/page_tour.dart';
import 'package:dscvr/models/edition.dart';
import 'package:dscvr/models/library.dart';
import 'package:dscvr/screens/reports/reports_page.dart';
import 'package:dscvr/screens/sessions/sessions_page.dart';
import 'package:dscvr/screens/add/add_material_sheet.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/screens/library/item_actions.dart';
import 'package:dscvr/screens/library/shelf_page.dart';
import 'package:dscvr/state/library_controller.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/material_card.dart';
import 'package:dscvr/widgets/progress_ring.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 5) return 'Up late';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// Landing screen: greeting, continue reading, recently added.
class RecentPage extends StatelessWidget {
  const RecentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final lib = services.library!;
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) {
        final c = context.colors;
        if (!lib.loaded) return const SkeletonPage();
        final user = services.session.user;
        final inProgress = lib.inProgress.take(8).toList();
        final recent = lib.recent.take(context.isCompact ? 8 : 12).toList();

        return PageBody(children: [
          Text('${_greeting()}, ${user.firstName}',
              style: context.isCompact ? context.text.displaySmall : context.text.displayMedium),
          const SizedBox(height: 6),
          Text(
            '${DateFormat('EEEE, d MMMM').format(DateTime.now())}  ·  ${lib.items.length} items across ${lib.categories.length} categories',
            style: AppTheme.sans(fontSize: 14, color: c.inkMuted),
          ),
          const SizedBox(height: 22),
          TourTarget(id: 'recent.actions', child: _QuickActions(edition: user.edition)),
          if (user.edition == Edition.enterprise && !user.inOrg) ...[
            const SizedBox(height: 22),
            _TeamPrompt(),
          ],
          if (lib.items.isEmpty) ...[
            const SizedBox(height: 40),
            EmptyState(
              icon: Ic.library,
              title: 'Your library is empty',
              message: 'Start by adding a paper, a PDF, an article or a YouTube lecture, or find something new in Discover.',
              action: Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                AppButton.primary(
                  onPressed: () => showAddMaterial(context),
                  icon: const Icon(Ic.add, size: 16),
                  label: const Text('Add material'),
                ),
                AppButton.secondary(
                  onPressed: () => context.go('/discover'),
                  icon: const Icon(Ic.discover, size: 16),
                  label: const Text('Open Discover'),
                ),
              ]),
            ),
          ],
          if (inProgress.isNotEmpty) ...[
            const SizedBox(height: 30),
            const SectionLabel('Continue reading'),
            const SizedBox(height: 14),
            TourTarget(
              id: 'recent.continue',
              child: SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: inProgress.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _ContinueTile(item: inProgress[i]),
              ),
            )),
          ],
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 30),
            SectionLabel('Recently opened', trailing: PillButton(label: 'Library', onTap: () => context.go('/library'))),
            const SizedBox(height: 14),
            TourTarget(id: 'recent.recent', child: MaterialGrid(children: [for (final i in recent) LibraryCard(key: ValueKey(i.id), item: i)])),
          ],
        ]);
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.edition});
  final Edition edition;

  @override
  Widget build(BuildContext context) {
    final pinda = (Ic.pinda, 'Ask Pinda', () => context.go('/pinda'));
    final voice = (Ic.mic, 'Voice note', () => createNote(context, voice: true));
    final focus = (Ic.timer, 'Focus session', () => startFocusFlow(context));
    final report = (Ic.report, 'New report', () => showNewReport(context));
    final arxiv = (Ic.bookOpen, 'Add from arXiv', () => showAddMaterial(context, initial: AddTab.paper));
    final pdf = (Ic.upload, 'Upload PDF', () => showAddMaterial(context, initial: AddTab.pdf));
    final room = (Ic.users, 'Group session', () => createRoomFlow(context));
    final actions = switch (edition) {
      Edition.students => [focus, voice, pdf, room, pinda],
      Edition.researchers => [arxiv, report, voice, focus, pinda],
      Edition.enterprise => [report, room, arxiv, voice, pinda],
    };
    if (context.isCompact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final a in actions)
            Padding(padding: const EdgeInsets.only(right: 8), child: PillButton(label: a.$2, icon: a.$1, onTap: a.$3)),
        ]),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final a in actions) PillButton(label: a.$2, icon: a.$1, onTap: a.$3),
    ]);
  }
}

class _TeamPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.line),
      ),
      child: Row(children: [
        Icon(Ic.enterprise, size: 20, color: c.ink),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Set up your team', style: context.text.titleMedium),
            const SizedBox(height: 2),
            Text('Create an organisation or join one with an invite code.', style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted)),
          ]),
        ),
        const SizedBox(width: 12),
        AppButton.primary(size: BtnSize.sm, onPressed: () => context.go('/team'), child: const Text('Open Team')),
      ]),
    );
  }
}

class _ContinueTile extends StatelessWidget {
  const _ContinueTile({required this.item});
  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lib = context.library;
    final cat = lib.category(item.categoryId);
    return Pressable(
      onTap: () => openItem(context, item),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.line),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 56,
            decoration: BoxDecoration(
              color: CardPalette.fill(item.colorIndex, c),
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: CardPalette.border(item.colorIndex, c)),
            ),
            child: Icon(Ic.forKind(item.kind), size: 18, color: c.inkMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.serif(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.25, color: c.ink)),
              const SizedBox(height: 6),
              Row(children: [
                if (cat != null) ...[ColorDot(CategoryPalette.of(cat.colorIndex), size: 7), const SizedBox(width: 6)],
                Expanded(child: Text(cat?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall)),
                ProgressRing(value: item.progress, size: 13, color: c.ink, track: c.line),
                const SizedBox(width: 5),
                Text('${(item.progress * 100).round()}%', style: context.text.labelSmall),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class ReadingListPage extends StatelessWidget {
  const ReadingListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = Services.of(context).library!;
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) {
        final items = lib.readingList;
        return PageBody(children: [
          const PageTitle('Reading list'),
          const SizedBox(height: 10),
          Text('Things you have set aside to read next.', style: AppTheme.sans(fontSize: 14.5, color: context.colors.inkMuted)),
          const SizedBox(height: 24),
          if (items.isEmpty)
            const EmptyState(
              icon: Ic.readingList,
              title: 'Nothing queued',
              message: 'Right-click or long-press any card and choose "Add to reading list".',
            )
          else
            MaterialGrid(children: [for (final i in items) LibraryCard(key: ValueKey(i.id), item: i)]),
        ]);
      },
    );
  }
}

/// Overview of all categories. Primary library entry point on phones.
class LibraryIndexPage extends StatelessWidget {
  const LibraryIndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = Services.of(context).library!;
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) {
        final c = context.colors;
        return PageBody(children: [
          PageTitle('My library', leading: null, onEdit: null),
          const SizedBox(height: 10),
          Text('${lib.items.length} items in ${lib.categories.length} categories',
              style: AppTheme.sans(fontSize: 14.5, color: c.inkMuted)),
          const SizedBox(height: 18),
          TourTarget(id: 'library.actions', child: Wrap(spacing: 8, runSpacing: 8, children: [
            PillButton(label: 'New category', icon: Ic.folderPlus, onTap: () => showCollectionEditor(context)),
            PillButton(
              label: 'Reading list',
              icon: Ic.readingList,
              trailing: CountBadge(lib.readingList.length),
              onTap: () => context.go('/reading-list'),
            ),
          ])),
          const SizedBox(height: 24),
          if (lib.categories.isEmpty && lib.loaded)
            EmptyState(
              icon: Ic.folder,
              title: 'Create your first category',
              message: 'Categories are the top shelves of your library, like Economics or Machine Learning.',
              action: AppButton.primary(onPressed: () => showCollectionEditor(context), child: const Text('New category')),
            )
          else
            TourTarget(
              id: 'library.shelves',
              child: MaterialGrid(minTileWidth: 260, children: [
                for (final cat in lib.categories) _CategoryTile(cat: cat, lib: lib),
              ]),
            ),
        ]);
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.cat, required this.lib});
  final LibraryCategory cat;
  final LibraryController lib;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = lib.itemsIn(cat.id)..sort(ItemSort.recentlyAccessed.compare);
    final topics = lib.topicsOf(cat.id);
    final color = CategoryPalette.of(cat.colorIndex);
    return Pressable(
      onTap: () => context.go('/c/${cat.id}'),
      child: Container(
        height: 168,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ColorDot(color, size: 10),
            const SizedBox(width: 8),
            Expanded(child: Text(cat.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleLarge)),
            Text('${items.length}', style: AppTheme.sans(fontSize: 13, color: c.inkFaint)),
          ]),
          const SizedBox(height: 8),
          if (topics.isNotEmpty)
            Text(topics.map((t) => t.name).join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium),
          const Spacer(),
          for (final i in items.take(2))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(Ic.forKind(i.kind), size: 13, color: c.inkFaint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(i.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.serif(fontSize: 13.5, color: c.inkMuted)),
                ),
              ]),
            ),
          if (items.isEmpty) Text('Empty', style: context.text.bodySmall),
        ]),
      ),
    );
  }
}

/// Search across titles, authors, summaries and note text.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lib = Services.of(context).library!;
    final c = context.colors;
    return ListenableBuilder(
      listenable: Listenable.merge([lib, _q]),
      builder: (context, _) {
        final results = lib.search(_q.text);
        return PageBody(maxWidth: 820, children: [
          TextField(
            controller: _q,
            autofocus: true,
            style: AppTheme.serif(fontSize: 22, color: c.ink),
            decoration: InputDecoration(
              hintText: 'Search your library',
              hintStyle: AppTheme.serif(fontSize: 22, color: c.inkFaint),
              prefixIcon: const Padding(padding: EdgeInsets.only(left: 12, right: 8), child: Icon(Ic.search, size: 20)),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            ),
          ),
          const SizedBox(height: 20),
          if (_q.text.trim().isEmpty)
            Text('Search titles, authors, summaries and your notes.', style: context.text.bodySmall)
          else ...[
            Text('${results.length} ${results.length == 1 ? 'result' : 'results'}', style: context.text.labelMedium),
            const SizedBox(height: 8),
            for (final item in results.take(60)) _ResultRow(item: item, lib: lib),
            const SizedBox(height: 12),
            Pressable(
              onTap: () => context.go('/discover?q=${Uri.encodeComponent(_q.text.trim())}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(children: [
                  const Icon(Ic.discover, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Search papers for "${_q.text.trim()}" in Discover', style: context.text.bodyMedium)),
                  const Icon(Ic.arrowRight, size: 16),
                ]),
              ),
            ),
          ],
        ]);
      },
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.item, required this.lib});
  final LibraryItem item;
  final LibraryController lib;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cat = lib.category(item.categoryId);
    return Pressable(
      onTap: () => openItem(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: CardPalette.fill(item.colorIndex, c),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(Ic.forKind(item.kind), size: 16, color: c.inkMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: AppTheme.serif(fontSize: 15.5, fontWeight: FontWeight.w600, color: c.ink)),
              const SizedBox(height: 3),
              Text(
                [if (item.year != null) '${item.year}', if (item.authorLine.isNotEmpty) item.authorLine, if (cat != null) cat.name]
                    .join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
