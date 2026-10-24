import 'package:dscvr/models/library.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/progress_ring.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';

/// Pastel material card: year + collection, serif title, authors, note
/// count and reading progress.
class MaterialCard extends StatefulWidget {
  const MaterialCard({super.key, required this.item, required this.collectionLabel, required this.onTap, this.onMenu});

  final LibraryItem item;
  final String collectionLabel;
  final VoidCallback onTap;

  /// Called with the global position for a context menu.
  final void Function(Offset position)? onMenu;

  static const double height = 214;

  @override
  State<MaterialCard> createState() => _MaterialCardState();
}

class _MaterialCardState extends State<MaterialCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final item = widget.item;
    final fill = CardPalette.fill(item.colorIndex, c);
    final border = CardPalette.border(item.colorIndex, c);
    final inkOnCard = c.isDark ? c.ink : const Color(0xFF2A2420);
    final mutedOnCard = c.isDark ? c.inkMuted : const Color(0xFF4F4740);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Pressable(
        onTap: widget.onTap,
        scale: 0.975,
        onLongPress: widget.onMenu == null ? null : (d) => widget.onMenu!(d.globalPosition),
        onSecondaryTapUp: widget.onMenu == null ? null : (d) => widget.onMenu!(d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          height: MaterialCard.height,
          decoration: ShapeDecoration(
            color: fill,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(Radii.lg + 2),
              side: BorderSide(color: border),
            ),
            shadows: _hover
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: c.isDark ? 0.35 : 0.10),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: c.isDark ? 0.15 : 0.03),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Builder(
            builder: (_) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.year != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: CardPalette.badge(c),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '${item.year}',
                              style: AppTheme.sans(fontSize: 11.5, fontWeight: FontWeight.w700, color: inkOnCard),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (item.kind != MaterialKind.paper) ...[
                          Icon(Ic.forKind(item.kind), size: 13, color: mutedOnCard),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            widget.collectionLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sans(fontSize: 12, fontWeight: FontWeight.w500, color: mutedOnCard),
                          ),
                        ),
                        if (widget.onMenu != null && _hover)
                          Builder(
                            builder: (ctx) => Pressable(
                              scale: 0.85,
                              onTap: () {
                                final box = ctx.findRenderObject() as RenderBox;
                                widget.onMenu!(box.localToGlobal(Offset(0, box.size.height)));
                              },
                              child: Icon(Ic.more, size: 18, color: mutedOnCard),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.serif(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25, color: inkOnCard),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        item.kind == MaterialKind.note && item.authors.isEmpty ? item.summary : item.authorLine,
                        maxLines: 4,
                        overflow: TextOverflow.fade,
                        style: AppTheme.sans(fontSize: 11.5, height: 1.45, color: mutedOnCard),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Ic.notebook, size: 14, color: mutedOnCard),
                        const SizedBox(width: 4),
                        Text(
                          '${item.noteCount}',
                          style: AppTheme.sans(fontSize: 11.5, fontWeight: FontWeight.w500, color: mutedOnCard),
                        ),
                        if (item.inReadingList) ...[
                          const SizedBox(width: 10),
                          Icon(Ic.readingListOn, size: 13, color: mutedOnCard),
                        ],
                        const Spacer(),
                        if (item.kind != MaterialKind.note)
                          ProgressRing(
                            value: item.progress,
                            size: 15,
                            color: inkOnCard.withValues(alpha: 0.75),
                            track: inkOnCard.withValues(alpha: 0.14),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Responsive grid of [MaterialCard]s.
class MaterialGrid extends StatelessWidget {
  const MaterialGrid({super.key, required this.children, this.minTileWidth = 172});
  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const gap = 12.0;
        final cols = ((w + gap) / (minTileWidth + gap)).floor().clamp(2, 6);
        final tileW = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
          for (final (i, c) in children.indexed)
            SizedBox(
              key: c.key,
              width: tileW,
              // Staggered entrance; capped so long grids don't drag.
              child: Appear(delay: Duration(milliseconds: 22 * (i < 14 ? i : 14)), child: c),
            ),
        ],
        );
      },
    );
  }
}


/// Placeholder grid shown while the library loads.
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({super.key, this.count = 8});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MaterialGrid(children: [
      for (var i = 0; i < count; i++)
        Container(
          height: MaterialCard.height,
          padding: const EdgeInsets.all(12),
          decoration: ShapeDecoration(
            color: c.surface.withValues(alpha: 0.6),
            shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(Radii.lg + 2), side: BorderSide(color: c.line)),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Skeleton(width: 70, height: 16),
            SizedBox(height: 14),
            Skeleton(height: 16),
            SizedBox(height: 8),
            Skeleton(width: 110, height: 16),
            SizedBox(height: 14),
            Skeleton(width: 140, height: 11),
            Spacer(),
            Skeleton(width: 30, height: 11),
          ]),
        ),
    ]);
  }
}

/// Skeleton for a full library page: title, line, grid.
class SkeletonPage extends StatelessWidget {
  const SkeletonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pad = context.isCompact ? 16.0 : 32.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Skeleton(width: 280, height: 38, radius: 10),
        SizedBox(height: 14),
        Skeleton(width: 420, height: 14),
        SizedBox(height: 34),
        SkeletonGrid(),
      ]),
    );
  }
}
