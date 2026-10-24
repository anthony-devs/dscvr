import 'package:dscvr/models/library.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shows content as a dialog on wide screens and a bottom sheet on phones.
Future<T?> showAdaptiveSheet<T>(BuildContext context, {required WidgetBuilder builder, double maxWidth = 520}) {
  if (context.isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: builder(ctx),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: builder(ctx)),
    ),
  );
}

Future<bool> confirm(BuildContext context,
    {required String title, required String message, String action = 'Delete', bool destructive = true}) async {
  final c = context.colors;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Text(message, style: context.text.bodyMedium?.copyWith(color: c.inkMuted)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: c.danger, foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Shared header for sheets and dialogs.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, context.isCompact ? 0 : 22, 12, 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.text.headlineSmall),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: context.text.bodySmall),
            ],
          ]),
        ),
        if (!context.isCompact)
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Ic.close, size: 18), tooltip: 'Close'),
      ]),
    );
  }
}

class ColorPicker extends StatelessWidget {
  const ColorPicker({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (var i = 0; i < CategoryPalette.colors.length; i++)
        Semantics(
          button: true,
          selected: i == value,
          label: 'Colour ${i + 1}',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onChanged(i),
            child: Container(
              width: 28,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: i == value ? c.ink : Colors.transparent, width: 2),
              ),
              child: Container(decoration: BoxDecoration(color: CategoryPalette.of(i), shape: BoxShape.circle)),
            ),
          ),
        ),
    ]);
  }
}

/// Create or edit a category (or a topic when [categoryId] is given).
class CollectionEditor extends StatefulWidget {
  const CollectionEditor({super.key, this.category, this.topic, this.parentCategoryId});

  final LibraryCategory? category;
  final Topic? topic;

  /// When set, the editor creates a topic inside this category.
  final String? parentCategoryId;

  bool get isTopic => topic != null || parentCategoryId != null;
  bool get isEdit => category != null || topic != null;

  @override
  State<CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends State<CollectionEditor> {
  late final _name = TextEditingController(text: widget.category?.name ?? widget.topic?.name ?? '');
  late final _desc = TextEditingController(text: widget.category?.description ?? widget.topic?.description ?? '');
  late int _color;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _color = widget.category?.colorIndex ?? widget.topic?.colorIndex ?? context.library.nextCategoryColor();
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final repo = context.services.repo;
    final router = GoRouter.of(context);
    final nav = Navigator.of(context);
    try {
      if (widget.category != null) {
        await repo.updateCategory(widget.category!.copyWith(name: name, description: _desc.text.trim(), colorIndex: _color));
        nav.pop();
      } else if (widget.topic != null) {
        await repo.updateTopic(widget.topic!.copyWith(name: name, description: _desc.text.trim(), colorIndex: _color));
        nav.pop();
      } else if (widget.parentCategoryId != null) {
        final t = await repo.createTopic(
            categoryId: widget.parentCategoryId!, name: name, description: _desc.text.trim(), colorIndex: _color);
        nav.pop();
        router.go('/c/${t.categoryId}/t/${t.id}');
      } else {
        final cat = await repo.createCategory(name: name, description: _desc.text.trim(), colorIndex: _color);
        nav.pop();
        router.go('/c/${cat.id}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        toast(context, 'Could not save: $e');
      }
    }
  }

  Future<void> _delete() async {
    final lib = context.library;
    final router = GoRouter.of(context);
    final nav = Navigator.of(context);
    if (widget.category != null) {
      final n = lib.countIn(widget.category!.id);
      final ok = await confirm(context,
          title: 'Delete ${widget.category!.name}?',
          message: n == 0
              ? 'This category and its topics will be removed.'
              : 'This removes the category, its topics and $n ${n == 1 ? 'item' : 'items'} inside it. This cannot be undone.');
      if (!ok) return;
      await lib.repo.deleteCategory(widget.category!.id);
      nav.pop();
      router.go('/recent');
    } else if (widget.topic != null) {
      final ok = await confirm(context,
          title: 'Delete ${widget.topic!.name}?',
          message: 'Items in this topic move up to the parent category.');
      if (!ok) return;
      await lib.repo.deleteTopic(widget.topic!.id);
      nav.pop();
      router.go('/c/${widget.topic!.categoryId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.isTopic ? 'topic' : 'category';
    final c = context.colors;
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader(
          title: widget.isEdit ? 'Edit $kind' : 'New $kind',
          subtitle: widget.isTopic
              ? 'Topics group related materials inside a category.'
              : 'Categories are the top shelves of your library.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Name', hintText: widget.isTopic ? 'Machine learning' : 'Computer Science'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description', hintText: 'What belongs here?'),
            ),
            const SizedBox(height: 18),
            Text('Colour', style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w500, color: c.inkMuted)),
            const SizedBox(height: 10),
            ColorPicker(value: _color, onChanged: (v) => setState(() => _color = v)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Row(children: [
            if (widget.isEdit)
              TextButton.icon(
                onPressed: _delete,
                icon: Icon(Ic.trash, size: 16, color: c.danger),
                label: Text('Delete', style: TextStyle(color: c.danger)),
              ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(widget.isEdit ? 'Save' : 'Create'),
            ),
          ]),
        ),
      ]),
    );
  }
}

Future<void> showCollectionEditor(BuildContext context,
        {LibraryCategory? category, Topic? topic, String? parentCategoryId}) =>
    showAdaptiveSheet(context,
        builder: (_) => CollectionEditor(category: category, topic: topic, parentCategoryId: parentCategoryId));

/// Pick a category and optional topic. Used by Move and Add Material.
class CollectionPicker extends StatelessWidget {
  const CollectionPicker({
    super.key,
    required this.categoryId,
    required this.topicId,
    required this.onChanged,
  });

  final String? categoryId;
  final String? topicId;
  final void Function(String? categoryId, String? topicId) onChanged;

  @override
  Widget build(BuildContext context) {
    final lib = context.library;
    final topics = categoryId == null ? <Topic>[] : lib.topicsOf(categoryId!);
    return Row(children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          initialValue: lib.category(categoryId) == null ? null : categoryId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            for (final cat in lib.categories)
              DropdownMenuItem(
                value: cat.id,
                child: Row(children: [
                  ColorDot(CategoryPalette.of(cat.colorIndex)),
                  const SizedBox(width: 8),
                  Flexible(child: Text(cat.name, overflow: TextOverflow.ellipsis)),
                ]),
              ),
          ],
          onChanged: (v) => onChanged(v, null),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: DropdownButtonFormField<String?>(
          key: ValueKey(categoryId),
          initialValue: topics.any((t) => t.id == topicId) ? topicId : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Topic'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('None')),
            for (final t in topics) DropdownMenuItem<String?>(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: topics.isEmpty ? null : (v) => onChanged(categoryId, v),
        ),
      ),
    ]);
  }
}
