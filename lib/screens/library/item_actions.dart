import 'package:dscvr/models/library.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/state/library_controller.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/material_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

String collectionLabel(LibraryController lib, LibraryItem item) =>
    lib.topic(item.topicId)?.name ?? lib.category(item.categoryId)?.name ?? 'Library';

void openItem(BuildContext context, LibraryItem item) => context.push('/m/${item.id}');

/// A [MaterialCard] wired up to navigation and the item context menu.
class LibraryCard extends StatelessWidget {
  const LibraryCard({super.key, required this.item});
  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    final lib = context.library;
    return MaterialCard(
      item: item,
      collectionLabel: collectionLabel(lib, item),
      onTap: () => openItem(context, item),
      onMenu: (pos) => showItemMenu(context, item, pos),
    );
  }
}

Future<void> showItemMenu(BuildContext context, LibraryItem item, Offset position) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final c = context.colors;
  PopupMenuItem<String> entry(String value, IconData icon, String label, {Color? color}) => PopupMenuItem(
        value: value,
        height: 40,
        child: Row(children: [
          Icon(icon, size: 17, color: color ?? c.inkMuted),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color)),
        ]),
      );

  final choice = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & overlay.size),
    items: [
      entry('open', Ic.book, 'Open'),
      entry('reading', item.inReadingList ? Ic.readingListOn : Ic.readingList,
          item.inReadingList ? 'Remove from reading list' : 'Add to reading list'),
      entry('edit', Ic.edit, 'Edit details'),
      entry('move', Ic.folder, 'Move to...'),
      const PopupMenuDivider(),
      entry('delete', Ic.trash, 'Delete', color: c.danger),
    ],
  );
  if (choice == null || !context.mounted) return;
  await runItemAction(context, item, choice);
}

Future<void> runItemAction(BuildContext context, LibraryItem item, String action) async {
  final repo = context.services.repo;
  switch (action) {
    case 'open':
      openItem(context, item);
    case 'reading':
      await repo.setReadingList(item.id, !item.inReadingList);
      if (context.mounted) toast(context, item.inReadingList ? 'Removed from reading list' : 'Added to reading list');
    case 'edit':
      await showAdaptiveSheet(context, builder: (_) => ItemDetailsEditor(item: item));
    case 'move':
      await showAdaptiveSheet(context, builder: (_) => MoveItemSheet(item: item));
    case 'delete':
      final ok = await confirm(context,
          title: 'Delete this item?', message: '"${item.title}" and its notes will be removed from your library.');
      if (!ok) return;
      await repo.deleteItem(item);
      if (context.mounted) toast(context, 'Deleted');
  }
}

class MoveItemSheet extends StatefulWidget {
  const MoveItemSheet({super.key, required this.item});
  final LibraryItem item;

  @override
  State<MoveItemSheet> createState() => _MoveItemSheetState();
}

class _MoveItemSheetState extends State<MoveItemSheet> {
  late String? _cat = widget.item.categoryId;
  late String? _topic = widget.item.topicId;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetHeader(title: 'Move item', subtitle: widget.item.title),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: CollectionPicker(
          categoryId: _cat,
          topicId: _topic,
          onChanged: (c, t) => setState(() {
            _cat = c;
            _topic = t;
          }),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(24),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _cat == null
                ? null
                : () async {
                    final nav = Navigator.of(context);
                    await context.services.repo.saveItem(
                        widget.item.copyWith(categoryId: _cat, topicId: _topic, clearTopic: _topic == null));
                    nav.pop();
                  },
            child: const Text('Move'),
          ),
        ]),
      ),
    ]);
  }
}

class ItemDetailsEditor extends StatefulWidget {
  const ItemDetailsEditor({super.key, required this.item});
  final LibraryItem item;

  @override
  State<ItemDetailsEditor> createState() => _ItemDetailsEditorState();
}

class _ItemDetailsEditorState extends State<ItemDetailsEditor> {
  late final _title = TextEditingController(text: widget.item.title);
  late final _authors = TextEditingController(text: widget.item.authors.join(', '));
  late final _year = TextEditingController(text: widget.item.year?.toString() ?? '');
  late final _summary = TextEditingController(text: widget.item.summary);
  late int _color = widget.item.colorIndex;

  @override
  void dispose() {
    _title.dispose();
    _authors.dispose();
    _year.dispose();
    _summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SheetHeader(title: 'Edit details'),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title'), maxLines: 2, minLines: 1),
            const SizedBox(height: 12),
            TextField(controller: _authors, decoration: const InputDecoration(labelText: 'Authors', hintText: 'Separate names with commas')),
            const SizedBox(height: 12),
            TextField(controller: _year, decoration: const InputDecoration(labelText: 'Year'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextField(controller: _summary, decoration: const InputDecoration(labelText: 'Summary'), minLines: 2, maxLines: 5),
            const SizedBox(height: 16),
            Text('Card colour', style: context.text.labelMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < CardPalette.length; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _color = i),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: CardPalette.fill(i, c),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: i == _color ? c.ink : CardPalette.border(i, c), width: i == _color ? 2 : 1),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                await context.services.repo.saveItem(widget.item.copyWith(
                  title: _title.text.trim().isEmpty ? widget.item.title : _title.text.trim(),
                  authors: _authors.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                  year: int.tryParse(_year.text.trim()),
                  summary: _summary.text.trim(),
                  colorIndex: _color,
                ));
                nav.pop();
              },
              child: const Text('Save'),
            ),
          ]),
        ),
      ]),
    );
  }
}
