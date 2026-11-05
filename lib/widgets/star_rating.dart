import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';

const _gold = Color(0xFFE0A526);

/// Five tappable stars. Tapping the current value clears it.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.onChanged, this.size = 20, this.spacing = 2});

  final int value;
  final ValueChanged<int>? onChanged;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Padding(
          padding: EdgeInsets.only(right: i == 5 ? 0 : spacing),
          child: Semantics(
            button: onChanged != null,
            label: '$i star${i == 1 ? '' : 's'}',
            selected: i <= value,
            child: Pressable(
              scale: 0.85,
              onTap: onChanged == null ? null : () => onChanged!(i == value ? 0 : i),
              child: Icon(i <= value ? Ic.starFill : Ic.star, size: size, color: i <= value ? _gold : c.inkFaint),
            ),
          ),
        ),
    ]);
  }
}

/// Compact read-only community rating: "4.3 ★ (12)".
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.average, required this.count});
  final double? average;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (average == null || count == 0) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Ic.starFill, size: 13, color: _gold),
      const SizedBox(width: 3),
      Text(average!.toStringAsFixed(1), style: AppTheme.sans(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink)),
      const SizedBox(width: 3),
      Text('($count)', style: AppTheme.sans(fontSize: 12, color: c.inkMuted)),
    ]);
  }
}
