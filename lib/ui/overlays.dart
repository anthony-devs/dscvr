import 'dart:ui' as ui;

import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/motion.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared surface
// ─────────────────────────────────────────────────────────────────────────────

/// Elevated, slightly translucent surface used by popovers, menus, dialogs
/// and sheets. Superellipse corners (the iOS "squircle").
ShapeDecoration floatingSurface(DscvrColors c, {double radius = 14, bool translucent = true}) => ShapeDecoration(
      color: translucent ? c.surface.withValues(alpha: c.isDark ? 0.92 : 0.94) : c.surface,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: c.line.withValues(alpha: c.isDark ? 0.9 : 0.8)),
      ),
      shadows: [
        BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? 0.45 : 0.10), blurRadius: 32, offset: const Offset(0, 14)),
        BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? 0.3 : 0.06), blurRadius: 6, offset: const Offset(0, 2)),
      ],
    );

/// Global rect of the widget that owns [context]; used to anchor popovers.
Rect anchorRectOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// True when menus should appear as bottom action sheets (phones).
bool useSheets(BuildContext context) => context.isCompact;

// ─────────────────────────────────────────────────────────────────────────────
// Popover
// ─────────────────────────────────────────────────────────────────────────────

class _PopoverRoute<T> extends PopupRoute<T> {
  _PopoverRoute({required this.anchor, required this.builder, this.width, this.matchAnchorWidth = false});

  final Rect anchor;
  final WidgetBuilder builder;
  final double? width;
  final bool matchAnchorWidth;

  @override
  Color? get barrierColor => Colors.transparent;
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => 'Dismiss';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final screen = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final w = matchAnchorWidth ? anchor.width.clamp(200.0, 420.0) : (width ?? 240.0);
    final spaceBelow = screen.height - anchor.bottom - pad.bottom - 12;
    final spaceAbove = anchor.top - pad.top - 12;
    final below = spaceBelow >= 220 || spaceBelow >= spaceAbove;
    final maxH = (below ? spaceBelow : spaceAbove).clamp(120.0, 440.0);
    var left = anchor.left;
    if (left + w > screen.width - 12) left = (anchor.right - w).clamp(12.0, screen.width - w - 12);
    left = left.clamp(12.0, (screen.width - w - 12).clamp(12.0, double.infinity));

    final curved = CurvedAnimation(parent: animation, curve: const Cubic(0.2, 0.9, 0.25, 1.05), reverseCurve: Curves.easeIn);
    final c = context.colors;
    return Stack(children: [
      Positioned(
        left: left,
        width: w,
        top: below ? anchor.bottom + 6 : null,
        bottom: below ? null : screen.height - anchor.top + 6,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: AnimatedBuilder(
            animation: curved,
            builder: (context, child) => Opacity(
              opacity: animation.value.clamp(0, 1),
              child: Transform.scale(
                scale: 0.94 + 0.06 * curved.value,
                alignment: below ? Alignment.topLeft : Alignment.bottomLeft,
                child: Transform.translate(offset: Offset(0, (below ? -6 : 6) * (1 - curved.value)), child: child),
              ),
            ),
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Material(
                  type: MaterialType.transparency,
                  child: DecoratedBox(decoration: floatingSurface(c), child: builder(context)),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

Future<T?> showPopover<T>(BuildContext context,
        {required Rect anchor, required WidgetBuilder builder, double? width, bool matchAnchorWidth = false}) =>
    Navigator.of(context, rootNavigator: true).push(_PopoverRoute<T>(anchor: anchor, builder: builder, width: width, matchAnchorWidth: matchAnchorWidth));

// ─────────────────────────────────────────────────────────────────────────────
// Menus
// ─────────────────────────────────────────────────────────────────────────────

class MenuEntry<T> {
  const MenuEntry({
    required this.value,
    required this.label,
    this.icon,
    this.leading,
    this.checked = false,
    this.destructive = false,
    this.subtitle,
  }) : divider = false;

  const MenuEntry.divider()
      : value = null,
        label = '',
        icon = null,
        leading = null,
        checked = false,
        destructive = false,
        subtitle = null,
        divider = true;

  final T? value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final bool checked;
  final bool destructive;
  final bool divider;
}

/// Shows a menu anchored to [anchor] on wide screens, or as an action
/// sheet on phones.
Future<T?> showAppMenu<T>(
  BuildContext context, {
  required Rect anchor,
  required List<MenuEntry<T>> entries,
  String? title,
  double width = 240,
  bool matchAnchorWidth = false,
}) {
  if (useSheets(context)) {
    return showAppSheet<T>(context, builder: (ctx) => _ActionSheet<T>(entries: entries, title: title));
  }
  return showPopover<T>(
    context,
    anchor: anchor,
    width: width,
    matchAnchorWidth: matchAnchorWidth,
    builder: (ctx) => _MenuList<T>(entries: entries),
  );
}

class _MenuList<T> extends StatefulWidget {
  const _MenuList({required this.entries});
  final List<MenuEntry<T>> entries;

  @override
  State<_MenuList<T>> createState() => _MenuListState<T>();
}

class _MenuListState<T> extends State<_MenuList<T>> {
  int _focus = -1;

  List<int> get _selectable => [
        for (var i = 0; i < widget.entries.length; i++)
          if (!widget.entries[i].divider) i
      ];

  void _move(int delta) {
    final s = _selectable;
    if (s.isEmpty) return;
    final at = s.indexOf(_focus);
    setState(() => _focus = s[((at < 0 ? (delta > 0 ? -1 : 0) : at) + delta) % s.length]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (_focus >= 0) Navigator.pop(context, widget.entries[_focus].value);
        },
      },
      child: Focus(
        autofocus: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < widget.entries.length; i++)
              if (widget.entries[i].divider)
                Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Divider(height: 1, color: c.line))
              else
                _MenuRow<T>(
                  entry: widget.entries[i],
                  focused: _focus == i,
                  onHover: (h) => setState(() => _focus = h ? i : (_focus == i ? -1 : _focus)),
                ),
          ]),
        ),
      ),
    );
  }
}

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({required this.entry, required this.focused, required this.onHover});
  final MenuEntry<T> entry;
  final bool focused;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = entry.destructive ? c.danger : c.ink;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.selection();
          Navigator.pop(context, entry.value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: ShapeDecoration(
            color: focused ? (entry.destructive ? c.danger.withValues(alpha: 0.1) : c.selection) : Colors.transparent,
            shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(9)),
          ),
          child: Row(children: [
            if (entry.leading != null) ...[entry.leading!, const SizedBox(width: 10)],
            if (entry.icon != null) ...[
              Icon(entry.icon, size: 16, color: entry.destructive ? c.danger : c.inkMuted),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(fontSize: 13.5, fontWeight: FontWeight.w500, color: color)),
                if (entry.subtitle != null)
                  Text(entry.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall),
              ]),
            ),
            if (entry.checked) ...[const SizedBox(width: 8), Icon(Ic.check, size: 15, color: c.ink)],
          ]),
        ),
      ),
    );
  }
}

class _ActionSheet<T> extends StatelessWidget {
  const _ActionSheet({required this.entries, this.title});
  final List<MenuEntry<T>> entries;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final groups = <List<MenuEntry<T>>>[[]];
    for (final e in entries) {
      if (e.divider) {
        groups.add([]);
      } else {
        groups.last.add(e);
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Text(title!, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
          ),
        for (final g in groups.where((g) => g.isNotEmpty)) ...[
          Container(
            decoration: ShapeDecoration(
              color: c.surfaceMuted,
              shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Column(children: [
              for (final (i, e) in g.indexed) ...[
                if (i > 0) Divider(height: 1, indent: 48, color: c.line),
                Pressable(
                  scale: 0.985,
                  onTap: () => Navigator.pop(context, e.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      if (e.leading != null) ...[SizedBox(width: 20, child: e.leading), const SizedBox(width: 14)],
                      if (e.icon != null) ...[
                        Icon(e.icon, size: 19, color: e.destructive ? c.danger : c.ink),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Text(e.label,
                            style: AppTheme.sans(
                                fontSize: 15.5, fontWeight: FontWeight.w500, color: e.destructive ? c.danger : c.ink)),
                      ),
                      if (e.checked) Icon(Ic.check, size: 18, color: c.ink),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}

/// Wraps a trigger so tapping it opens a menu below it.
class MenuButton<T> extends StatelessWidget {
  const MenuButton({
    super.key,
    required this.entries,
    required this.onSelected,
    required this.child,
    this.title,
    this.width = 240,
    this.tooltip,
  });

  final List<MenuEntry<T>> Function() entries;
  final ValueChanged<T> onSelected;
  final Widget child;
  final String? title;
  final double width;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (ctx) {
      final trigger = Pressable(
        onTap: () async {
          final v = await showAppMenu<T>(ctx, anchor: anchorRectOf(ctx), entries: entries(), title: title, width: width);
          if (v != null) onSelected(v);
        },
        child: child,
      );
      return tooltip == null ? trigger : Tooltip(message: tooltip!, child: trigger);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Select
// ─────────────────────────────────────────────────────────────────────────────

class SelectOption<T> {
  const SelectOption(this.value, this.label, {this.leading, this.subtitle});
  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
}

/// Modern select: an input-like trigger that opens an anchored list
/// (or an action sheet on phones). Replaces DropdownButtonFormField.
class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.placeholder = 'Select',
    this.enabled = true,
  });

  final List<SelectOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? label;
  final String placeholder;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    SelectOption<T>? current;
    for (final o in options) {
      if (o.value == value) current = o;
    }
    final active = enabled && onChanged != null && options.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (label != null) FieldLabel(label!),
      Builder(
        builder: (ctx) => Pressable(
          scale: 0.99,
          enabled: active,
          onTap: !active
              ? null
              : () async {
                  final v = await showAppMenu<_Boxed<T>>(
                    ctx,
                    anchor: anchorRectOf(ctx),
                    matchAnchorWidth: true,
                    title: label,
                    entries: [
                      for (final o in options)
                        MenuEntry(value: _Boxed(o.value), label: o.label, leading: o.leading, subtitle: o.subtitle, checked: o.value == value),
                    ],
                  );
                  if (v != null) onChanged!(v.value);
                },
          builder: (context, hovered, pressed, child) => AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: ShapeDecoration(
              color: active ? c.surface : c.surfaceMuted,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(Radii.md),
                side: BorderSide(color: hovered && active ? c.inkFaint : c.line),
              ),
            ),
            child: child,
          ),
          child: Row(children: [
            if (current?.leading != null) ...[current!.leading!, const SizedBox(width: 8)],
            Expanded(
              child: Text(current?.label ?? placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sans(fontSize: 14, color: current == null || !active ? c.inkFaint : c.ink)),
            ),
            Icon(Ic.caretUpDown, size: 15, color: c.inkFaint),
          ]),
        ),
      ),
    ]);
  }
}

/// Lets null be a real, selectable option value.
class _Boxed<T> {
  const _Boxed(this.value);
  final T value;
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7, left: 2),
        child: Text(text, style: AppTheme.sans(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.colors.inkMuted)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheets and dialogs
// ─────────────────────────────────────────────────────────────────────────────

class _SheetRoute<T> extends PopupRoute<T> {
  _SheetRoute({required this.builder, required this.colors});
  final WidgetBuilder builder;
  final DscvrColors colors;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: colors.isDark ? 0.5 : 0.28);
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => 'Close';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 240);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return _SheetBody(animation: animation, child: builder(context));
  }
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final curved = CurvedAnimation(parent: widget.animation, curve: const Cubic(0.22, 1, 0.36, 1), reverseCurve: Curves.easeInCubic);
    final mq = MediaQuery.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => FractionalTranslation(
          translation: Offset(0, 1 - curved.value),
          child: Transform.translate(offset: Offset(0, _drag), child: child),
        ),
        child: GestureDetector(
          onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(0, 600)),
          onVerticalDragEnd: (d) {
            if (_drag > 110 || (d.primaryVelocity ?? 0) > 700) {
              Navigator.pop(context);
            } else {
              setState(() => _drag = 0);
            }
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: mq.size.height - mq.padding.top - 24, maxWidth: 640),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                decoration: ShapeDecoration(
                  color: c.surface,
                  shape: const RoundedSuperellipseBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                  shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30)],
                ),
                padding: EdgeInsets.only(bottom: mq.viewInsets.bottom + mq.padding.bottom),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 9, bottom: 12),
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  Flexible(child: widget.child),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogRoute<T> extends PopupRoute<T> {
  _DialogRoute({required this.builder, required this.maxWidth, required this.colors});
  final WidgetBuilder builder;
  final double maxWidth;
  final DscvrColors colors;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: colors.isDark ? 0.45 : 0.18);
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => 'Close';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildModalBarrier() => Stack(fit: StackFit.expand, children: [
        // Frosted backdrop behind dialogs.
        FadeTransition(
          opacity: animation!,
          child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6), child: const SizedBox.expand()),
        ),
        super.buildModalBarrier(),
      ]);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final c = context.colors;
    final curved = CurvedAnimation(parent: animation, curve: const Cubic(0.2, 0.9, 0.25, 1.08), reverseCurve: Curves.easeIn);
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom) + const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: curved,
          builder: (context, child) => Opacity(
            opacity: animation.value.clamp(0, 1),
            child: Transform.scale(scale: 0.95 + 0.05 * curved.value, child: child),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Material(
              type: MaterialType.transparency,
              child: DecoratedBox(
                decoration: floatingSurface(c, radius: 22, translucent: false),
                child: builder(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder}) =>
    Navigator.of(context, rootNavigator: true).push(_SheetRoute<T>(builder: builder, colors: context.colors));

Future<T?> showAppDialog<T>(BuildContext context, {required WidgetBuilder builder, double maxWidth = 480}) =>
    Navigator.of(context, rootNavigator: true).push(_DialogRoute<T>(builder: builder, maxWidth: maxWidth, colors: context.colors));

/// Bottom sheet on phones, centered dialog elsewhere.
Future<T?> showAdaptiveSheet<T>(BuildContext context, {required WidgetBuilder builder, double maxWidth = 520}) =>
    context.isCompact ? showAppSheet<T>(context, builder: builder) : showAppDialog<T>(context, builder: builder, maxWidth: maxWidth);
