import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';

/// Pinda — Coming Soon placeholder.
class PindaPage extends StatelessWidget {
  const PindaPage({super.key, this.conversationId});
  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon container
            Container(
              width: 88,
              height: 88,
              decoration: ShapeDecoration(
                color: c.chip,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Center(
                child: Icon(Ic.pinda, size: 40, color: c.inkMuted),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Pinda is coming soon',
              style: AppTheme.serif(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: c.ink,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 360,
              child: Text(
                'Your AI research companion that reads your library and answers questions grounded in your own materials.',
                style: AppTheme.sans(
                  fontSize: 15,
                  color: c.inkMuted,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            // Feature pills
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _FeaturePill(icon: Ic.library, label: 'Library-grounded', colors: c),
                _FeaturePill(icon: Ic.chatCircle, label: 'Conversational', colors: c),
                _FeaturePill(icon: Ic.scale, label: 'Fact-checked', colors: c),
                _FeaturePill(icon: Ic.lightning, label: 'Powered by Claude', colors: c),
              ],
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: ShapeDecoration(
                color: c.selection,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Ic.info, size: 16, color: c.ink),
                  const SizedBox(width: 10),
                  Text(
                    'We\'ll notify you when Pinda is ready.',
                    style: AppTheme.sans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.colors,
  });
  final IconData icon;
  final String label;
  final DscvrColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.line),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.inkMuted),
          const SizedBox(width: 7),
          Text(
            label,
            style: AppTheme.sans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
