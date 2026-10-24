import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/ui/ui.dart';
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
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      builder: (context, hovered, pressed, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(9, 5, 6, 5),
        decoration: ShapeDecoration(
          color: selected ? c.ink : (hovered ? Color.lerp(c.chip, c.ink, 0.06) : c.chip),
          shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: child,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(name,
            style: AppTheme.sans(fontSize: 12.5, fontWeight: FontWeight.w500, color: selected ? c.inverseInk : c.ink)),
        const SizedBox(width: 6),
        CountBadge(count, background: selected ? c.inverseInk.withValues(alpha: 0.2) : null),
      ]),
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
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      builder: (context, hovered, pressed, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: ShapeDecoration(
          color: hovered ? c.surface : c.surface.withValues(alpha: c.isDark ? 0.55 : 0.72),
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(9),
            side: BorderSide(color: hovered ? c.inkFaint.withValues(alpha: 0.6) : c.line),
          ),
          shadows: hovered ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))] : null,
        ),
        child: child,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: c.ink), const SizedBox(width: 6)],
        Text(label, style: AppTheme.sans(fontSize: 12.5, fontWeight: FontWeight.w500, color: c.ink)),
        if (trailing != null) ...[const SizedBox(width: 5), trailing!],
      ]),
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
  const PageTitle(this.title, {super.key, this.onEdit, this.onShare, this.leading});
  final String title;
  final VoidCallback? onEdit;
  final VoidCallback? onShare;
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
        if (onShare != null) RoundIconButton(icon: Ic.share, tooltip: 'Share', onTap: onShare!),
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
      child: Pressable(
        onTap: onTap,
        scale: 0.88,
        builder: (context, hovered, pressed, child) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: size,
          height: size,
          decoration: ShapeDecoration(
            color: hovered ? c.surface : c.surfaceMuted,
            shape: CircleBorder(side: BorderSide(color: c.line)),
            shadows: hovered ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          child: child,
        ),
        child: Icon(icon, size: size * 0.5, color: c.ink),
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final (i, t) in tabs.indexed)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Pressable(
              scale: 0.97,
              onTap: () => onSelect(i),
              builder: (context, hovered, pressed, child) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: i == selected ? 10 : 8),
                decoration: BoxDecoration(
                  color: i == selected ? c.surface : (hovered ? c.selection : c.surfaceMuted),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.md)),
                  border: Border(
                    top: BorderSide(color: c.line),
                    left: BorderSide(color: c.line),
                    right: BorderSide(color: c.line),
                  ),
                ),
                child: child,
              ),
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
      ]),
    );
  }
}

/// Simple segmented control used in settings and the reader.
class Segmented<T> extends StatefulWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged, this.expand = false});
  final List<(T, String, IconData?)> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Stretch segments to fill the available width.
  final bool expand;

  @override
  State<Segmented<T>> createState() => _SegmentedState<T>();
}

/// iOS-style segmented control with a thumb that slides between segments.
class _SegmentedState<T> extends State<Segmented<T>> {
  final _keys = <GlobalKey>[];
  final _rowKey = GlobalKey();
  Rect? _thumb;

  @override
  void initState() {
    super.initState();
    _syncKeys();
  }

  @override
  void didUpdateWidget(covariant Segmented<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncKeys();
  }

  void _syncKeys() {
    while (_keys.length < widget.options.length) {
      _keys.add(GlobalKey());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final i = widget.options.indexWhere((o) => o.$1 == widget.value);
    final row = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    final seg = i < 0 ? null : _keys[i].currentContext?.findRenderObject() as RenderBox?;
    if (row == null || seg == null || !row.hasSize || !seg.hasSize) return;
    final r = seg.localToGlobal(Offset.zero, ancestor: row) & seg.size;
    if (r != _thumb) setState(() => _thumb = r);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    Widget segment(int i) {
      final o = widget.options[i];
      final on = o.$1 == widget.value;
      return GestureDetector(
        key: _keys[i],
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (on) return;
          Haptics.selection();
          widget.onChanged(o.$1);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              if (o.$3 != null) ...[Icon(o.$3, size: 14, color: on ? c.ink : c.inkMuted), const SizedBox(width: 6)],
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: AppTheme.sans(fontSize: 12.5, fontWeight: on ? FontWeight.w600 : FontWeight.w500, color: on ? c.ink : c.inkMuted),
                child: Text(o.$2),
              ),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(
        color: c.surfaceMuted,
        shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(Radii.md), side: BorderSide(color: c.line)),
      ),
      child: Stack(children: [
        if (_thumb != null)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: const Cubic(0.3, 1.25, 0.5, 1),
            left: _thumb!.left,
            top: _thumb!.top,
            width: _thumb!.width,
            height: _thumb!.height,
            child: Container(
              decoration: ShapeDecoration(
                color: c.isDark ? c.chip : c.surface,
                shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(Radii.sm + 1)),
                shadows: [BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? 0.3 : 0.08), blurRadius: 5, offset: const Offset(0, 1))],
              ),
            ),
          ),
        Row(
          key: _rowKey,
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.options.length; i++) widget.expand ? Expanded(child: segment(i)) : segment(i),
          ],
        ),
      ]),
    );
  }
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

/// Shows a Sileo-style toast. Kind is inferred from wording unless given.
void toast(BuildContext context, String message, {ToastKind? kind, String? description}) {
  final low = message.toLowerCase();
  final inferred = kind ??
      (low.contains('fail') || low.contains('could not') || low.contains('error') || low.contains('not saved')
          ? ToastKind.error
          : (low.contains('added') || low.contains('saved') || low.contains('sent') || low.contains('uploaded') || low.contains('copied') || low.contains('deleted') || low.contains('created'))
              ? ToastKind.success
              : ToastKind.info);
  Toasts.show(context, message, kind: inferred, description: description);
}
