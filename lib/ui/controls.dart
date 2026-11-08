import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/motion.dart';
import 'package:dscvr/ui/spinner.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum BtnVariant { primary, secondary, ghost, danger }

enum BtnSize { sm, md, lg }

/// Button with spring press, hover tint and optional loading state.
///
/// Parameter names mirror Material's FilledButton / OutlinedButton /
/// TextButton (`onPressed`, `child`, `icon`, `label`) so call sites read
/// the same. `style` is accepted for compatibility and ignored.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.variant = BtnVariant.primary,
    this.size = BtnSize.md,
    this.loading = false,
    this.expand = false,
    this.style,
  });

  const AppButton.primary({super.key, required this.onPressed, this.child, this.label, this.icon, this.size = BtnSize.md, this.loading = false, this.expand = false, this.style})
      : variant = BtnVariant.primary;
  const AppButton.secondary({super.key, required this.onPressed, this.child, this.label, this.icon, this.size = BtnSize.md, this.loading = false, this.expand = false, this.style})
      : variant = BtnVariant.secondary;
  const AppButton.ghost({super.key, required this.onPressed, this.child, this.label, this.icon, this.size = BtnSize.md, this.loading = false, this.expand = false, this.style})
      : variant = BtnVariant.ghost;
  const AppButton.danger({super.key, required this.onPressed, this.child, this.label, this.icon, this.size = BtnSize.md, this.loading = false, this.expand = false, this.style})
      : variant = BtnVariant.danger;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? label;
  final Widget? icon;
  final BtnVariant variant;
  final BtnSize size;
  final bool loading;
  final bool expand;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null && !loading;
    final (bg, fg, border, hover) = switch (variant) {
      BtnVariant.primary => (c.ink, c.inverseInk, Colors.transparent, c.ink.withValues(alpha: 0.88)),
      BtnVariant.secondary => (c.surface, c.ink, c.line, c.surfaceMuted),
      BtnVariant.ghost => (Colors.transparent, c.ink, Colors.transparent, c.selection),
      BtnVariant.danger => (c.danger, Colors.white, Colors.transparent, c.danger.withValues(alpha: 0.88)),
    };
    final (h, padX, font) = switch (size) {
      BtnSize.sm => (32.0, 12.0, 13.0),
      BtnSize.md => (40.0, 16.0, 14.0),
      BtnSize.lg => (48.0, 20.0, 15.0),
    };
    final text = label ?? child;
    return Opacity(
      opacity: enabled || loading ? 1 : 0.45,
      child: Pressable(
        enabled: enabled,
        onTap: enabled ? onPressed : null,
        builder: (context, hovered, pressed, content) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: h,
          padding: EdgeInsets.symmetric(horizontal: variant == BtnVariant.ghost ? padX * 0.7 : padX),
          decoration: ShapeDecoration(
            color: hovered && enabled ? hover : bg,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(h * 0.32),
              side: BorderSide(color: border),
            ),
            shadows: variant == BtnVariant.primary && enabled
                ? [BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? 0.3 : 0.12), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: content,
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              Spinner(size: font + 2, color: fg)
            else ...[
              if (icon != null) IconTheme(data: IconThemeData(color: fg, size: font + 2), child: icon!),
              if (icon != null && text != null) const SizedBox(width: 8),
              if (text != null)
                DefaultTextStyle(
                  style: AppTheme.sans(fontSize: font, fontWeight: FontWeight.w600, color: fg),
                  child: text,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Icon button with hover circle and spring press. Mirrors IconButton's
/// common parameters; extras are accepted and ignored.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.size = 36,
    this.filled = false,
    this.visualDensity,
    this.padding,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final double size;
  final bool filled;
  final VisualDensity? visualDensity;
  final EdgeInsetsGeometry? padding;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    final dim = visualDensity == VisualDensity.compact ? size - 6 : size;
    Widget w = Pressable(
      enabled: enabled,
      scale: 0.9,
      onTap: onPressed,
      semanticLabel: tooltip,
      builder: (context, hovered, pressed, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: dim,
        height: dim,
        decoration: ShapeDecoration(
          color: filled
              ? (enabled ? c.ink : c.surfaceMuted)
              : (hovered && enabled ? c.selection : Colors.transparent),
          shape: const CircleBorder(),
        ),
        child: child,
      ),
      child: Center(
        child: IconTheme(
          data: IconThemeData(
            size: 19,
            color: filled ? (enabled ? c.inverseInk : c.inkFaint) : (enabled ? c.inkMuted : c.inkFaint),
          ),
          child: icon,
        ),
      ),
    );
    if (tooltip != null) w = Tooltip(message: tooltip!, child: w);
    return w;
  }
}

/// Selectable pill used for subjects, roles and interests.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.selected, required this.onTap, this.leading});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      selected: selected,
      builder: (context, hovered, pressed, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        // At least 36px tall, so it's an easy target on touch screens.
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: ShapeDecoration(
          color: selected ? c.ink : (hovered ? c.selection : c.chip),
          shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: child,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leading != null) ...[leading!, const SizedBox(width: 7)],
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? c.inverseInk : c.ink),
          child: Text(label),
        ),
      ]),
    );
  }
}

/// Thin-track slider with a soft thumb, iOS style.
class AppSlider extends StatefulWidget {
  const AppSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.label,
    this.valueLabel,
    this.step,
  });
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  /// Read by screen readers, e.g. "Text size".
  final String? label;

  /// How the value is announced, e.g. (v) => "${(v * 100).round()} percent".
  final String Function(double value)? valueLabel;

  /// Keyboard and screen-reader step; defaults to a tenth of the range.
  final double? step;

  @override
  State<AppSlider> createState() => _AppSliderState();
}

class _AppSliderState extends State<AppSlider> {
  bool _focused = false;

  double get _step => widget.step ?? (widget.max - widget.min) / 10;

  void _nudge(double d) => widget.onChanged((widget.value + d).clamp(widget.min, widget.max));

  String _say(double v) => widget.valueLabel?.call(v) ?? v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = widget.value, min = widget.min, max = widget.max;
    return Semantics(
      slider: true,
      label: widget.label,
      value: _say(value),
      increasedValue: _say((value + _step).clamp(min, max)),
      decreasedValue: _say((value - _step).clamp(min, max)),
      onIncrease: () => _nudge(_step),
      onDecrease: () => _nudge(-_step),
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowRight): _Nudge(1),
          SingleActivator(LogicalKeyboardKey.arrowUp): _Nudge(1),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _Nudge(-1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _Nudge(-1),
        },
        actions: {
          _Nudge: CallbackAction<_Nudge>(onInvoke: (i) {
            _nudge(i.dir * _step);
            return null;
          }),
        },
        child: ExcludeSemantics(
          child: LayoutBuilder(builder: (context, box) {
            const thumb = 22.0;
            final w = box.maxWidth;
            final t = ((value - min) / (max - min)).clamp(0.0, 1.0);
            void set(double dx) {
              final v = min + ((dx - thumb / 2) / (w - thumb)).clamp(0.0, 1.0) * (max - min);
              if ((v - value).abs() > 0.001) widget.onChanged(v);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => set(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => set(d.localPosition.dx),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: SizedBox(
                  height: 32,
                  child: Stack(alignment: Alignment.centerLeft, children: [
                    Container(height: 4, decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2))),
                    Container(
                      width: thumb / 2 + t * (w - thumb),
                      height: 4,
                      decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(2)),
                    ),
                    Positioned(
                      left: t * (w - thumb),
                      child: Container(
                        width: thumb,
                        height: thumb,
                        decoration: BoxDecoration(
                          color: c.isDark ? c.ink : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _focused ? const Color(0xFF7AA7FF) : c.line, width: _focused ? 2.5 : 1),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Nudge extends Intent {
  const _Nudge(this.dir);
  final int dir;
}

/// iOS-style on/off switch. Announced as a toggle with its label.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged, this.label});
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      label: label,
      child: Pressable(
        enabled: enabled,
        scale: 0.96,
        onTap: () => onChanged?.call(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 46,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? c.ink : c.chip,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: value ? c.ink : c.line),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? c.inverseInk : (enabled ? c.surface : c.surfaceMuted),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3, offset: const Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

/// Text field with its label above (no Material floating label).
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.autofocus = false,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.onChanged,
    this.prefixIcon,
    this.suffix,
    this.style,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool autofocus;
  final int? minLines;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffix;
  final TextStyle? style;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (label != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 7, left: 2),
          child: Text(label!, style: AppTheme.sans(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.inkMuted)),
        ),
      TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        style: style ?? AppTheme.sans(fontSize: 14.5, color: c.ink),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: prefixIcon == null ? null : Padding(padding: const EdgeInsets.only(left: 12, right: 8), child: prefixIcon),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
          suffixIcon: suffix,
        ),
      ),
    ]);
  }
}


/// A large selectable row with a title and subtitle, used for single-choice
/// lists (field of study, plan options). Announced as a selectable button.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({super.key, required this.title, this.subtitle, required this.selected, required this.onTap, this.leading});
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      selected: selected,
      semanticLabel: subtitle == null ? title : '$title. $subtitle',
      builder: (context, hovered, pressed, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: ShapeDecoration(
          color: selected ? c.selection : (hovered ? c.surfaceMuted : c.surface),
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: selected ? c.ink : c.line, width: selected ? 1.5 : 1),
          ),
        ),
        child: child,
      ),
      child: ExcludeSemantics(
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTheme.sans(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppTheme.sans(fontSize: 13, color: c.inkMuted)),
              ],
            ]),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? c.ink : Colors.transparent,
              border: Border.all(color: selected ? c.ink : c.inkFaint, width: 1.5),
            ),
            child: selected ? Icon(Ic.check, size: 13, color: c.inverseInk) : null,
          ),
        ]),
      ),
    );
  }
}
