import 'package:dscvr/models/edition.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';

/// A selectable card describing one DSCVR edition.
class EditionCard extends StatelessWidget {
  const EditionCard({super.key, required this.edition, required this.selected, required this.onTap, this.compact = false});

  final Edition edition;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? c.surface : c.surfaceMuted,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: selected ? c.ink : c.line, width: selected ? 1.6 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? c.ink : c.chip,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(edition.icon, size: 19, color: selected ? c.inverseInk : c.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(edition.label, style: context.text.titleMedium),
                const SizedBox(height: 2),
                Text(edition.price, style: AppTheme.sans(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.inkMuted)),
              ]),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: selected ? 1 : 0,
              child: Icon(Ic.done, size: 20, color: c.ink),
            ),
          ]),
          const SizedBox(height: 10),
          Text(edition.tagline, style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted, height: 1.45)),
          if (!compact) ...[
            const SizedBox(height: 10),
            for (final h in edition.highlights.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Ic.check, size: 13, color: c.inkMuted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(h, style: AppTheme.sans(fontSize: 13, color: c.ink, height: 1.4))),
                ]),
              ),
          ],
        ]),
      ),
    );
  }
}
