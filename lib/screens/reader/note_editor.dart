import 'dart:async';

import 'package:dscvr/data/library_repository.dart';
import 'package:dscvr/models/library.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/markdown_view.dart';
import 'package:flutter/material.dart';

/// Markdown note editor with live preview and autosave.
class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key, required this.item, required this.onAsk});
  final LibraryItem item;
  final ValueChanged<String> onAsk;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

enum _SaveState { saved, dirty, saving, failed }

class _NoteEditorState extends State<NoteEditor> {
  late final _title = TextEditingController(text: widget.item.title == 'Untitled note' ? '' : widget.item.title);
  late final _body = TextEditingController(text: widget.item.content);
  bool _preview = false;
  Timer? _debounce;
  _SaveState _state = _SaveState.saved;
  late final LibraryRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = context.services.repo;
    _preview = widget.item.content.trim().isNotEmpty;
    _title.addListener(_changed);
    _body.addListener(_changed);
  }

  @override
  void dispose() {
    if (_state == _SaveState.dirty) _save();
    _debounce?.cancel();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _changed() {
    final title = _title.text.trim().isEmpty ? 'Untitled note' : _title.text.trim();
    if (title == widget.item.title && _body.text == widget.item.content) return;
    if (_state != _SaveState.dirty) setState(() => _state = _SaveState.dirty);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _save);
  }

  Future<void> _save() async {
    final repo = _repo;
    final title = _title.text.trim().isEmpty ? 'Untitled note' : _title.text.trim();
    final plain = _body.text.replaceAll(RegExp(r'[#>*_`\[\]()-]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (mounted) setState(() => _state = _SaveState.saving);
    try {
      await repo.saveItem(widget.item.copyWith(
        title: title,
        content: _body.text,
        summary: plain.length > 220 ? '${plain.substring(0, 220)}...' : plain,
      ));
      if (mounted) setState(() => _state = _SaveState.saved);
    } catch (_) {
      if (mounted) setState(() => _state = _SaveState.failed);
    }
  }

  void _wrap(String left, [String? right]) {
    right ??= left;
    final sel = _body.selection;
    final text = _body.text;
    if (!sel.isValid) {
      _body.text = '$text$left$right';
      return;
    }
    final selected = sel.textInside(text);
    _body.value = TextEditingValue(
      text: sel.textBefore(text) + left + selected + right + sel.textAfter(text),
      selection: TextSelection(baseOffset: sel.start + left.length, extentOffset: sel.start + left.length + selected.length),
    );
  }

  void _linePrefix(String prefix) {
    final sel = _body.selection;
    final text = _body.text;
    final at = sel.isValid ? sel.start : text.length;
    final lineStart = text.lastIndexOf('\n', at > 0 ? at - 1 : 0) + 1;
    _body.value = TextEditingValue(
      text: text.substring(0, lineStart) + prefix + text.substring(lineStart),
      selection: TextSelection.collapsed(offset: at + prefix.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scale = Services.of(context).settings.readerScale;
    final pad = context.isCompact ? 20.0 : 48.0;
    final status = switch (_state) {
      _SaveState.saved => 'Saved',
      _SaveState.dirty => 'Editing',
      _SaveState.saving => 'Saving...',
      _SaveState.failed => 'Not saved',
    };

    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(pad - 8, 4, pad - 8, 4),
        child: Row(children: [
          Segmented<bool>(
            options: const [(false, 'Write', Ic.edit), (true, 'Preview', Ic.book)],
            value: _preview,
            onChanged: (v) => setState(() => _preview = v),
          ),
          const SizedBox(width: 10),
          if (!_preview && !context.isCompact) ...[
            _ToolButton(label: 'B', tooltip: 'Bold', onTap: () => _wrap('**')),
            _ToolButton(label: 'I', tooltip: 'Italic', italic: true, onTap: () => _wrap('*')),
            _ToolButton(label: 'H', tooltip: 'Heading', onTap: () => _linePrefix('## ')),
            _ToolButton(icon: Ic.list, tooltip: 'List', onTap: () => _linePrefix('- ')),
            _ToolButton(icon: Ic.quote, tooltip: 'Quote', onTap: () => _linePrefix('> ')),
          ],
          const Spacer(),
          Text(status, style: AppTheme.sans(fontSize: 12, color: _state == _SaveState.failed ? c.danger : c.inkFaint)),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Ask Pinda about this note',
            onPressed: () => widget.onAsk(_body.text.length > 600 ? _body.text.substring(0, 600) : _body.text),
            icon: const Icon(Ic.pinda, size: 18),
          ),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, 16, pad, 80),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _title,
                  style: AppTheme.serif(fontSize: (context.isCompact ? 28 : 36) * scale, fontWeight: FontWeight.w600, color: c.ink, height: 1.15),
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Untitled note',
                    hintStyle: AppTheme.serif(fontSize: (context.isCompact ? 28 : 36) * scale, fontWeight: FontWeight.w600, color: c.inkFaint),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 18),
                if (_preview)
                  _body.text.trim().isEmpty
                      ? Text('Nothing written yet.', style: context.text.bodySmall)
                      : SelectionArea(child: MarkdownView(_body.text, scale: scale, serifBody: true))
                else
                  TextField(
                    controller: _body,
                    autofocus: widget.item.content.isEmpty,
                    maxLines: null,
                    minLines: 12,
                    keyboardType: TextInputType.multiline,
                    style: AppTheme.serif(fontSize: 17.5 * scale, color: c.ink, height: 1.65),
                    decoration: InputDecoration(
                      hintText: 'Start writing. Markdown works: ## headings, **bold**, - lists, > quotes.',
                      hintStyle: AppTheme.serif(fontSize: 17 * scale, color: c.inkFaint),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({this.label, this.icon, required this.tooltip, required this.onTap, this.italic = false});
  final String? label;
  final IconData? icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: icon != null
                ? Icon(icon, size: 16, color: c.inkMuted)
                : Text(label!,
                    style: AppTheme.serif(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                        color: c.inkMuted)),
          ),
        ),
      ),
    );
  }
}
