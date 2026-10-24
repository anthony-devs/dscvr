import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';

class ColorDot extends StatelessWidget {
  const ColorDot(this.color, {super.key, this.size = 9});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Brand mark: four tiles, two squares and two circles, echoing the original
/// DSCVR logo.
class DscvrMark extends StatelessWidget {
  const DscvrMark({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(size * 0.26)),
      padding: EdgeInsets.all(size * 0.2),
      child: CustomPaint(painter: _MarkPainter(c.inverseInk)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width * 0.08;
    final tile = (size.width - gap) / 2;
    final solid = Paint()..color = color;
    final soft = Paint()..color = color.withValues(alpha: 0.5);
    final r = Radius.circular(tile * 0.18);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, tile, tile), r), solid);
    canvas.drawCircle(Offset(tile + gap + tile / 2, tile / 2), tile / 2, soft);
    canvas.drawCircle(Offset(tile / 2, tile + gap + tile / 2), tile / 2, soft);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(tile + gap, tile + gap, tile, tile), r), solid);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 26});
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DscvrMark(size: size),
          const SizedBox(width: 10),
          Text('DSCVR',
              style: AppTheme.sans(
                  fontSize: size * 0.52,
                  fontWeight: FontWeight.w700,
                  letterSpacing: size * 0.09,
                  color: context.colors.ink)),
        ],
      );
}

/// Rounded count badge, e.g. the "2" next to an author's name.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.background});
  final int count;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: background ?? c.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text('$count',
          style: AppTheme.sans(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.inkMuted)),
    );
  }
}

class AuthorChip extends StatelessWidget {
  const AuthorChip({super.key, required this.name, required this.count, this.selected = false, this.onTap});
  final String name;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected ? c.ink : c.chip,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 5, 6, 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(name,
                style: AppTheme.sans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: selected ? c.inverseInk : c.ink)),
            const SizedBox(width: 6),
            CountBadge(count, background: selected ? c.inverseInk.withValues(alpha: 0.2) : null),
          ]),
        ),
      ),
    );
  }
}

/// Small outlined pill button: "+ Add", "Recently accessed".
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, this.icon, this.onTap, this.trailing});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface.withValues(alpha: c.isDark ? 0.6 : 0.75),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        side: BorderSide(color: c.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 14, color: c.ink), const SizedBox(width: 6)],
            Text(label, style: AppTheme.sans(fontSize: 12.5, fontWeight: FontWeight.w500, color: c.ink)),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ]),
        ),
      ),
    );
  }
}

/// Small uppercase-free section heading with an optional trailing action.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.count});
  final String text;
  final Widget? trailing;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Text(count == null ? text : '$text ($count)',
          style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w500, color: c.ink)),
      if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      const SizedBox(width: 12),
      Expanded(child: Divider(color: c.line)),
    ]);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(Radii.lg)),
              child: Icon(icon, size: 24, color: c.inkMuted),
            ),
            const SizedBox(height: Space.lg),
            Text(title, textAlign: TextAlign.center, style: context.text.titleLarge),
            if (message != null) ...[
              const SizedBox(height: Space.sm),
              Text(message!, textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: c.inkMuted)),
            ],
            if (action != null) ...[const SizedBox(height: Space.xl), action!],
          ]),
        ),
      ),
    );
  }
}

/// Serif page title with an optional edit affordance, as in the reference.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.onEdit, this.leading});
  final String title;
  final VoidCallback? onEdit;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final style = context.isCompact ? context.text.displaySmall : context.text.displayMedium;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        ?leading,
        Text(title, style: style),
        if (onEdit != null) RoundIconButton(icon: Ic.edit, tooltip: 'Edit', onTap: onEdit!),
      ],
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.tooltip, required this.onTap, this.size = 30});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.surfaceMuted,
        shape: CircleBorder(side: BorderSide(color: c.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: size, child: Icon(icon, size: size * 0.5, color: c.ink)),
        ),
      ),
    );
  }
}

/// Folder-style tabs (Items / Notebooks / Topics) from the reference layout.
class FolderTabs extends StatelessWidget {
  const FolderTabs({super.key, required this.tabs, required this.selected, required this.onSelect});
  final List<(IconData, String)> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final (i, t) in tabs.indexed)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Material(
              color: i == selected ? c.surface : c.surfaceMuted,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.md)),
                side: BorderSide(color: c.line),
              ),
              child: InkWell(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.md)),
                onTap: () => onSelect(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(children: [
                    Icon(t.$1, size: 15, color: i == selected ? c.ink : c.inkMuted),
                    const SizedBox(width: 7),
                    Text(t.$2,
                        style: AppTheme.sans(
                            fontSize: 13,
                            fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                            color: i == selected ? c.ink : c.inkMuted)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Simple segmented control used in settings and the reader.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged, this.expand = false});
  final List<(T, String, IconData?)> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Stretch segments to fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.line),
      ),
      child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: [
        for (final o in options)
          _maybeExpand(GestureDetector(
            onTap: () => onChanged(o.$1),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: o.$1 == value ? c.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.sm),
                boxShadow: o.$1 == value
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                    : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                if (o.$3 != null) ...[Icon(o.$3, size: 14, color: c.ink), const SizedBox(width: 6)],
                Text(o.$2,
                    style: AppTheme.sans(
                        fontSize: 12.5,
                        fontWeight: o.$1 == value ? FontWeight.w600 : FontWeight.w500,
                        color: o.$1 == value ? c.ink : c.inkMuted)),
              ]),
            ),
          )),
      ]),
    );
  }

  Widget _maybeExpand(Widget w) => expand ? Expanded(child: w) : w;
}

String relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays == 1) return 'yesterday';
  if (d.inDays < 30) return '${d.inDays} days ago';
  if (d.inDays < 60) return 'last month';
  if (d.inDays < 365) return '${d.inDays ~/ 30} months ago';
  return '${d.inDays ~/ 365} years ago';
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
}
