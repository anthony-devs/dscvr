import 'package:dscvr/data/discover_service.dart';
import 'package:dscvr/models/paper.dart';
import 'package:dscvr/screens/add/add_material_sheet.dart';
import 'package:dscvr/screens/library/shelf_page.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Search arXiv and Semantic Scholar, browse fresh papers by subject, and
/// save anything into the library.
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key, this.initialQuery});
  final String? initialQuery;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _q = TextEditingController();
  PaperSource _source = PaperSource.arxiv;
  Subject? _subject;
  List<Paper> _papers = const [];
  TopicSummary? _summary;
  bool _loading = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) {
      _q.text = q;
      _search();
    } else {
      final interests = context.services.session.user.interests;
      _subject = Subject.all.firstWhere((s) => interests.contains(s.label), orElse: () => Subject.all.first);
      _loadSubject(_subject!);
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _run(Future<List<Paper>> Function() fetch, {Future<TopicSummary?>? summary}) async {
    final id = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _summary = null;
    });
    try {
      final results = await fetch();
      final s = await summary;
      if (!mounted || id != _request) return;
      setState(() {
        _papers = results;
        _summary = s;
      });
    } catch (e) {
      if (!mounted || id != _request) return;
      setState(() {
        _papers = const [];
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted && id == _request) setState(() => _loading = false);
    }
  }

  void _search() {
    final q = _q.text.trim();
    if (q.isEmpty) return;
    setState(() => _subject = null);
    final svc = context.services.discover;
    _run(() => svc.search(q, source: _source), summary: svc.summary(q));
  }

  void _loadSubject(Subject s) {
    setState(() {
      _subject = s;
      _q.clear();
    });
    final svc = context.services.discover;
    _run(() => svc.latest(s));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PageBody(maxWidth: 940, children: [
      PageTitle('Discover'),
      const SizedBox(height: 8),
      Text('Search open research and save what matters to your library.',
          style: AppTheme.sans(fontSize: 14.5, color: c.inkMuted)),
      const SizedBox(height: 22),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _q,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            style: AppTheme.sans(fontSize: 15, color: c.ink),
            decoration: InputDecoration(
              hintText: 'Search papers, authors or ideas',
              prefixIcon: const Icon(Ic.search, size: 18),
              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
              suffixIcon: AppIconButton(onPressed: _search, icon: const Icon(Ic.arrowRight, size: 18), tooltip: 'Search'),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Segmented<PaperSource>(
          options: [for (final s in PaperSource.values) (s, s.label, null)],
          value: _source,
          onChanged: (s) {
            setState(() => _source = s);
            if (_q.text.trim().isNotEmpty) _search();
          },
        ),
      ]),
      const SizedBox(height: 22),
      SectionLabel('Latest by subject'),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in Subject.all)
          AppChip(label: s.label, selected: _subject == s, onTap: () => _loadSubject(s)),
      ]),
      const SizedBox(height: 26),
      if (_summary != null && _summary!.extract.isNotEmpty) ...[
        _SummaryCard(summary: _summary!),
        const SizedBox(height: 22),
      ],
      SectionLabel(
        _subject != null ? 'New in ${_subject!.label}' : 'Results',
        count: _loading ? null : _papers.length,
      ),
      const SizedBox(height: 6),
      if (_loading)
        const Padding(padding: EdgeInsets.only(top: 18), child: _PaperSkeleton())
      else if (_error != null)
        EmptyState(icon: Ic.warning, title: 'Search unavailable', message: _error)
      else if (_papers.isEmpty)
        const EmptyState(icon: Ic.discover, title: 'No papers found', message: 'Try different words or another source.')
      else
        for (final p in _papers) _PaperRow(paper: p),
    ]);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final TopicSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.line),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (summary.thumbnail != null && !context.isCompact) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: Image.network(summary.thumbnail!, width: 88, height: 88, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink()),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(summary.title, style: context.text.titleLarge),
              const Spacer(),
              Text('Wikipedia', style: context.text.labelSmall),
            ]),
            const SizedBox(height: 8),
            Text(summary.extract, maxLines: 5, overflow: TextOverflow.ellipsis, style: AppTheme.sans(fontSize: 14, color: c.inkMuted, height: 1.55)),
            if (summary.url != null)
              AppButton.ghost(
                size: BtnSize.sm,
                onPressed: () => launchUrl(Uri.parse(summary.url!), mode: LaunchMode.externalApplication),
                child: const Text('Read more'),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _PaperRow extends StatefulWidget {
  const _PaperRow({required this.paper});
  final Paper paper;

  @override
  State<_PaperRow> createState() => _PaperRowState();
}

class _PaperRowState extends State<_PaperRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.paper;
    final c = context.colors;
    final meta = [
      if (p.year != null) '${p.year}',
      if (p.venue != null && p.venue!.isNotEmpty) p.venue!,
      if (p.citations != null) '${p.citations} citations',
      if (p.subjects.isNotEmpty) p.subjects.first,
    ].join('  ·  ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.title, style: AppTheme.serif(fontSize: 18, fontWeight: FontWeight.w600, color: c.ink, height: 1.3)),
        const SizedBox(height: 6),
        Text(
          p.authors.length > 6 ? '${p.authors.take(6).join(', ')}, et al.' : p.authors.join(', '),
          style: AppTheme.sans(fontSize: 13, color: c.inkMuted),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(meta, style: context.text.labelSmall),
        ],
        if (p.summary.isNotEmpty) ...[
          const SizedBox(height: 10),
          Pressable(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(p.summary,
                maxLines: _expanded ? null : 3,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: AppTheme.sans(fontSize: 14, color: c.ink, height: 1.55)),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          PillButton(label: 'Save to library', icon: Ic.add, onTap: () => savePaperFlow(context, p)),
          if (p.pdfUrl != null)
            PillButton(label: 'PDF', icon: Ic.pdf, onTap: () => launchUrl(Uri.parse(p.pdfUrl!), mode: LaunchMode.externalApplication)),
          if (p.url != null)
            PillButton(label: p.sourceLabel, icon: Ic.external, onTap: () => launchUrl(Uri.parse(p.url!), mode: LaunchMode.externalApplication)),
        ]),
      ]),
    );
  }
}

class _PaperSkeleton extends StatelessWidget {
  const _PaperSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < 4; i++)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Skeleton(width: 420, height: 18),
            SizedBox(height: 10),
            Skeleton(width: 260, height: 12),
            SizedBox(height: 14),
            Skeleton(height: 12),
            SizedBox(height: 6),
            Skeleton(width: 520, height: 12),
          ]),
        ),
    ]);
  }
}
