import 'package:dscvr/models/edition.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';

/// A pricing-style plan card for one DSCVR edition: a tinted price block,
/// who it's for, a choose button, then everything the plan includes.
class EditionCard extends StatelessWidget {
  const EditionCard({super.key, required this.edition, required this.selected, required this.onTap});

  final Edition edition;
  final bool selected;
  final VoidCallback? onTap;

  Color _tint(DscvrColors c) {
    final base = switch (edition) {
      Edition.students => const Color(0xFFDDE9F7),
      Edition.researchers => const Color(0xFFE3DDF8),
      Edition.enterprise => const Color(0xFFE6E7EC),
    };
    return c.isDark ? Color.alphaBlend(base.withValues(alpha: .14), c.surfaceMuted) : base;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = _tint(c);
    return Pressable(
      onTap: onTap,
      scale: .985,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: selected ? c.ink : c.line, width: selected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? .10 : .04),
              blurRadius: selected ? 30 : 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Price block
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(edition.icon, size: 13, color: c.ink),
                    const SizedBox(width: 6),
                    Text(edition.short.toUpperCase(),
                        style: AppTheme.sans(fontSize: 11, fontWeight: FontWeight.w700, color: c.ink, letterSpacing: .8)),
                  ]),
                ),
                const Spacer(),
                AnimatedScale(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  scale: selected ? 1 : 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
                    child: Icon(Ic.check, size: 14, color: c.inverseInk),
                  ),
                ),
              ]),
              const SizedBox(height: 26),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: edition.amount,
                    style: AppTheme.serif(fontSize: 38, fontWeight: FontWeight.w700, color: c.ink, height: 1),
                  ),
                  TextSpan(
                    text: ' ${edition.unit}',
                    style: AppTheme.sans(fontSize: 14, fontWeight: FontWeight.w500, color: c.inkMuted),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              // Two lines tall on every card, so the cards line up side by side.
              SizedBox(
                height: 34,
                child: Text(edition.priceNote, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(fontSize: 12, color: c.inkMuted, height: 1.4)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
            child: Text(edition.forWho, style: AppTheme.sans(fontSize: 14, fontWeight: FontWeight.w500, color: c.ink)),
          ),
          selected
              ? AppButton.primary(
                  onPressed: onTap,
                  expand: true,
                  icon: const Icon(Ic.check, size: 15),
                  label: Text('${edition.short} selected'),
                )
              : AppButton.secondary(
                  onPressed: onTap,
                  expand: true,
                  label: Text('Choose ${edition.short}'),
                ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("What's included",
                  style: AppTheme.sans(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.inkFaint, letterSpacing: .6)),
              const SizedBox(height: 6),
              for (final h in edition.highlights)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Ic.check, size: 14, color: selected ? c.ink : c.inkMuted),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(h, style: AppTheme.sans(fontSize: 13.5, color: c.ink, height: 1.4))),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
