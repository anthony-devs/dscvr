import 'dart:math';

import 'package:dscvr/data/link_service.dart';
import 'package:dscvr/models/library.dart';
import 'package:dscvr/models/paper.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum AddTab {
  link('Link', Ic.link),
  pdf('PDF', Ic.pdf),
  paper('Paper', Ic.paper),
  youtube('YouTube', Ic.video);

  const AddTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

Future<void> showAddMaterial(BuildContext context, {String? categoryId, String? topicId, AddTab initial = AddTab.link}) {
  return showAdaptiveSheet(
    context,
    maxWidth: 600,
    builder: (_) => AddMaterialSheet(categoryId: categoryId, topicId: topicId, initial: initial),
  );
}

/// Creates an empty note in the given (or first) category and opens it.
Future<void> createNote(BuildContext context, {String? categoryId, String? topicId}) async {
  final lib = context.library;
  final router = GoRouter.of(context);
  var catId = categoryId ?? (lib.categories.isNotEmpty ? lib.categories.first.id : null);
  catId ??= (await lib.repo.createCategory(name: 'Notes', colorIndex: lib.nextCategoryColor())).id;
  final now = DateTime.now();
  final item = LibraryItem(
    id: lib.repo.newId(),
    kind: MaterialKind.note,
    title: 'Untitled note',
    categoryId: catId,
    topicId: topicId,
    colorIndex: Random().nextInt(CardPalette.length),
    createdAt: now,
    updatedAt: now,
    lastOpenedAt: now,
  );
  await lib.repo.saveItem(item);
  router.push('/m/${item.id}');
}

class AddMaterialSheet extends StatefulWidget {
  const AddMaterialSheet({super.key, this.categoryId, this.topicId, this.initial = AddTab.link});
  final String? categoryId;
  final String? topicId;
  final AddTab initial;

  @override
  State<AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends State<AddMaterialSheet> {
  late AddTab _tab = widget.initial;
  late String? _categoryId;
  late String? _topicId = widget.topicId;
  final _newCategory = TextEditingController();

  final _url = TextEditingController();
  final _title = TextEditingController();
  final _query = TextEditingController();

  LinkPreview? _preview;
  PlatformFile? _file;
  List<Paper> _papers = const [];
  final Set<String> _added = {};
  bool _busy = false;
  String? _error;
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();
    final lib = context.library;
    _categoryId = widget.categoryId ?? (lib.categories.isNotEmpty ? lib.categories.first.id : null);
  }

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _query.dispose();
    _newCategory.dispose();
    super.dispose();
  }

  void _switch(AddTab t) => setState(() {
        _tab = t;
        _preview = null;
        _error = null;
        _title.clear();
        _url.clear();
      });

  Future<String?> _resolveCategory() async {
    if (_categoryId != null) return _categoryId;
    final name = _newCategory.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name a category for this material.');
      return null;
    }
    final lib = context.library;
    final cat = await lib.repo.createCategory(name: name, colorIndex: lib.nextCategoryColor());
    _categoryId = cat.id;
    return cat.id;
  }

  LibraryItem _draft({
    required MaterialKind kind,
    required String title,
    required String categoryId,
    String? url,
    String? pdfUrl,
    List<String> authors = const [],
    int? year,
    String summary = '',
    String content = '',
    String? siteName,
    String? thumbnailUrl,
    String? source,
    String? externalId,
    String? id,
  }) {
    final now = DateTime.now();
    return LibraryItem(
      id: id ?? context.library.repo.newId(),
      kind: kind,
      title: title,
      categoryId: categoryId,
      topicId: _topicId,
      url: url,
      pdfUrl: pdfUrl,
      authors: authors,
      year: year,
      summary: summary,
      content: content,
      siteName: siteName,
      thumbnailUrl: thumbnailUrl,
      source: source,
      externalId: externalId,
      colorIndex: Random().nextInt(CardPalette.length),
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── Link / YouTube ─────────────────────────────────────────────────────────

  Future<void> _fetchLink() async {
    final url = LinkService.normalize(_url.text);
    if (url == null) {
      setState(() => _error = 'Enter a valid web address.');
      return;
    }
    if (_tab == AddTab.youtube && LinkService.youtubeId(url) == null) {
      setState(() => _error = 'That does not look like a YouTube link.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await context.services.links.unfurl(url);
      if (!mounted) return;
      setState(() {
        _preview = p;
        _title.text = p.title ?? '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preview = LinkPreview(url: url, title: Uri.parse(url).host);
        _title.text = Uri.parse(url).host;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveLink() async {
    final p = _preview;
    if (p == null) return;
    setState(() => _busy = true);
    final cat = await _resolveCategory();
    if (cat == null || !mounted) return setState(() => _busy = false);
    final repo = context.library.repo;
    final title = _title.text.trim().isEmpty ? (p.title ?? p.url) : _title.text.trim();
    final ytId = LinkService.youtubeId(p.url);
    final LibraryItem item;
    if (ytId != null) {
      item = _draft(
        kind: MaterialKind.youtube,
        title: title,
        categoryId: cat,
        url: 'https://www.youtube.com/watch?v=$ytId',
        authors: p.authors.isNotEmpty ? p.authors : [if (p.siteName != null && p.siteName != 'YouTube') p.siteName!],
        year: p.year,
        summary: p.description ?? '',
        content: p.text,
        siteName: 'YouTube',
        thumbnailUrl: p.image ?? LinkService.youtubeThumb(ytId),
        externalId: ytId,
      );
    } else {
      item = _draft(
        kind: p.isPdf ? MaterialKind.pdf : MaterialKind.link,
        title: title,
        categoryId: cat,
        url: p.url,
        pdfUrl: p.isPdf ? p.url : null,
        authors: p.authors,
        year: p.year ?? DateTime.now().year,
        summary: p.description ?? '',
        content: p.text,
        siteName: p.siteName,
        thumbnailUrl: p.image,
      );
    }
    await repo.saveItem(item);
    if (!mounted) return;
    Navigator.pop(context);
    toast(context, 'Added to your library');
  }

  // ── PDF ────────────────────────────────────────────────────────────────────

  Future<void> _pickPdf() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) {
      setState(() => _error = 'Could not read that file.');
      return;
    }
    if (f.size > 50 * 1024 * 1024) {
      setState(() => _error = 'PDFs up to 50 MB are supported.');
      return;
    }
    setState(() {
      _file = f;
      _error = null;
      _title.text = f.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '').replaceAll(RegExp(r'[_-]+'), ' ');
    });
  }

  Future<void> _savePdf() async {
    final f = _file;
    if (f == null) return;
    setState(() {
      _busy = true;
      _uploadProgress = null;
      _error = null;
    });
    final cat = await _resolveCategory();
    if (cat == null || !mounted) return setState(() => _busy = false);
    final repo = context.library.repo;
    final id = repo.newId();
    try {
      final (path, url) = await repo.uploadPdf(itemId: id, fileName: f.name, bytes: f.bytes!);
      final draft = _draft(
        id: id,
        kind: MaterialKind.pdf,
        title: _title.text.trim().isEmpty ? f.name : _title.text.trim(),
        categoryId: cat,
        pdfUrl: url.isEmpty ? null : url,
        year: DateTime.now().year,
      );
      await repo.saveItem(LibraryItem.fromMap(id, {
        ...draft.toMap(),
        'storagePath': path,
        'fileName': f.name,
      }));
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, 'PDF uploaded');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Upload failed. Check that Firebase Storage is enabled. ($e)';
        });
      }
    }
  }

  // ── Paper search ───────────────────────────────────────────────────────────

  Future<void> _searchPapers() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await context.services.discover.search(q);
      if (mounted) setState(() => _papers = r);
    } catch (_) {
      if (mounted) setState(() => _error = 'Search failed. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPaper(Paper p) async {
    final cat = await _resolveCategory();
    if (cat == null || !mounted) return;
    await context.library.repo.saveItem(paperToItem(context, p, categoryId: cat, topicId: _topicId));
    if (mounted) setState(() => _added.add(p.id));
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lib = context.library;
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SheetHeader(title: 'Add to library', subtitle: 'Everything you add becomes context Pinda can read.'),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(children: [
            Expanded(
              child: Segmented<AddTab>(
                options: [for (final t in AddTab.values) (t, t.label, context.isCompact ? null : t.icon)],
                value: _tab,
                onChanged: _switch,
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: switch (_tab) {
            AddTab.link || AddTab.youtube => _linkBody(c),
            AddTab.pdf => _pdfBody(c),
            AddTab.paper => _paperBody(c),
          },
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(children: [
              Icon(Ic.warning, size: 16, color: c.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: AppTheme.sans(fontSize: 13, color: c.danger))),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: lib.categories.isEmpty
              ? TextField(
                  controller: _newCategory,
                  decoration: const InputDecoration(labelText: 'New category', hintText: 'e.g. Computer Science'),
                )
              : CollectionPicker(
                  categoryId: _categoryId,
                  topicId: _topicId,
                  onChanged: (cat, t) => setState(() {
                    _categoryId = cat;
                    _topicId = t;
                  }),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Row(children: [
            if (_busy && _uploadProgress == null && _tab == AddTab.pdf)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(_tab == AddTab.paper ? 'Done' : 'Cancel')),
            if (_tab != AddTab.paper) ...[
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy
                    ? null
                    : switch (_tab) {
                        AddTab.pdf => _file == null ? null : _savePdf,
                        _ => _preview == null ? _fetchLink : _saveLink,
                      },
                child: Text(switch (_tab) {
                  AddTab.pdf => 'Upload',
                  _ => _preview == null ? 'Fetch' : 'Save',
                }),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _linkBody(DscvrColors c) {
    final yt = _tab == AddTab.youtube;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _url,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: yt ? 'YouTube URL' : 'Web address',
          hintText: yt ? 'https://youtube.com/watch?v=...' : 'https://',
          prefixIcon: Icon(yt ? Ic.video : Ic.link, size: 18),
          suffixIcon: _busy ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
        ),
        onChanged: (_) {
          if (_preview != null) setState(() => _preview = null);
        },
        onSubmitted: (_) => _fetchLink(),
      ),
      if (_preview != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: c.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(_preview!.isPdf ? Ic.pdf : (yt ? Ic.video : Ic.globe), size: 15, color: c.inkMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_preview!.siteName ?? Uri.parse(_preview!.url).host,
                    style: context.text.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              style: AppTheme.serif(fontSize: 17, fontWeight: FontWeight.w600, color: c.ink),
              decoration: const InputDecoration(labelText: 'Title'),
              maxLines: 2,
              minLines: 1,
            ),
            if ((_preview!.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_preview!.description!, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
            ],
            if (_preview!.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Readable text extracted: ${(_preview!.text.length / 1000).toStringAsFixed(1)}k characters',
                  style: context.text.labelSmall),
            ],
          ]),
        ),
      ],
    ]);
  }

  Widget _pdfBody(DscvrColors c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: _busy ? null : _pickPdf,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: c.line, width: 1.2),
          ),
          child: Column(children: [
            Icon(_file == null ? Ic.upload : Ic.pdf, size: 26, color: c.inkMuted),
            const SizedBox(height: 10),
            Text(_file == null ? 'Choose a PDF' : _file!.name,
                textAlign: TextAlign.center, style: context.text.titleMedium),
            const SizedBox(height: 4),
            Text(_file == null ? 'Up to 50 MB' : '${(_file!.size / 1024 / 1024).toStringAsFixed(1)} MB  ·  tap to replace',
                style: context.text.bodySmall),
          ]),
        ),
      ),
      if (_file != null) ...[
        const SizedBox(height: 14),
        TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
      ],
      if (_busy) ...[
        const SizedBox(height: 14),
        const LinearProgressIndicator(minHeight: 3),
      ],
    ]);
  }

  Widget _paperBody(DscvrColors c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _query,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: 'Search arXiv',
          hintText: 'Title, author or topic',
          prefixIcon: const Icon(Ic.search, size: 18),
          suffixIcon: _busy
              ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(icon: const Icon(Ic.arrowRight, size: 18), onPressed: _searchPapers),
        ),
        onSubmitted: (_) => _searchPapers(),
      ),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 340),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _papers.length,
          separatorBuilder: (_, _) => Divider(color: c.line),
          itemBuilder: (context, i) {
            final p = _papers[i];
            final added = _added.contains(p.id);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.title, style: AppTheme.serif(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.ink)),
                    const SizedBox(height: 3),
                    Text([if (p.year != null) '${p.year}', p.authors.take(3).join(', ')].join('  ·  '),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                  ]),
                ),
                const SizedBox(width: 8),
                added
                    ? Padding(padding: const EdgeInsets.all(6), child: Icon(Ic.check, size: 18, color: c.success))
                    : PillButton(label: 'Add', icon: Ic.add, onTap: () => _addPaper(p)),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}

/// Converts a Discover search result into a library item.
LibraryItem paperToItem(BuildContext context, Paper p, {required String categoryId, String? topicId}) {
  final now = DateTime.now();
  return LibraryItem(
    id: context.library.repo.newId(),
    kind: MaterialKind.paper,
    title: p.title,
    categoryId: categoryId,
    topicId: topicId,
    authors: p.authors,
    year: p.year,
    summary: p.summary,
    url: p.url,
    pdfUrl: p.pdfUrl,
    siteName: p.sourceLabel,
    source: p.source,
    externalId: p.id,
    colorIndex: Random().nextInt(CardPalette.length),
    createdAt: now,
    updatedAt: now,
  );
}

/// Lets the user pick a destination for a Discover paper.
Future<void> savePaperFlow(BuildContext context, Paper p) async {
  final lib = context.library;
  String? cat = lib.categories.isNotEmpty ? lib.categories.first.id : null;
  String? topic;
  final newCat = TextEditingController();
  final saved = await showAdaptiveSheet<bool>(context, builder: (ctx) {
    return StatefulBuilder(builder: (ctx, setState) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader(title: 'Save to library', subtitle: p.title),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: lib.categories.isEmpty
              ? TextField(controller: newCat, autofocus: true, decoration: const InputDecoration(labelText: 'New category'))
              : CollectionPicker(
                  categoryId: cat,
                  topicId: topic,
                  onChanged: (c, t) => setState(() {
                    cat = c;
                    topic = t;
                  }),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ]),
        ),
      ]);
    });
  });
  if (saved != true || !context.mounted) return;
  if (cat == null) {
    final name = newCat.text.trim().isEmpty ? 'Papers' : newCat.text.trim();
    cat = (await lib.repo.createCategory(name: name, colorIndex: lib.nextCategoryColor())).id;
  }
  if (!context.mounted) return;
  await lib.repo.saveItem(paperToItem(context, p, categoryId: cat!, topicId: topic));
  if (context.mounted) toast(context, 'Saved to ${lib.category(cat)?.name ?? 'library'}');
}
