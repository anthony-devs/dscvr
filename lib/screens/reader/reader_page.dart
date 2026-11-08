import 'package:dscvr/screens/tour/page_tour.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:dscvr/data/link_service.dart';
import 'package:dscvr/models/library.dart';
import 'package:dscvr/models/pinda.dart';
import 'package:dscvr/models/workspace.dart';
import 'package:dscvr/screens/add/add_material_sheet.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/screens/library/item_actions.dart';
import 'package:dscvr/screens/reader/related_panel.dart';
import 'package:dscvr/screens/reader/study_panel.dart';
import 'package:dscvr/widgets/cite_sheet.dart';
import 'package:dscvr/widgets/pdf/dscvr_pdf_viewer.dart';
import 'package:dscvr/screens/pinda/pinda_chat.dart';
import 'package:dscvr/screens/reader/notes_panel.dart';
import 'package:dscvr/screens/reader/note_editor.dart';
import 'package:dscvr/screens/reader/parliament_panel.dart';
import 'package:dscvr/state/pinda_controller.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/embed/embed_view.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/markdown_view.dart';
import 'package:dscvr/widgets/progress_ring.dart';
import 'package:dscvr/widgets/star_rating.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

enum _Pane { read, notes, pinda, study, parliament, related }

/// Opens a single material: the content on the left, Pinda and margin
/// notes on the right (wide screens) or as tabs (phones).
class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.itemId, this.dictate = false, this.ask});
  final String itemId;

  /// A passage to ask Pinda about as soon as the item opens.
  final String? ask;

  /// Opens a note with dictation already running.
  final bool dictate;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  PindaController? _pinda;
  final _chatKey = GlobalKey<PindaChatState>();
  final _parliamentKey = GlobalKey<ParliamentPanelState>();
  _Pane _mobilePane = _Pane.read;
  _Pane _sidePane = _Pane.pinda;
  bool _sideOpen = true;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    final ask = widget.ask;
    if (ask != null && ask.trim().isNotEmpty) {
      // Wait for the item and Pinda to be built.
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _askAbout(ask);
      });
    }
  }

  @override
  void dispose() {
    _pinda?.dispose();
    super.dispose();
  }

  PindaController _pindaFor(LibraryItem item) {
    final s = context.services;
    return _pinda ??= PindaController(
      repo: s.repo,
      service: s.pinda,
      context: PindaContext(scope: PindaScope.material, id: item.id, label: item.title),
      styleOf: () => s.settings.pindaStyle,
      onReply: (reply, voice) {
        if (voice) s.voice.speak(reply.text);
      },
    );
  }

  Future<void> _rate(LibraryItem item, int stars) async {
    final s = context.services;
    await s.repo.setRating(item.id, stars);
    final key = item.paperKey;
    if (key != null && stars > 0) {
      s.research.rate(key, stars, item.title).catchError((_) => const PaperRating());
    }
  }

  Future<void> _savePdf(LibraryItem item) async {
    final s = context.services;
    toast(context, 'Saving PDF to your library...');
    final ok = await s.research.importPdf(s.repo, item);
    if (mounted) toast(context, ok ? 'PDF saved to your library' : "Couldn't save that PDF", description: ok ? 'It now opens offline and Pinda reads all of it.' : null);
  }

  void _markOpened(LibraryItem item) {
    if (_opened) return;
    _opened = true;
    context.services.repo.markOpened(item.id).catchError((_) {});
  }

  void _askAbout(String passage) {
    final quoted = '> ${passage.replaceAll('\n', ' ').trim()}\n\n';
    setState(() {
      _sideOpen = true;
      _sidePane = _Pane.pinda;
      _mobilePane = _Pane.pinda;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatKey.currentState?.prefill('${quoted}Explain this passage.');
    });
  }

  Future<void> _noteFrom(String passage) async {
    final item = context.library.item(widget.itemId);
    if (item == null) return;
    final saved = await showNoteComposer(context, item: item, quote: passage);
    if (saved && mounted) toast(context, 'Note added', description: 'Find it in the Notes panel.');
  }

  void _factCheck(String passage) {
    setState(() {
      _sideOpen = true;
      _sidePane = _Pane.parliament;
      _mobilePane = _Pane.parliament;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _parliamentKey.currentState?.prefill(passage.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final maybeLib = Services.of(context).library;
    if (maybeLib == null) return Scaffold(backgroundColor: context.colors.background);
    final lib = maybeLib;
    return PageTourGate(pageKey: 'reader', child: ListenableBuilder(
      listenable: lib,
      builder: (context, _) {
        final item = lib.item(widget.itemId);
        final c = context.colors;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(leading: _backButton(context)),
            body: lib.loaded
                ? EmptyState(
                    icon: Ic.file,
                    title: 'This item is not in your library',
                    message: 'It may have been deleted.',
                    action: AppButton.secondary(onPressed: () => context.go('/recent'), child: const Text('Back to library')),
                  )
                : const PageSpinner(),
          );
        }
        _markOpened(item);
        final pinda = _pindaFor(item);
        final content = _ReaderContent(item: item, onAsk: _askAbout, onNote: _noteFrom, onFactCheck: _factCheck, dictate: widget.dictate);

        final parliamentPanel = ParliamentPanel(
          key: _parliamentKey,
          materialContext: item.summary.isNotEmpty ? item.summary : null,
        );
        final side = _SidePanel(
          item: item,
          pane: _sidePane,
          onPane: (p) => setState(() => _sidePane = p),
          chat: PindaChat(key: _chatKey, controller: pinda, compact: true),
          parliament: parliamentPanel,
        );

        if (context.isCompact) {
          return Scaffold(
            backgroundColor: c.background,
            appBar: _appBar(context, item, showSideToggle: false),
            extendBody: true,
            body: SafeArea(
              top: false,
              child: IndexedStack(
                index: _mobilePane.index,
                children: [
                  content,
                  NotesPanel(item: item),
                  PindaChat(key: _chatKey, controller: pinda, compact: true),
                  StudyPanel(item: item),
                  parliamentPanel,
                ],
              ),
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom > 0 ? MediaQuery.paddingOf(context).bottom : 12),
              child: ClipRSuperellipse(
                borderRadius: BorderRadius.circular(Radii.md + 4),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: TourTarget(id: 'reader.tabs', child: Segmented<_Pane>(
                    options: const [
                      (_Pane.read, 'Read', Ic.book),
                      (_Pane.notes, 'Notes', Ic.notebook),
                      (_Pane.pinda, 'Pinda', Ic.pinda),
                      (_Pane.study, 'Study', Ic.exam),
                      (_Pane.parliament, 'Check', Ic.scale),
                    ],
                    value: _mobilePane,
                    expand: true,
                    onChanged: (p) => setState(() => _mobilePane = p),
                  )),
                ),
              ),
            ),
          );
        }

        final sideWidth = context.isWide ? 420.0 : 360.0;
        return Scaffold(
          backgroundColor: c.background,
          appBar: _appBar(context, item, showSideToggle: true),
          body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: content),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: _sideOpen ? sideWidth : 0,
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(left: BorderSide(color: c.line)),
              ),
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: sideWidth,
                  maxWidth: sideWidth,
                  child: side,
                ),
              ),
            ),
          ]),
        );
      },
    ));
  }

  Widget _backButton(BuildContext context) => AppIconButton(
        tooltip: 'Back',
        icon: const Icon(Ic.back, size: 20),
        onPressed: () => context.canPop() ? context.pop() : context.go('/recent'),
      );

  PreferredSizeWidget _appBar(BuildContext context, LibraryItem item, {required bool showSideToggle}) {
    final lib = context.library;
    final cat = lib.category(item.categoryId);
    final topic = lib.topic(item.topicId);
    final c = context.colors;
    final external = item.kind == MaterialKind.note ? null : (item.url ?? item.pdfUrl);
    return AppBar(
      leading: _backButton(context),
      titleSpacing: 0,
      title: GestureDetector(
        onTap: cat == null ? null : () => context.go(topic == null ? '/c/${cat.id}' : '/c/${cat.id}/t/${topic.id}'),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (cat != null) ...[ColorDot(CategoryPalette.of(cat.colorIndex), size: 8), const SizedBox(width: 8)],
          Flexible(
            child: Text(
              [if (cat != null) cat.name, if (topic != null) topic.name].join('  /  '),
              overflow: TextOverflow.ellipsis,
              style: AppTheme.sans(fontSize: 13.5, fontWeight: FontWeight.w500, color: c.inkMuted),
            ),
          ),
        ]),
      ),
      actions: [
        if (!context.isCompact)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: StarRating(value: item.rating, size: 17, onChanged: (v) => _rate(item, v)),
          )
        else
          AppIconButton(
            tooltip: item.rating > 0 ? 'Rated ${item.rating} of 5' : 'Rate',
            onPressed: () => showAdaptiveSheet<void>(
              context,
              builder: (ctx) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SheetHeader(title: 'Rate this'),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (ctx, set) => StarRating(
                      value: context.library.item(item.id)?.rating ?? 0,
                      size: 34,
                      spacing: 8,
                      onChanged: (v) async {
                        await _rate(item, v);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ),
                ]),
              ),
            ),
            icon: Icon(item.rating > 0 ? Ic.starFill : Ic.star, size: 19, color: item.rating > 0 ? const Color(0xFFE0A526) : null),
          ),
        if (item.hasPdf && !item.pdfInLibrary && item.kind != MaterialKind.note)
          AppIconButton(
            tooltip: 'Save PDF to your library',
            onPressed: () => _savePdf(item),
            icon: const Icon(Ic.download, size: 19),
          ),
        if (item.kind != MaterialKind.note) _ProgressButton(item: item),
        AppIconButton(
          tooltip: item.inReadingList ? 'Remove from reading list' : 'Add to reading list',
          onPressed: () => context.services.repo.setReadingList(item.id, !item.inReadingList),
          icon: Icon(item.inReadingList ? Ic.readingListOn : Ic.readingList, size: 19),
        ),
        if (external != null)
          AppIconButton(
            tooltip: 'Open original',
            onPressed: () => launchUrl(Uri.parse(external), mode: LaunchMode.externalApplication),
            icon: const Icon(Ic.external, size: 19),
          ),
        if (item.kind != MaterialKind.youtube) TourTarget(id: 'reader.listen', child: _ListenButton(item: item)),
        TourTarget(
          id: 'reader.cite',
          child: AppIconButton(
            tooltip: 'Cite',
            onPressed: () => showCiteSheet(context, CiteSource.fromItem(item)),
            icon: const Icon(Ic.quote, size: 19),
          ),
        ),
        const PageTourButton(pageKey: 'reader', size: 34),
        Builder(
          builder: (ctx) => AppIconButton(
            tooltip: 'More',
            onPressed: () {
              final box = ctx.findRenderObject() as RenderBox;
              showItemMenu(ctx, item, box.localToGlobal(Offset(0, box.size.height)));
            },
            icon: const Icon(Ic.more, size: 20),
          ),
        ),
        if (showSideToggle)
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: _sideOpen
                ? AppIconButton(
                    tooltip: 'Hide panel',
                    onPressed: () => setState(() => _sideOpen = false),
                    icon: const Icon(Ic.sidebar, size: 19),
                  )
                : AppButton.primary(
                    onPressed: () => setState(() => _sideOpen = true),
                    size: BtnSize.sm,
                    icon: const Icon(Ic.pinda, size: 15),
                    label: const Text('Ask Pinda'),
                  ),
          )
        else
          const SizedBox(width: 6),
      ],
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.item, required this.pane, required this.onPane, required this.chat, required this.parliament});
  final LibraryItem item;
  final _Pane pane;
  final ValueChanged<_Pane> onPane;
  final Widget chat;
  final Widget parliament;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final related = item.kind == MaterialKind.paper || item.kind == MaterialKind.pdf;
    final activePaneIndex = switch (pane) {
      _Pane.notes => 1,
      _Pane.study => 2,
      _Pane.parliament => 3,
      _Pane.related => related ? 4 : 0,
      _ => 0,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Row(children: [
          Expanded(
            child: TourTarget(id: 'reader.tabs', child: Segmented<_Pane>(
              // Five tabs fit the panel as text; icons would push the last one off.
              expand: true,
              options: [
                (_Pane.pinda, 'Pinda', null),
                (_Pane.notes, item.noteCount > 0 ? 'Notes ${item.noteCount}' : 'Notes', null),
                (_Pane.study, 'Study', null),
                (_Pane.parliament, 'Check', null),
                if (related) (_Pane.related, 'Related', null),
              ],
              value: pane == _Pane.read || (pane == _Pane.related && !related) ? _Pane.pinda : pane,
              onChanged: onPane,
            )),
          ),
        ]),
      ),
      Divider(color: c.line, height: 1),
      Expanded(
        child: IndexedStack(
          index: activePaneIndex,
          children: [chat, NotesPanel(item: item), StudyPanel(item: item), parliament, if (related) RelatedPanel(item: item)],
        ),
      ),
    ]);
  }
}

/// Reads the item aloud (its text, or its abstract for PDFs), at the speed
/// set in Settings > Accessibility.
class _ListenButton extends StatelessWidget {
  const _ListenButton({required this.item});
  final LibraryItem item;

  String get _text {
    final body = item.content.trim().isNotEmpty ? item.content : item.summary;
    return '${item.title}. ${item.authors.isNotEmpty ? 'By ${item.authors.take(3).join(', ')}. ' : ''}$body';
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.services.voice;
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) {
        final on = voice.reading;
        final hasText = item.content.trim().isNotEmpty || item.summary.trim().isNotEmpty;
        return AppIconButton(
          tooltip: on ? 'Stop reading aloud' : (hasText ? 'Listen' : 'Nothing to read aloud yet'),
          onPressed: !hasText && !on
              ? null
              : () => on ? voice.stopReading() : voice.readAloud(_text, rate: context.services.settings.speechRate),
          icon: Icon(on ? Ic.stopCircle : Ic.headphones, size: 19),
        );
      },
    );
  }
}

class _ProgressButton extends StatelessWidget {
  const _ProgressButton({required this.item});
  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const steps = [(0.0, 'Not started'), (0.25, 'A quarter'), (0.5, 'Halfway'), (0.75, 'Nearly done'), (1.0, 'Finished')];
    return MenuButton<double>(
      tooltip: 'Reading progress',
      title: 'Reading progress',
      width: 200,
      onSelected: (v) {
        context.services.repo.setProgress(item.id, v);
        if (v >= 1) toast(context, 'Marked as finished', kind: ToastKind.success);
      },
      entries: () => [
        for (final s in steps)
          MenuEntry(
            value: s.$1,
            label: s.$2,
            checked: (item.progress - s.$1).abs() < 0.13,
            leading: ProgressRing(value: s.$1, size: 15, color: c.ink, track: c.line),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(children: [
          ProgressRing(value: item.progress, size: 16, color: c.ink, track: c.line),
          const SizedBox(width: 6),
          Text(item.progress >= 1 ? 'Done' : '${(item.progress * 100).round()}%', style: context.text.labelMedium),
        ]),
      ),
    );
  }
}

/// Chooses the right view for the material's kind.
class _ReaderContent extends StatelessWidget {
  const _ReaderContent({required this.item, required this.onAsk, required this.onNote, required this.onFactCheck, this.dictate = false});
  final LibraryItem item;
  final bool dictate;
  final ValueChanged<String> onAsk;
  final ValueChanged<String> onNote;
  final ValueChanged<String> onFactCheck;

  @override
  Widget build(BuildContext context) {
    switch (item.kind) {
      case MaterialKind.note:
        return NoteEditor(item: item, onAsk: onAsk, dictateOnOpen: dictate);
      case MaterialKind.youtube:
        return _VideoView(item: item, onAsk: onAsk, onNote: onNote, onFactCheck: onFactCheck);
      case MaterialKind.pdf:
      case MaterialKind.paper:
        // Papers and PDFs open in DSCVR's own PDF reader whenever there is a PDF.
        return item.hasPdf ? _PdfView(item: item, onAsk: onAsk, onNote: onNote, onFactCheck: onFactCheck) : _DocumentView(item: item, onAsk: onAsk, onNote: onNote, onFactCheck: onFactCheck);
      case MaterialKind.link:
        return _DocumentView(item: item, onAsk: onAsk, onNote: onNote, onFactCheck: onFactCheck);
    }
  }
}

/// Adds "Ask Pinda" and "Add note" to the text selection menu.
class _SelectableReading extends StatefulWidget {
  const _SelectableReading({required this.child, required this.onAsk, required this.onNote, required this.onFactCheck});
  final Widget child;
  final ValueChanged<String> onAsk;
  final ValueChanged<String> onNote;
  final ValueChanged<String> onFactCheck;

  @override
  State<_SelectableReading> createState() => _SelectableReadingState();
}

class _SelectableReadingState extends State<_SelectableReading> {
  String _selected = '';

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      onSelectionChanged: (content) => _selected = content?.plainText ?? '',
      contextMenuBuilder: (ctx, state) {
        final text = _selected;
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: [
            if (text.trim().isNotEmpty) ...[
              ContextMenuButtonItem(
                label: 'Ask Pinda',
                onPressed: () {
                  ContextMenuController.removeAny();
                  widget.onAsk(text);
                },
              ),
              ContextMenuButtonItem(
                label: 'Fact-check',
                onPressed: () {
                  ContextMenuController.removeAny();
                  widget.onFactCheck(text);
                },
              ),
              ContextMenuButtonItem(
                label: 'Add note',
                onPressed: () {
                  ContextMenuController.removeAny();
                  widget.onNote(text);
                },
              ),
            ],
            ...state.contextMenuButtonItems,
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// Long-form reading view for articles and papers.
class _DocumentView extends StatefulWidget {
  const _DocumentView({required this.item, required this.onAsk, required this.onNote, required this.onFactCheck});
  final LibraryItem item;
  final ValueChanged<String> onAsk;
  final ValueChanged<String> onNote;
  final ValueChanged<String> onFactCheck;

  @override
  State<_DocumentView> createState() => _DocumentViewState();
}

class _DocumentViewState extends State<_DocumentView> {
  final _scroll = ScrollController();
  Timer? _debounce;
  double _maxSeen = 0;

  @override
  void initState() {
    super.initState();
    _maxSeen = widget.item.progress;
    _scroll.addListener(_track);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _track() {
    if (!_scroll.hasClients || widget.item.content.isEmpty) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    final p = (_scroll.offset / max).clamp(0.0, 1.0);
    if (p <= _maxSeen + 0.02) return;
    _maxSeen = p > 0.97 ? 1 : p;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), () {
      context.services.repo.setProgress(widget.item.id, _maxSeen).catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final c = context.colors;
    final scale = Services.of(context).settings.readerScale;
    final hasText = item.content.trim().isNotEmpty;
    final pad = context.isCompact ? 20.0 : 48.0;

    return _SelectableReading(
      onAsk: widget.onAsk,
      onNote: widget.onNote,
      onFactCheck: widget.onFactCheck,
      child: Scrollbar(
        controller: _scroll,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 80),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Ic.forKind(item.kind), size: 15, color: c.inkFaint),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      [item.siteName ?? item.kind.label, if (item.year != null) '${item.year}'].join('  ·  '),
                      style: context.text.labelMedium,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(item.title,
                    style: AppTheme.serif(fontSize: (context.isCompact ? 28 : 36) * scale, fontWeight: FontWeight.w600, height: 1.15, color: c.ink)),
                if (item.authors.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(item.authors.join(', '), style: AppTheme.sans(fontSize: 14 * scale, color: c.inkMuted, height: 1.5)),
                ],
                const SizedBox(height: 24),
                if (item.summary.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: CardPalette.fill(item.colorIndex, c).withValues(alpha: c.isDark ? 1 : 0.55),
                      borderRadius: BorderRadius.circular(Radii.lg),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.kind == MaterialKind.paper ? 'Abstract' : 'Summary',
                          style: AppTheme.sans(fontSize: 12, fontWeight: FontWeight.w600, color: c.inkMuted, letterSpacing: 0.4)),
                      const SizedBox(height: 8),
                      Text(item.summary, style: AppTheme.serif(fontSize: 16.5 * scale, height: 1.6, color: c.ink)),
                    ]),
                  ),
                  const SizedBox(height: 28),
                ],
                if (hasText)
                  MarkdownView(item.content, scale: scale, serifBody: true)
                else
                  _NoTextNotice(item: item),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoTextNotice extends StatefulWidget {
  const _NoTextNotice({required this.item});
  final LibraryItem item;

  @override
  State<_NoTextNotice> createState() => _NoTextNoticeState();
}

class _NoTextNoticeState extends State<_NoTextNotice> {
  bool _finding = false;
  String? _none;

  String? get _doi {
    final m = RegExp(r'10\.\d{4,9}/[^\s?#]+', caseSensitive: false).firstMatch('${widget.item.url ?? ''} ${widget.item.externalId ?? ''}');
    return m?.group(0);
  }

  /// Looks for a legal, free copy (Unpaywall) and opens it in the reader.
  Future<void> _findPdf() async {
    setState(() {
      _finding = true;
      _none = null;
    });
    try {
      final r = await context.services.api.get('/pdf/find', query: {'doi': _doi!});
      final pdf = r['pdfUrl'] as String?;
      if (pdf == null || !mounted) return;
      await keepPaper(context, LibraryItem.fromMap(widget.item.id, {...widget.item.toMap(), 'pdfUrl': pdf}));
    } catch (e) {
      if (mounted) setState(() => _none = e.toString());
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = widget.item;
    final url = item.url;
    final arxivPdf = item.source == 'arxiv' && item.externalId != null ? 'https://arxiv.org/pdf/${item.externalId}' : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          item.kind == MaterialKind.paper ? 'Read the full paper' : 'Full text is not stored for this link',
          style: context.text.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          item.kind == MaterialKind.paper
              ? 'Read the PDF here in DSCVR with Pinda beside you, or ask Pinda about the abstract.'
              : 'Open the original page to read it. Pinda can still use the title and summary.',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (arxivPdf != null && !item.hasPdf)
            AppButton.primary(
              onPressed: () => keepPaper(context, LibraryItem.fromMap(item.id, {...item.toMap(), 'pdfUrl': arxivPdf})),
              icon: const Icon(Ic.pdf, size: 16),
              label: const Text('Read PDF in DSCVR'),
            ),
          if (arxivPdf == null && !item.hasPdf && _doi != null && item.kind == MaterialKind.paper)
            AppButton.primary(
              onPressed: _finding ? null : _findPdf,
              loading: _finding,
              icon: const Icon(Ic.search, size: 16),
              label: const Text('Find a free PDF'),
            ),
          if (url != null)
            AppButton.secondary(
              onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              icon: const Icon(Ic.external, size: 16),
              label: const Text('Open original'),
            ),
        ]),
        if (_none != null) ...[
          const SizedBox(height: 10),
          Text(_none!, style: AppTheme.sans(fontSize: 13, color: c.inkMuted)),
        ],
      ]),
    );
  }
}

class _PdfView extends StatefulWidget {
  const _PdfView({required this.item, required this.onAsk, required this.onNote, required this.onFactCheck});
  final LibraryItem item;
  final ValueChanged<String> onAsk;
  final ValueChanged<String> onNote;
  final ValueChanged<String> onFactCheck;

  @override
  State<_PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<_PdfView> {
  double _saved = -1;

  /// Reading progress follows the page, saved at most every 10%.
  void _onPage(int page, int count) {
    if (count <= 0) return;
    final p = (page / count).clamp(0.0, 1.0);
    if (p <= widget.item.progress && _saved < 0) return;
    if ((p - _saved).abs() < 0.1 && p < 1) return;
    _saved = p;
    if (p > widget.item.progress) context.services.repo.setProgress(widget.item.id, p);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = widget.item;
    return Container(
      margin: EdgeInsets.fromLTRB(context.isCompact ? 0 : 16, 0, context.isCompact ? 0 : 16, context.isCompact ? 0 : 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.isCompact ? 0 : Radii.lg),
        border: Border.all(color: c.line),
      ),
      child: DscvrPdfViewer(
        url: item.pdfUrl!,
        title: item.title,
        onAsk: widget.onAsk,
        onNote: widget.onNote,
        onFactCheck: widget.onFactCheck,
        onPage: _onPage,
        initialPage: 1,
      ),
    );
  }
}

class _VideoView extends StatelessWidget {
  const _VideoView({required this.item, required this.onAsk, required this.onNote, required this.onFactCheck});
  final LibraryItem item;
  final ValueChanged<String> onAsk;
  final ValueChanged<String> onNote;
  final ValueChanged<String> onFactCheck;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final id = item.externalId ?? LinkService.youtubeId(item.url ?? '');
    final pad = context.isCompact ? 16.0 : 40.0;
    return _SelectableReading(
      onAsk: onAsk,
      onNote: onNote,
      onFactCheck: onFactCheck,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 16, pad, 60),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.lg),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: id == null
                      ? Container(color: c.surfaceMuted, child: const Center(child: Text('Video unavailable')))
                      : EmbedView(url: 'https://www.youtube-nocookie.com/embed/$id?rel=0&modestbranding=1'),
                ),
              ),
              const SizedBox(height: 20),
              Text(item.title, style: AppTheme.serif(fontSize: context.isCompact ? 22 : 28, fontWeight: FontWeight.w600, color: c.ink, height: 1.2)),
              if (item.authors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(item.authors.join(', '), style: context.text.bodySmall),
              ],
              if (item.summary.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(item.summary, style: AppTheme.sans(fontSize: 14.5, color: c.inkMuted, height: 1.6)),
              ],
              if (item.content.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text('Transcript', style: context.text.titleLarge),
                const SizedBox(height: 10),
                MarkdownView(item.content),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
