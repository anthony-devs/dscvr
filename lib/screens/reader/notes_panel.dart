import 'package:dscvr/models/library.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';

/// Margin notes for a material: quick capture at the top, list below.
class NotesPanel extends StatefulWidget {
  const NotesPanel({super.key, required this.item});
  final LibraryItem item;

  @override
  State<NotesPanel> createState() => _NotesPanelState();
}

class _NotesPanelState extends State<NotesPanel> {
  late Stream<List<ItemNote>> _stream;
  final _input = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _stream = context.services.repo.watchNotes(widget.item.id);
  }

  @override
  void didUpdateWidget(covariant NotesPanel old) {
    super.didUpdateWidget(old);
    if (old.item.id != widget.item.id) _stream = context.services.repo.watchNotes(widget.item.id);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    await context.services.repo.addNote(widget.item.id, text: text);
    _input.clear();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Container(
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: c.line),
          ),
          padding: const EdgeInsets.fromLTRB(12, 2, 6, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            TextField(
              controller: _input,
              minLines: 2,
              maxLines: 6,
              style: AppTheme.sans(fontSize: 14, color: c.ink, height: 1.45),
              decoration: const InputDecoration(
                hintText: 'Write a note. Select text in the reader to quote it.',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            ListenableBuilder(
              listenable: _input,
              builder: (context, _) => AppButton.ghost(
                onPressed: _saving || _input.text.trim().isEmpty ? null : _add,
                child: const Text('Add note'),
              ),
            ),
          ]),
        ),
      ),
      Expanded(
        child: StreamBuilder<List<ItemNote>>(
          stream: _stream,
          builder: (context, snap) {
            final notes = snap.data ?? const <ItemNote>[];
            if (notes.isEmpty) {
              return const EmptyState(
                icon: Ic.notebook,
                title: 'No notes yet',
                message: 'Capture ideas as you read. Pinda can see your notes too.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              itemCount: notes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _NoteTile(item: widget.item, note: notes[i]),
            );
          },
        ),
      ),
    ]);
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.item, required this.note});
  final LibraryItem item;
  final ItemNote note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
      decoration: BoxDecoration(
        color: CardPalette.fill(item.colorIndex, c).withValues(alpha: c.isDark ? 1 : 0.5),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: CardPalette.border(item.colorIndex, c).withValues(alpha: 0.7)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (note.quote != null && note.quote!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(border: Border(left: BorderSide(color: c.inkFaint, width: 2))),
                child: Text(note.quote!,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.serif(fontSize: 14, fontStyle: FontStyle.italic, color: c.inkMuted, height: 1.45)),
              ),
              const SizedBox(height: 8),
            ],
            SelectableText(note.text, style: AppTheme.sans(fontSize: 14, color: c.ink, height: 1.5)),
            const SizedBox(height: 6),
            Text(relativeTime(note.createdAt), style: context.text.labelSmall),
          ]),
        ),
        AppIconButton(
          tooltip: 'Delete note',
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            final ok = await confirm(context, title: 'Delete note?', message: 'This note will be removed.');
            if (ok && context.mounted) await context.services.repo.deleteNote(item.id, note.id);
          },
          icon: Icon(Ic.trash, size: 15, color: c.inkFaint),
        ),
      ]),
    );
  }
}

/// Dialog for saving a quoted passage with an optional comment.
Future<bool> showNoteComposer(BuildContext context, {required LibraryItem item, String? quote}) async {
  final ctl = TextEditingController();
  final c = context.colors;
  final ok = await showAdaptiveSheet<bool>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SheetHeader(title: 'Add note'),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (quote != null)
            Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(border: Border(left: BorderSide(color: c.inkFaint, width: 2))),
              child: Text(quote.trim(),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.serif(fontSize: 15, fontStyle: FontStyle.italic, color: c.inkMuted)),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: ctl,
            autofocus: true,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(hintText: 'Your thoughts (optional)'),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(24),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          AppButton.ghost(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          const SizedBox(width: 8),
          AppButton.primary(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ]),
      ),
    ]),
  );
  if (ok == true && context.mounted) {
    await context.services.repo.addNote(item.id, text: ctl.text.trim().isEmpty ? 'Highlight' : ctl.text.trim(), quote: quote?.trim());
  }
  ctl.dispose();
  return ok == true;
}
