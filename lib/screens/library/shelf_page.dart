import 'package:dscvr/models/library.dart';
import 'package:dscvr/screens/add/add_material_sheet.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/screens/library/item_actions.dart';
import 'package:dscvr/state/library_controller.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/material_card.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Scrollable, width-constrained page body shared by library screens.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 1240});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final pad = context.isCompact ? 16.0 : 32.0;
    return SingleChildScrollView(
      // Bottom padding includes the floating tab bar on phones.
      padding: EdgeInsets.fromLTRB(pad, context.isCompact ? 12 : 8, pad, 48 + MediaQuery.paddingOf(context).bottom),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ),
    );
  }
}

/// A category or topic page: title, description, author facets, tabs and
/// the material grid.
class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key, required this.categoryId, this.topicId});
  final String categoryId;
  final String? topicId;

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  int _tab = 0;
  final Set<String> _authors = {};
  ItemSort _sort = ItemSort.recentlyAccessed;
  bool _showAllAuthors = false;

  @override
  void didUpdateWidget(covariant ShelfPage old) {
    super.didUpdateWidget(old);
    if (old.categoryId != widget.categoryId || old.topicId != widget.topicId) {
      _tab = 0;
      _authors.clear();
      _showAllAuthors = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lib = Services.of(context).library!;
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) {
        final cat = lib.category(widget.categoryId);
        final topic = widget.topicId == null ? null : lib.topic(widget.topicId);
        if (!lib.loaded) return const SkeletonPage();
        if (cat == null || (widget.topicId != null && topic == null)) {
          return EmptyState(
            icon: Ic.folder,
            title: 'This collection no longer exists',
            action: AppButton.secondary(onPressed: () => context.go('/recent'), child: const Text('Back to Recent')),
          );
        }
        final all = lib.itemsIn(cat.id, topicId: topic?.id);
        final notes = all.where((i) => i.kind == MaterialKind.note).toList()..sort(ItemSort.recentlyAccessed.compare);
        final materials = all.where((i) => i.kind != MaterialKind.note).toList();
        final topics = topic == null ? lib.topicsOf(cat.id) : const <Topic>[];

        final tabs = <(IconData, String)>[
          (Ic.file, 'Items'),
          (Ic.notebook, 'Notebooks'),
          if (topic == null) (Ic.folder, 'Topics'),
        ];
        final tab = _tab.clamp(0, tabs.length - 1);

        return PageBody(children: [
          PageTitle(
            topic?.name ?? cat.name,
            onEdit: () => showCollectionEditor(context, category: topic == null ? cat : null, topic: topic),
          ),
          const SizedBox(height: 10),
          _Description(
            text: (topic?.description ?? cat.description),
            onAdd: () => showCollectionEditor(context, category: topic == null ? cat : null, topic: topic),
          ),
          if (topics.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in topics)
                PillButton(
                  label: t.name,
                  trailing: CountBadge(lib.countIn(cat.id, topicId: t.id)),
                  onTap: () => context.go('/c/${cat.id}/t/${t.id}'),
                ),
              PillButton(label: 'New topic', icon: Ic.add, onTap: () => showCollectionEditor(context, parentCategoryId: cat.id)),
            ]),
          ],
          const SizedBox(height: 26),
          FolderTabs(tabs: tabs, selected: tab, onSelect: (i) => setState(() => _tab = i)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(context.isCompact ? 14 : 20),
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: context.colors.isDark ? 0.5 : 0.55),
              border: Border.all(color: context.colors.line),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(Radii.lg),
                bottomLeft: Radius.circular(Radii.lg),
                bottomRight: Radius.circular(Radii.lg),
              ),
            ),
            child: switch (tab) {
              0 => _itemsTab(cat, topic, materials),
              1 => _notesTab(cat, topic, notes),
              _ => _topicsTab(lib, cat, topics),
            },
          ),
        ]);
      },
    );
  }

  Widget _itemsTab(LibraryCategory cat, Topic? topic, List<LibraryItem> materials) {
    final facets = LibraryController.authorFacets(materials);
    final filtered = (_authors.isEmpty
        ? materials
        : materials.where((i) => i.authors.any(_authors.contains)).toList())
      ..sort(_sort.compare);
    final shownFacets = _showAllAuthors ? facets : facets.take(context.isCompact ? 5 : 14).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (facets.isNotEmpty) ...[
        SectionLabel('Authors', trailing: _authors.isEmpty ? null : PillButton(label: 'Clear', onTap: () => setState(_authors.clear))),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (name, n) in shownFacets)
            AuthorChip(
              name: name,
              count: n,
              selected: _authors.contains(name),
              onTap: () => setState(() => _authors.contains(name) ? _authors.remove(name) : _authors.add(name)),
            ),
          if (facets.length > shownFacets.length || _showAllAuthors)
            PillButton(
              label: _showAllAuthors ? 'Show fewer' : '${facets.length - shownFacets.length} more',
              onTap: () => setState(() => _showAllAuthors = !_showAllAuthors),
            ),
        ]),
        const SizedBox(height: 22),
      ],
      SectionLabel(
        'Items',
        count: filtered.length,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          PillButton(
            label: 'Add',
            icon: Ic.add,
            onTap: () => showAddMaterial(context, categoryId: cat.id, topicId: topic?.id),
          ),
          const SizedBox(width: 8),
          _SortButton(value: _sort, onChanged: (s) => setState(() => _sort = s)),
        ]),
      ),
      const SizedBox(height: 14),
      if (filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: EmptyState(
            icon: Ic.file,
            title: 'Nothing here yet',
            message: 'Add a paper, PDF, article or video. Pinda can read anything you add here.',
            action: AppButton.primary(
              onPressed: () => showAddMaterial(context, categoryId: cat.id, topicId: topic?.id),
              icon: const Icon(Ic.add, size: 16),
              label: const Text('Add material'),
            ),
          ),
        )
      else
        MaterialGrid(children: [for (final i in filtered) LibraryCard(key: ValueKey(i.id), item: i)]),
    ]);
  }

  Widget _notesTab(LibraryCategory cat, Topic? topic, List<LibraryItem> notes) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel(
        'Notebooks',
        count: notes.length,
        trailing: PillButton(
          label: 'New note',
          icon: Ic.add,
          onTap: () => createNote(context, categoryId: cat.id, topicId: topic?.id),
        ),
      ),
      const SizedBox(height: 14),
      if (notes.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: EmptyState(
            icon: Ic.notebook,
            title: 'No notebooks yet',
            message: 'Write up what you are learning. Notes live alongside your sources and Pinda can read them too.',
          ),
        )
      else
        MaterialGrid(children: [for (final i in notes) LibraryCard(key: ValueKey(i.id), item: i)]),
    ]);
  }

  Widget _topicsTab(LibraryController lib, LibraryCategory cat, List<Topic> topics) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel('Topics',
          count: topics.length,
          trailing: PillButton(label: 'New topic', icon: Ic.add, onTap: () => showCollectionEditor(context, parentCategoryId: cat.id))),
      const SizedBox(height: 14),
      if (topics.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: EmptyState(icon: Ic.folder, title: 'No topics yet', message: 'Split this category into focused topics as it grows.'),
        )
      else
        MaterialGrid(minTileWidth: 220, children: [
          for (final t in topics)
            Pressable(
              onTap: () => context.go('/c/${cat.id}/t/${t.id}'),
              child: Container(
                height: 120,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(color: c.line),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    ColorDot(CategoryPalette.of(t.colorIndex)),
                    const Spacer(),
                    Text('${lib.countIn(cat.id, topicId: t.id)} items', style: context.text.labelSmall),
                  ]),
                  const Spacer(),
                  Text(t.name, style: context.text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
        ]),
    ]);
  }
}

class _Description extends StatelessWidget {
  const _Description({required this.text, required this.onAdd});
  final String text;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (text.trim().isEmpty) {
      return Pressable(
        onTap: onAdd,
        child: Text('Add a description', style: AppTheme.sans(fontSize: 14.5, color: c.inkFaint)),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Text(text, style: AppTheme.sans(fontSize: 14.5, height: 1.6, color: c.inkMuted)),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.value, required this.onChanged});
  final ItemSort value;
  final ValueChanged<ItemSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return MenuButton<ItemSort>(
      title: 'Sort by',
      width: 210,
      entries: () => [for (final s in ItemSort.values) MenuEntry(value: s, label: s.label, checked: s == value)],
      onSelected: onChanged,
      child: IgnorePointer(child: PillButton(label: value.label, icon: Ic.sort, onTap: () {})),
    );
  }
}
