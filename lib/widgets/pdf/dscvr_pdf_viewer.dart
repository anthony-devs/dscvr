import 'dart:async';

import 'package:dscvr/config/env.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/download/download.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

/// DSCVR's own PDF reader: pages, zoom, search inside the PDF, download, and
/// Pinda on whatever you select (or the whole page).
class DscvrPdfViewer extends StatefulWidget {
  const DscvrPdfViewer({
    super.key,
    required this.url,
    required this.title,
    this.onAsk,
    this.onNote,
    this.onFactCheck,
    this.onPage,
    this.initialPage = 1,
  });

  /// Public or storage URL of the PDF. Fetched through the DSCVR server so
  /// publishers without CORS still open.
  final String url;
  final String title;
  final ValueChanged<String>? onAsk;
  final ValueChanged<String>? onNote;
  final ValueChanged<String>? onFactCheck;

  /// Called with (page, pageCount) as the reader moves through the document.
  final void Function(int page, int count)? onPage;
  final int initialPage;

  @override
  State<DscvrPdfViewer> createState() => _DscvrPdfViewerState();
}

class _DscvrPdfViewerState extends State<DscvrPdfViewer> {
  final _controller = PdfViewerController();
  late final PdfTextSearcher _searcher = PdfTextSearcher(_controller)..addListener(_onSearch);
  final _query = TextEditingController();
  Future<Map<String, String>>? _headers;
  int _page = 1;
  int _count = 0;
  bool _searching = false;
  bool _downloading = false;
  String _selection = '';
  Timer? _selDebounce;

  @override
  void initState() {
    super.initState();
    _headers = Env.demo ? Future.value(const {}) : context.services.api.authHeaders();
  }

  @override
  void dispose() {
    _selDebounce?.cancel();
    _searcher.removeListener(_onSearch);
    _searcher.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onSearch() {
    if (mounted) setState(() {});
  }

  Uri get _source => Env.demo
      ? Uri.parse(widget.url)
      : context.services.api.uri('/pdf/view', {'url': widget.url});

  String get _fileName {
    final base = widget.title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]+'), '').trim().replaceAll(RegExp(r'\s+'), '-');
    return '${base.isEmpty ? 'paper' : base.substring(0, base.length.clamp(0, 80))}.pdf';
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      if (!canDownload || Env.demo) {
        await launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);
      } else {
        final bytes = await context.services.api.getBytes('/pdf/view', query: {'url': widget.url});
        downloadBytes(_fileName, bytes);
        if (mounted) toast(context, 'PDF downloaded', description: _fileName);
      }
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<String> _pageText() async {
    if (!_controller.isReady) return '';
    final page = _controller.document.pages[(_page - 1).clamp(0, _count - 1)];
    final text = await page.loadStructuredText();
    return text.fullText.trim();
  }

  Future<void> _askAboutPage() async {
    final t = await _pageText();
    if (t.isEmpty) {
      if (mounted) toast(context, 'This page has no selectable text', description: 'It may be a scanned image.');
      return;
    }
    widget.onAsk?.call('(Page $_page)\n${t.length > 6000 ? t.substring(0, 6000) : t}');
  }

  void _onSelection(PdfTextSelection sel) {
    _selDebounce?.cancel();
    _selDebounce = Timer(const Duration(milliseconds: 180), () async {
      final text = sel.hasSelectedText ? (await sel.getSelectedText()).trim() : '';
      if (mounted && text != _selection) setState(() => _selection = text);
    });
  }

  Future<void> _clearSelection() async {
    await _controller.textSelectionDelegate.clearTextSelection();
    if (mounted) setState(() => _selection = '');
  }

  void _act(ValueChanged<String>? f) {
    final t = _selection;
    if (t.isEmpty || f == null) return;
    f(t);
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _toolbar(c),
      if (_searching) _searchBar(c),
      Expanded(
        child: Stack(children: [
          FutureBuilder<Map<String, String>>(
            future: _headers,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: Spinner(size: 22));
              return Semantics(
                label: 'PDF: ${widget.title}. Page $_page of $_count.',
                child: PdfViewer.uri(
                  _source,
                  headers: snap.data,
                  controller: _controller,
                  initialPageNumber: widget.initialPage,
                  params: PdfViewerParams(
                    backgroundColor: c.surfaceMuted,
                    margin: 12,
                    pageDropShadow: BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
                    textSelectionParams: PdfTextSelectionParams(onTextSelectionChange: _onSelection),
                    pagePaintCallbacks: [_searcher.pageTextMatchPaintCallback],
                    onViewerReady: (doc, ctrl) {
                      setState(() => _count = doc.pages.length);
                      widget.onPage?.call(_page, _count);
                    },
                    onPageChanged: (n) {
                      if (n == null) return;
                      setState(() => _page = n);
                      widget.onPage?.call(n, _count);
                    },
                    loadingBannerBuilder: (context, got, total) => Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Spinner(size: 22),
                        const SizedBox(height: 10),
                        Text(
                          total != null && total > 0 ? 'Opening PDF ${(got * 100 / total).round()}%' : 'Opening PDF…',
                          style: AppTheme.sans(fontSize: 13, color: c.inkMuted),
                        ),
                      ]),
                    ),
                    errorBannerBuilder: (context, error, stack, ref) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: EmptyState(
                          icon: Ic.warning,
                          title: "This PDF won't open here",
                          message: 'The publisher may block downloads, or the file may be damaged.',
                          action: AppButton.secondary(
                            onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
                            icon: const Icon(Ic.external, size: 14),
                            label: const Text('Open the original'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (_selection.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(child: _SelectionBar(
                onAsk: widget.onAsk == null ? null : () => _act(widget.onAsk),
                onNote: widget.onNote == null ? null : () => _act(widget.onNote),
                onCheck: widget.onFactCheck == null ? null : () => _act(widget.onFactCheck),
                onCopy: () async {
                  await Clipboard.setData(ClipboardData(text: _selection));
                  if (context.mounted) toast(context, 'Copied');
                  _clearSelection();
                },
              )),
            ),
        ]),
      ),
    ]);
  }

  Widget _toolbar(DscvrColors c) {
    final ready = _count > 0;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.line))),
      child: Row(children: [
        AppIconButton(
          tooltip: 'Previous page',
          size: 32,
          onPressed: ready && _page > 1 ? () => _controller.goToPage(pageNumber: _page - 1) : null,
          icon: const Icon(Ic.caretLeft, size: 16),
        ),
        Semantics(
          liveRegion: true,
          child: Text(ready ? '$_page / $_count' : '…', style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
        ),
        AppIconButton(
          tooltip: 'Next page',
          size: 32,
          onPressed: ready && _page < _count ? () => _controller.goToPage(pageNumber: _page + 1) : null,
          icon: const Icon(Ic.caretRight, size: 16),
        ),
        const SizedBox(width: 4),
        AppIconButton(tooltip: 'Zoom out', size: 32, onPressed: ready ? () => _controller.zoomDown() : null, icon: const Icon(Ic.minus, size: 16)),
        AppIconButton(tooltip: 'Zoom in', size: 32, onPressed: ready ? () => _controller.zoomUp() : null, icon: const Icon(Ic.add, size: 16)),
        const Spacer(),
        if (widget.onAsk != null && !context.isCompact)
          AppButton.ghost(
            size: BtnSize.sm,
            onPressed: ready ? _askAboutPage : null,
            icon: const Icon(Ic.pinda, size: 14),
            label: const Text('Explain this page'),
          )
        else if (widget.onAsk != null)
          AppIconButton(tooltip: 'Ask Pinda about this page', size: 32, onPressed: ready ? _askAboutPage : null, icon: const Icon(Ic.pinda, size: 16)),
        AppIconButton(
          tooltip: 'Search in this PDF',
          size: 32,
          onPressed: ready
              ? () => setState(() {
                    _searching = !_searching;
                    if (!_searching) {
                      _searcher.resetTextSearch();
                      _query.clear();
                    }
                  })
              : null,
          icon: const Icon(Ic.search, size: 16),
        ),
        AppIconButton(
          tooltip: _downloading ? 'Downloading' : 'Download PDF',
          size: 32,
          onPressed: _downloading ? null : _download,
          icon: _downloading ? const Spinner(size: 14) : const Icon(Ic.download, size: 16),
        ),
      ]),
    );
  }

  Widget _searchBar(DscvrColors c) {
    final n = _searcher.matches.length;
    final i = _searcher.currentIndex;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.line))),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (v) => v.trim().length >= 2 ? _searcher.startTextSearch(v.trim()) : _searcher.resetTextSearch(),
            onSubmitted: (_) => _searcher.goToNextMatch(),
            style: AppTheme.sans(fontSize: 14, color: c.ink),
            decoration: const InputDecoration(
              hintText: 'Find in this PDF',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            _searcher.isSearching ? 'Searching…' : (n == 0 ? (_query.text.length >= 2 ? 'No matches' : '') : '${(i ?? 0) + 1} of $n'),
            style: AppTheme.sans(fontSize: 12.5, color: c.inkMuted),
          ),
        ),
        AppIconButton(tooltip: 'Previous match', size: 32, onPressed: n > 0 ? () => _searcher.goToPrevMatch() : null, icon: const Icon(Ic.caretLeft, size: 15)),
        AppIconButton(tooltip: 'Next match', size: 32, onPressed: n > 0 ? () => _searcher.goToNextMatch() : null, icon: const Icon(Ic.caretRight, size: 15)),
      ]),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({this.onAsk, this.onNote, this.onCheck, required this.onCopy});
  final VoidCallback? onAsk;
  final VoidCallback? onNote;
  final VoidCallback? onCheck;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget btn(String label, IconData icon, VoidCallback? f, {bool primary = false}) => f == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: primary
                ? AppButton.primary(size: BtnSize.sm, onPressed: f, icon: Icon(icon, size: 14), label: Text(label))
                : AppButton.ghost(size: BtnSize.sm, onPressed: f, icon: Icon(icon, size: 14), label: Text(label)),
          );
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Wrap(children: [
        btn('Ask Pinda', Ic.pinda, onAsk, primary: true),
        btn('Note', Ic.note, onNote),
        btn('Fact-check', Ic.scale, onCheck),
        btn('Copy', Ic.copy, onCopy),
      ]),
    );
  }
}
