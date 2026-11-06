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
import 'package:dscvr/data/research_service.dart';
import 'package:dscvr/models/workspace.dart';
import 'package:dscvr/widgets/star_rating.dart';
import 'package:dscvr/widgets/subject_picker.dart';
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
      final mine = _mySubjects();
      _loadSubject(mine.isNotEmpty ? mine.first : Subject.lookup('Computer Science')!);
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
        _ratings = const {};
      });
      _loadRatings(results, id);
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

  Map<String, PaperRating> _ratings = const {};

  Future<void> _loadRatings(List<Paper> papers, int id) async {
    final r = await context.services.research.ratings([for (final p in papers) ResearchService.paperKey(p)]);
    if (mounted && id == _request) setState(() => _ratings = r);
  }

  void _search() {
    final q = _q.text.trim();
    if (q.isEmpty) return;
    setState(() => _subject = null);
    final svc = context.services.discover;
    _run(() => svc.search(q, source: _source), summary: svc.summary(q));
  }

  /// Subjects picked here this visit, on top of the user's own.
  final List<Subject> _picked = [];

  /// The user's library categories and sign-up subjects, so every field works.
  List<Subject> _mySubjects() {
    final names = <String>[
      ...context.library.categories.map((c) => c.name),
      ...context.services.session.user.interests,
    ];
    final out = <Subject>[];
    for (final n in names) {
      if (n.trim().isEmpty) continue;
      final s = Subject.custom(n);
      if (!out.contains(s)) out.add(s);
    }
    for (final s in _picked) {
      if (!out.contains(s)) out.add(s);
    }
    return out;
  }

  Future<void> _moreSubjects() async {
    final label = await pickSubject(context);
    if (label == null || !mounted) return;
    final s = Subject.custom(label);
    if (!_picked.contains(s)) _picked.add(s);
    _loadSubject(s);
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
        AppButton.ghost(
          size: BtnSize.sm,
          onPressed: () {
            final q = _q.text.trim().isNotEmpty ? _q.text.trim() : (_subject?.label ?? '');
            launchUrl(Uri.https('scholar.google.com', '/scholar', {if (q.isNotEmpty) 'q': q}), mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Ic.external, size: 14),
          label: const Text('Open in Google Scholar'),
        ),
      ]),
      const SizedBox(height: 22),
      SectionLabel('Latest in your subjects'),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in _mySubjects())
          AppChip(label: s.label, selected: _subject == s, onTap: () => _loadSubject(s)),
        if (_subject != null && !_mySubjects().contains(_subject))
          AppChip(label: _subject!.label, selected: true, onTap: () {}),
        AppChip(label: 'More subjects', leading: const Icon(Ic.add, size: 13), selected: false, onTap: _moreSubjects),
      ]),
      const SizedBox(height: 26),
      if (_summary != null && _summary!.extract.isNotEmpty) ...[
        _SummaryCard(summary: _summary!),
        const SizedBox(height: 22),
      ],
      SectionLabel(
        _subject != null
            ? (_subject!.usesArxiv ? 'New in ${_subject!.label} on arXiv' : 'New in ${_subject!.label} across journals')
            : 'Results',
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
        for (final p in _papers)
          _PaperRow(
            paper: p,
            rating: _ratings[ResearchService.paperKey(p)],
            onRated: (r) => setState(() => _ratings = {..._ratings, ResearchService.paperKey(p): r}),
          ),
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
  const _PaperRow({required this.paper, this.rating, required this.onRated});
  final Paper paper;
  final PaperRating? rating;
  final ValueChanged<PaperRating> onRated;

  @override
  State<_PaperRow> createState() => _PaperRowState();
}

class _PaperRowState extends State<_PaperRow> {
  bool _expanded = false;

  Future<void> _rate(int stars) async {
    if (stars == 0) return;
    try {
      final r = await context.services.research.rate(ResearchService.paperKey(widget.paper), stars, widget.paper.title);
      widget.onRated(r);
      if (mounted) toast(context, 'Thanks for rating', description: 'Your rating helps others find good papers.');
    } catch (e) {
      if (mounted) toast(context, e.toString());
    }
  }

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
        if (meta.isNotEmpty || (widget.rating?.count ?? 0) > 0) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (widget.rating != null) RatingBadge(average: widget.rating!.average, count: widget.rating!.count),
            if (meta.isNotEmpty) Text(meta, style: context.text.labelSmall),
          ]),
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
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: StarRating(value: widget.rating?.mine ?? 0, size: 16, onChanged: _rate),
          ),
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
