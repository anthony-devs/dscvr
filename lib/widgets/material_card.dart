import 'package:dscvr/models/library.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/progress_ring.dart';
import 'package:flutter/material.dart';

/// Pastel material card: year + collection, serif title, authors, note
/// count and reading progress.
class MaterialCard extends StatefulWidget {
  const MaterialCard({
    super.key,
    required this.item,
    required this.collectionLabel,
    required this.onTap,
    this.onMenu,
  });

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
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onSecondaryTapUp: widget.onMenu == null ? null : (d) => widget.onMenu!(d.globalPosition),
        onLongPressStart: widget.onMenu == null ? null : (d) => widget.onMenu!(d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          height: MaterialCard.height,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: border),
            boxShadow: _hover
                ? [BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? 0.3 : 0.08), blurRadius: 16, offset: const Offset(0, 6))]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.lg),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (item.year != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: CardPalette.badge(c),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('${item.year}',
                            style: AppTheme.sans(fontSize: 11.5, fontWeight: FontWeight.w700, color: inkOnCard)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (item.kind != MaterialKind.paper) ...[
                      Icon(Ic.forKind(item.kind), size: 13, color: mutedOnCard),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: Text(widget.collectionLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(fontSize: 12, fontWeight: FontWeight.w500, color: mutedOnCard)),
                    ),
                    if (widget.onMenu != null && _hover)
                      Builder(
                        builder: (ctx) => InkWell(
                          borderRadius: BorderRadius.circular(Radii.sm),
                          onTap: () {
                            final box = ctx.findRenderObject() as RenderBox;
                            widget.onMenu!(box.localToGlobal(Offset(0, box.size.height)));
                          },
                          child: Icon(Ic.more, size: 18, color: mutedOnCard),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Text(item.title,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.serif(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25, color: inkOnCard)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      item.kind == MaterialKind.note && item.authors.isEmpty
                          ? item.summary
                          : item.authorLine,
                      maxLines: 4,
                      overflow: TextOverflow.fade,
                      style: AppTheme.sans(fontSize: 11.5, height: 1.45, color: mutedOnCard),
                    ),
                  ),
                  Row(children: [
                    Icon(Ic.notebook, size: 14, color: mutedOnCard),
                    const SizedBox(width: 4),
                    Text('${item.noteCount}',
                        style: AppTheme.sans(fontSize: 11.5, fontWeight: FontWeight.w500, color: mutedOnCard)),
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
                  ]),
                ]),
              ),
            ),
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
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      const gap = 12.0;
      final cols = ((w + gap) / (minTileWidth + gap)).floor().clamp(2, 6);
      final tileW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: tileW, child: c)],
      );
    });
  }
}
