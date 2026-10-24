import 'dart:async';

import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/motion.dart';
import 'package:dscvr/ui/spinner.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';

enum ToastKind { success, error, info, warning, loading }

/// A live toast that can be updated or dismissed (e.g. loading -> success).
class ToastHandle {
  ToastHandle._(this._id, this._host);
  final int _id;
  final ToasterState _host;

  void update(String title, {String? description, ToastKind? kind, Duration? duration}) =>
      _host._update(_id, title: title, description: description, kind: kind, duration: duration);

  void dismiss() => _host._dismiss(_id);
}

/// Sileo-style notifications: dark pills that spring in from the top,
/// morph open to reveal detail, stack, pause on hover and swipe away.
class Toasts {
  Toasts._();

  static ToasterState? _fallback;

  static ToasterState? _host(BuildContext context) =>
      context.findAncestorStateOfType<ToasterState>() ?? _fallback;

  static ToastHandle? show(
    BuildContext context,
    String title, {
    String? description,
    ToastKind kind = ToastKind.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final host = _host(context);
    if (host == null) return null;
    return host._add(_ToastData(
      title: title,
      description: description,
      kind: kind,
      duration: duration ?? (kind == ToastKind.loading ? null : const Duration(milliseconds: 3800)),
      actionLabel: actionLabel,
      onAction: onAction,
    ));
  }

  static ToastHandle? success(BuildContext c, String title, {String? description}) =>
      show(c, title, description: description, kind: ToastKind.success);
  static ToastHandle? error(BuildContext c, String title, {String? description}) =>
      show(c, title, description: description, kind: ToastKind.error);

  /// Shows a loading toast that resolves to success or error.
  static Future<T> promise<T>(
    BuildContext context,
    Future<T> future, {
    required String loading,
    required String Function(T value) success,
    String Function(Object error)? error,
  }) async {
    final h = show(context, loading, kind: ToastKind.loading);
    try {
      final v = await future;
      h?.update(success(v), kind: ToastKind.success, duration: const Duration(milliseconds: 3200));
      return v;
    } catch (e) {
      h?.update(error?.call(e) ?? 'Something went wrong', kind: ToastKind.error, duration: const Duration(seconds: 5));
      rethrow;
    }
  }
}

class _ToastData {
  _ToastData({
    required this.title,
    required this.kind,
    this.description,
    this.duration,
    this.actionLabel,
    this.onAction,
  });
  String title;
  String? description;
  ToastKind kind;
  Duration? duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  int id = 0;
  int version = 0;
}

/// Hosts toasts above the whole app. Placed in MaterialApp.builder.
class Toaster extends StatefulWidget {
  const Toaster({super.key, required this.child});
  final Widget child;

  @override
  State<Toaster> createState() => ToasterState();
}

class ToasterState extends State<Toaster> {
  final List<_ToastData> _toasts = [];
  int _next = 1;

  @override
  void initState() {
    super.initState();
    Toasts._fallback = this;
  }

  @override
  void dispose() {
    if (Toasts._fallback == this) Toasts._fallback = null;
    super.dispose();
  }

  ToastHandle _add(_ToastData t) {
    t.id = _next++;
    setState(() {
      _toasts.insert(0, t);
      if (_toasts.length > 4) _toasts.removeLast();
    });
    if (t.kind == ToastKind.error) {
      Haptics.medium();
    } else {
      Haptics.light();
    }
    return ToastHandle._(t.id, this);
  }

  void _update(int id, {required String title, String? description, ToastKind? kind, Duration? duration}) {
    final i = _toasts.indexWhere((t) => t.id == id);
    if (i < 0) return;
    setState(() {
      final t = _toasts[i];
      t.title = title;
      t.description = description;
      if (kind != null) t.kind = kind;
      t.duration = duration ?? const Duration(milliseconds: 3600);
      t.version++;
    });
    if (kind == ToastKind.success) Haptics.success();
  }

  void _dismiss(int id) {
    if (!mounted) return;
    setState(() => _toasts.removeWhere((t) => t.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + (context.isCompact ? 8 : 18);
    return Stack(children: [
      widget.child,
      Positioned(
        top: top,
        left: 12,
        right: 12,
        child: IgnorePointer(
          ignoring: _toasts.isEmpty,
          child: Material(
            type: MaterialType.transparency,
            child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 420,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
                for (var i = _toasts.length - 1; i >= 0; i--)
                  _ToastView(
                    key: ValueKey(_toasts[i].id),
                    data: _toasts[i],
                    depth: i,
                    onDismiss: () => _dismiss(_toasts[i].id),
                  ),
              ]),
            ),
          ),
          ),
        ),
      ),
    ]);
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({super.key, required this.data, required this.depth, required this.onDismiss});
  final _ToastData data;
  final int depth;
  final VoidCallback onDismiss;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController.unbounded(vsync: this, value: 0);
  late final AnimationController _depth = AnimationController.unbounded(vsync: this, value: widget.depth.toDouble());
  Timer? _timer;
  bool _expanded = false;
  bool _hovered = false;
  double _drag = 0;
  bool _leaving = false;
  int _seenVersion = -1;

  @override
  void initState() {
    super.initState();
    springTo(_enter, 1, spring: Springs.bouncy);
    // The Sileo "morph": arrive as a compact pill, then open up.
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted && widget.data.description != null) setState(() => _expanded = true);
    });
    _arm();
  }

  @override
  void didUpdateWidget(covariant _ToastView old) {
    super.didUpdateWidget(old);
    if (old.depth != widget.depth) springTo(_depth, widget.depth.toDouble(), spring: Springs.gentle);
    if (_seenVersion != widget.data.version) _arm();
    if (widget.data.description != null && !_expanded) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _expanded = true);
      });
    }
  }

  void _arm() {
    _seenVersion = widget.data.version;
    _timer?.cancel();
    final d = widget.data.duration;
    if (d == null || _hovered) return;
    _timer = Timer(d, _leave);
  }

  Future<void> _leave() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    await springTo(_enter, 0, spring: Springs.snappy);
    widget.onDismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _enter.dispose();
    _depth.dispose();
    super.dispose();
  }

  Color _accent(DscvrColors c) => switch (widget.data.kind) {
        ToastKind.success => const Color(0xFF4CC38A),
        ToastKind.error => const Color(0xFFF0705A),
        ToastKind.warning => const Color(0xFFF2B33D),
        ToastKind.info => const Color(0xFF7AA7FF),
        ToastKind.loading => c.isDark ? c.inverseInk : c.inverseInk,
      };

  IconData get _icon => switch (widget.data.kind) {
        ToastKind.success => Ic.check,
        ToastKind.error => Ic.close,
        ToastKind.warning => Ic.warning,
        ToastKind.info => Ic.info,
        ToastKind.loading => Ic.info,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = widget.data;
    // Pills are always dark: ink on light theme, raised charcoal on dark.
    final bg = c.isDark ? const Color(0xFF2B2724) : const Color(0xFF1E1A17);
    const fg = Color(0xFFF7F2EC);
    final accent = _accent(c);

    final pill = MouseRegion(
      onEnter: (_) {
        _hovered = true;
        _timer?.cancel();
      },
      onExit: (_) {
        _hovered = false;
        _arm();
      },
      child: GestureDetector(
        onVerticalDragUpdate: (e) => setState(() => _drag = (_drag + e.delta.dy).clamp(-120, 24)),
        onVerticalDragEnd: (e) {
          if (_drag < -28 || (e.primaryVelocity ?? 0) < -400) {
            _leave();
          } else {
            setState(() => _drag = 0);
          }
        },
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 420),
          curve: const Cubic(0.34, 1.36, 0.64, 1),
          alignment: Alignment.topCenter,
          child: Container(
            constraints: BoxConstraints(minWidth: 0, maxWidth: _expanded ? 420 : 360),
            padding: EdgeInsets.fromLTRB(10, 9, 12, _expanded && d.description != null ? 12 : 9),
            decoration: ShapeDecoration(
              color: bg,
              shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(_expanded ? 20 : 24)),
              shadows: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 10)),
                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4, offset: const Offset(0, 1)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: child)),
                  child: Container(
                    key: ValueKey(d.kind),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: d.kind == ToastKind.loading ? Colors.transparent : accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: d.kind == ToastKind.loading
                        ? const Padding(padding: EdgeInsets.all(3), child: Spinner(size: 16, color: fg))
                        : Icon(_icon, size: 13, color: accent),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(d.title,
                        key: ValueKey(d.title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg, height: 1.3)),
                  ),
                ),
                if (d.actionLabel != null) ...[
                  const SizedBox(width: 12),
                  Pressable(
                    onTap: () {
                      d.onAction?.call();
                      _leave();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: ShapeDecoration(
                        color: fg.withValues(alpha: 0.12),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(d.actionLabel!,
                          style: AppTheme.sans(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
                    ),
                  ),
                ],
              ]),
              if (_expanded && d.description != null)
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 4, right: 4),
                  child: Text(d.description!,
                      style: AppTheme.sans(fontSize: 12.5, color: fg.withValues(alpha: 0.72), height: 1.45)),
                ),
            ]),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _depth]),
      builder: (context, child) {
        final t = _enter.value;
        final depth = _depth.value;
        final y = -64 * (1 - t) + depth * 10 + _drag;
        final scale = (0.86 + 0.14 * t) * (1 - 0.05 * depth);
        final opacity = (t.clamp(0.0, 1.0)) * (depth > 2.5 ? 0 : 1 - depth * 0.18);
        return IgnorePointer(
          ignoring: depth > 0.5,
          child: Transform.translate(
            offset: Offset(0, y),
            child: Transform.scale(scale: scale, alignment: Alignment.topCenter, child: Opacity(opacity: opacity.clamp(0, 1), child: child)),
          ),
        );
      },
      child: pill,
    );
  }
}
