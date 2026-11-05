import 'package:dscvr/data/api.dart';
import 'package:dscvr/data/research_service.dart';
import 'package:dscvr/models/library.dart';
import 'package:dscvr/models/paper.dart';
import 'package:dscvr/models/workspace.dart';
import 'package:dscvr/screens/add/add_material_sheet.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/star_rating.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Papers related to the open one, from Semantic Scholar, with community
/// ratings and one-tap save.
class RelatedPanel extends StatefulWidget {
  const RelatedPanel({super.key, required this.item});
  final LibraryItem item;

  @override
  State<RelatedPanel> createState() => _RelatedPanelState();
}

class _RelatedPanelState extends State<RelatedPanel> {
  late Future<(List<Paper>, Map<String, PaperRating>)> _future = _load();
  final Set<String> _saved = {};

  Future<(List<Paper>, Map<String, PaperRating>)> _load() async {
    final research = context.services.research;
    final papers = await research.related(widget.item);
    final ratings = await research.ratings([for (final p in papers) ResearchService.paperKey(p)]);
    return (papers, ratings);
  }

  Future<void> _save(Paper p) async {
    final lib = context.library;
    final item = paperToItem(context, p, categoryId: widget.item.categoryId, topicId: widget.item.topicId);
    await keepPaper(context, item);
    if (!mounted) return;
    setState(() => _saved.add(p.id));
    toast(context, 'Saved next to this paper', description: lib.category(widget.item.categoryId)?.name);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FutureBuilder<(List<Paper>, Map<String, PaperRating>)>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (var i = 0; i < 4; i++)
              const Padding(padding: EdgeInsets.only(bottom: 14), child: Skeleton(height: 64)),
          ]);
        }
        if (snap.hasError) {
          final msg = snap.error is ApiException ? (snap.error as ApiException).message : 'Related papers are unavailable right now.';
          return EmptyState(
            icon: Ic.discover,
            title: 'No suggestions yet',
            message: msg,
            action: AppButton.secondary(onPressed: () => setState(() => _future = _load()), child: const Text('Try again')),
          );
        }
        final (papers, ratings) = snap.data!;
        if (papers.isEmpty) {
          return const EmptyState(
            icon: Ic.discover,
            title: 'Nothing related found',
            message: 'Semantic Scholar has no recommendations for this one yet.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          itemCount: papers.length + 1,
          separatorBuilder: (_, i) => i == 0 ? const SizedBox(height: 4) : Divider(color: c.line, height: 22),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Text('Recommended from Semantic Scholar', style: context.text.labelMedium);
            }
            final p = papers[i - 1];
            final r = ratings[ResearchService.paperKey(p)];
            final saved = _saved.contains(p.id);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title, style: AppTheme.serif(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.ink, height: 1.3)),
              const SizedBox(height: 4),
              Text(
                [if (p.year != null) '${p.year}', if (p.authors.isNotEmpty) p.authors.take(3).join(', '), if (p.citations != null) '${p.citations} citations']
                    .join('  ·  '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(children: [
                if (r != null) RatingBadge(average: r.average, count: r.count),
                const Spacer(),
                if (p.url != null)
                  AppIconButton(
                    tooltip: 'Open',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => launchUrl(Uri.parse(p.url!), mode: LaunchMode.externalApplication),
                    icon: const Icon(Ic.external, size: 16),
                  ),
                saved
                    ? Padding(padding: const EdgeInsets.all(8), child: Icon(Ic.check, size: 17, color: c.success))
                    : PillButton(label: 'Save', icon: Ic.add, onTap: () => _save(p)),
              ]),
            ]);
          },
        );
      },
    );
  }
}
