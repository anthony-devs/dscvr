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
import 'package:dscvr/widgets/cite_sheet.dart';
import 'package:dscvr/models/profession.dart';
import 'package:dscvr/screens/reader/pdf_read_page.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Search papers, clinical literature and case law, browse what's new in
/// each subject, and save anything into the library.
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key, this.initialQuery});
  final String? initialQuery;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _q = TextEditingController();
  PaperSource _source = PaperSource.all;
  bool _freeOnly = false;
  bool _guidelines = false;
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

  bool get _lowData => context.services.settings.lowData;
  int get _limit => _lowData ? 10 : 20;

  void _search() {
    final q = _q.text.trim();
    if (q.isEmpty) return;
    setState(() => _subject = null);
    final svc = context.services.discover;
    _run(() => svc.search(q,
            source: _source, limit: _limit, guidelines: _guidelines && _source == PaperSource.europePmc, openAccess: _freeOnly),
        summary: _lowData || _source == PaperSource.ukCaseLaw ? null : svc.summary(q));
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
    _run(() async {
      final papers = await svc.latest(s, limit: _limit, guidelines: s.guidelines || (_guidelines && s.feed == Feed.europepmc));
      return _freeOnly ? [for (final p in papers) if (p.pdfUrl != null || p.openAccess) p] : papers;
    });
  }

  String _searchedLine(Map<String, Object?> status) {
    final ok = [for (final e in status.entries) if (e.value is num) Paper.labelFor(e.key)];
    final busy = [for (final e in status.entries) if (e.value is! num) Paper.labelFor(e.key)];
    return 'Searched ${ok.join(', ')}${busy.isEmpty ? '' : '. Busy right now: ${busy.join(', ')}'}';
  }

  /// Law libraries show for law subjects and law searches. A lawyer's profile only
  /// brings them back when no other subject is open, so Physics never shows them.
  bool get _showLaw {
    if (_source == PaperSource.ukCaseLaw) return true;
    if (_subject != null) return _subject!.isLaw;
    return context.services.session.user.profession == Profession.law;
  }

  /// Plain words for the library's own search box, never a feed query like "cat:physics.gen-ph".
  String get _lawQuery {
    final typed = _q.text.trim();
    if (typed.isNotEmpty) return typed;
    final s = _subject;
    return (s != null && s.isLaw) ? s.label : 'contract';
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
        SizedBox(
          width: 230,
          child: AppSelect<PaperSource>(
            options: [for (final s in PaperSource.searchable) SelectOption(s, s.label, subtitle: s.blurb)],
            value: _source,
            onChanged: (s) {
              setState(() => _source = s);
              if (_q.text.trim().isNotEmpty) _search();
            },
          ),
        ),
        if (_source != PaperSource.ukCaseLaw)
          AppChip(
            label: 'Free PDF only',
            selected: _freeOnly,
            onTap: () {
              setState(() => _freeOnly = !_freeOnly);
              if (_q.text.trim().isNotEmpty) _search();
            },
          ),
        if (_source == PaperSource.europePmc || (_subject?.feed == Feed.europepmc))
          AppChip(
            label: 'Guidelines only',
            selected: _guidelines,
            onTap: () {
              setState(() => _guidelines = !_guidelines);
              if (_q.text.trim().isNotEmpty) {
                _search();
              } else if (_subject != null) {
                _loadSubject(_subject!);
              }
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
      if (_showLaw) ...[
        _LawLibraries(query: _lawQuery),
        const SizedBox(height: 22),
      ],
      if (_summary != null && _summary!.extract.isNotEmpty) ...[
        _SummaryCard(summary: _summary!, showImage: !_lowData),
        const SizedBox(height: 22),
      ],
      SectionLabel(
        _subject != null
            ? switch (_subject!.feed) {
                Feed.arxiv => 'New in ${_subject!.label} on arXiv',
                Feed.europepmc => _subject!.guidelines || _guidelines
                    ? 'Recent guidelines in ${_subject!.label}'
                    : 'Recent in ${_subject!.label} from Europe PMC',
                Feed.caselaw => 'Latest UK judgments in ${_subject!.label}',
                Feed.openalex => 'New in ${_subject!.label} across journals',
              }
            : 'Results',
        count: _loading ? null : _papers.length,
      ),
      if (!_loading && _subject == null && _source == PaperSource.all && context.services.discover.lastSources.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_searchedLine(context.services.discover.lastSources), style: context.text.labelSmall),
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

/// Links to the free African and Commonwealth law libraries, which don't
/// allow automated search, plus a pointer for subscribers' own law reports.
class _LawLibraries extends StatelessWidget {
  const _LawLibraries({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Search Nigerian and Commonwealth judgments', style: context.text.titleMedium),
        const SizedBox(height: 4),
        Text('Opens each free law library\'s own search for "$query". Save any judgment to your library with its link or PDF.',
            style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted, height: 1.5)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final lib in LawLibrary.all)
            PillButton(
              label: '${lib.name} · ${lib.country}',
              icon: Ic.external,
              onTap: () => launchUrl(lib.searchUri(query), mode: LaunchMode.externalApplication),
            ),
        ]),
        const SizedBox(height: 12),
        Text('Subscribe to NWLR, LawPavilion or another law report? Add the PDF of a report to your library and Pinda can brief it, '
            'quiz you on it, and cite it.',
            style: AppTheme.sans(fontSize: 12.5, color: c.inkFaint, height: 1.5)),
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, this.showImage = true});
  final TopicSummary summary;
  final bool showImage;

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
        if (showImage && summary.thumbnail != null && !context.isCompact) ...[
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
    final meta = p.isJudgment
        ? [
            if (p.citation != null) p.citation!,
            if (p.court != null && p.court!.isNotEmpty) p.court!,
            if (p.date != null) p.date!,
          ].join('  ·  ')
        : [
            if (p.year != null) '${p.year}',
            if (p.venue != null && p.venue!.isNotEmpty) p.venue!,
            if (p.citations != null) '${p.citations} citations',
            if (p.subjects.isNotEmpty) p.subjects.first,
          ].join('  ·  ');
    final badge = p.isJudgment
        ? 'Judgment'
        : p.isGuideline
            ? 'Guideline'
            : p.kind;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final l in p.sourceLabels) _Tag(l, source: true),
          if (badge != null) _Tag(badge),
          if (p.openAccess || p.pdfUrl != null) const _Tag('Free to read'),
        ]),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(p.title, style: AppTheme.serif(fontSize: 18, fontWeight: FontWeight.w600, color: c.ink, height: 1.3)),
        ),
        if (!p.isJudgment) ...[
          const SizedBox(height: 6),
          Text(
            p.authors.length > 6 ? '${p.authors.take(6).join(', ')}, et al.' : p.authors.join(', '),
            style: AppTheme.sans(fontSize: 13, color: c.inkMuted),
          ),
        ],
        if (meta.isNotEmpty || (widget.rating?.count ?? 0) > 0) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (widget.rating != null) RatingBadge(average: widget.rating!.average, count: widget.rating!.count),
            if (meta.isNotEmpty) Text(meta, style: context.text.labelSmall),
          ]),
        ],
        if (p.summary.isNotEmpty && !p.isJudgment) ...[
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
          if (p.pdfUrl != null)
            PillButton(label: 'Read in DSCVR', icon: Ic.bookOpen, onTap: () => openPdfReader(context, p)),
          if (p.pdfUrl == null && p.doi != null) _FindPdfButton(paper: p),
          PillButton(label: 'Save to library', icon: Ic.add, onTap: () => savePaperFlow(context, p)),
          if (p.url != null)
            PillButton(label: p.sourceLabel, icon: Ic.external, onTap: () => launchUrl(Uri.parse(p.url!), mode: LaunchMode.externalApplication)),
          PillButton(label: 'Cite', icon: Ic.quote, onTap: () => showCiteSheet(context, CiteSource.fromPaper(p))),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: StarRating(value: widget.rating?.mine ?? 0, size: 16, onChanged: _rate),
          ),
        ]),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.source = false});
  final String text;

  /// Source labels (arXiv, PLOS...) are outlined; kinds are filled.
  final bool source;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: source ? 'Source: $text' : text,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: source ? Colors.transparent : c.surfaceMuted,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.line),
          ),
          child: Text(text, style: AppTheme.sans(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.inkMuted)),
        ),
      ),
    );
  }
}

/// Asks the server for a legal free copy (Unpaywall), then opens it.
class _FindPdfButton extends StatefulWidget {
  const _FindPdfButton({required this.paper});
  final Paper paper;

  @override
  State<_FindPdfButton> createState() => _FindPdfButtonState();
}

class _FindPdfButtonState extends State<_FindPdfButton> {
  bool _busy = false;

  Future<void> _find() async {
    setState(() => _busy = true);
    try {
      final r = await context.services.api.get('/pdf/find', query: {'doi': widget.paper.doi!}, auth: false);
      final url = r['pdfUrl'] as String?;
      if (url != null && mounted) {
        openPdfReader(context, Paper.fromMap({...widget.paper.toMap(), 'pdfUrl': url}));
      }
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      PillButton(label: _busy ? 'Looking…' : 'Find free PDF', icon: Ic.search, onTap: _busy ? () {} : _find);
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
