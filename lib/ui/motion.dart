import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Motion primitives shared by the DSCVR UI kit.
///
/// Everything interactive moves on springs rather than fixed curves, which
/// is what makes the UI feel native on iOS, Android and the web alike.
class Springs {
  Springs._();

  /// Snappy, no overshoot: menus, popovers, press feedback.
  static const snappy = SpringDescription(mass: 1, stiffness: 520, damping: 40);

  /// Slight overshoot: toasts and sheets arriving.
  static const bouncy = SpringDescription(mass: 1, stiffness: 380, damping: 24);

  /// Soft, for larger layout changes.
  static const gentle = SpringDescription(mass: 1, stiffness: 220, damping: 26);
}

/// Drives an [AnimationController] toward [target] using a spring.
TickerFuture springTo(AnimationController c, double target,
    {SpringDescription spring = Springs.snappy, double velocity = 0}) {
  return c.animateWith(SpringSimulation(spring, c.value, target, velocity));
}

bool get isTouchPlatform =>
    defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;

/// Haptics that are silent on platforms without them.
class Haptics {
  Haptics._();
  static void selection() {
    if (isTouchPlatform && !kIsWeb) HapticFeedback.selectionClick();
  }

  static void light() {
    if (isTouchPlatform && !kIsWeb) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (isTouchPlatform && !kIsWeb) HapticFeedback.mediumImpact();
  }

  static void success() {
    if (isTouchPlatform && !kIsWeb) HapticFeedback.mediumImpact();
  }
}

/// Makes any widget pressable with a spring scale-down, hover state and
/// pointer cursor. Replaces Material ink ripples across the app.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTapUp,
    this.scale = 0.97,
    this.haptic = true,
    this.builder,
    this.semanticLabel,
    this.enabled = true,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPress;
  final GestureTapUpCallback? onSecondaryTapUp;
  final double scale;
  final bool haptic;
  final bool enabled;
  final String? semanticLabel;

  /// For toggles and chips: announced as selected or not by screen readers.
  final bool? selected;

  /// Optional builder receiving hover/pressed state for custom styling.
  final Widget Function(BuildContext context, bool hovered, bool pressed, Widget child)? builder;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: 1);
  bool _hover = false;
  bool _pressed = false;

  bool get _active => widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _down() {
    if (!_active) return;
    setState(() => _pressed = true);
    if (!_still) springTo(_c, widget.scale);
  }

  void _up() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    springTo(_c, 1, spring: Springs.bouncy);
  }

  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    Widget content = widget.builder?.call(context, _hover, _pressed, widget.child) ?? widget.child;
    if (_focused) {
      // Keyboard focus ring (web/desktop accessibility).
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: const Color(0xFF7AA7FF).withValues(alpha: 0.9), width: 2),
          ),
        ),
        child: content,
      );
    }
    return Semantics(
      button: _active,
      enabled: _active,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: _active,
        mouseCursor: _active ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _down(),
          onTapUp: (_) => _up(),
          onTapCancel: _up,
          onTap: !_active
              ? null
              : () {
                  if (widget.haptic) Haptics.selection();
                  widget.onTap?.call();
                },
          onLongPressStart: widget.onLongPress == null
              ? null
              : (d) {
                  _up();
                  Haptics.medium();
                  widget.onLongPress!(d);
                },
          onSecondaryTapUp: widget.onSecondaryTapUp,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Transform.scale(scale: _c.value, child: child),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts its child in once, with an optional stagger delay.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child, this.delay = Duration.zero, this.offset = 10});
  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: const Cubic(0.2, 0.8, 0.2, 1));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - _t.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

/// iOS-style bouncing scroll everywhere. Touch, stylus and trackpad drag;
/// the mouse is left for text selection (wheel scrolling still works).
class DscvrScrollBehavior extends ScrollBehavior {
  const DscvrScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
