import 'package:dscvr/data/api.dart';
import 'package:dscvr/models/plan.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/screens/library/shelf_page.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Plans and usage: the usage meter, the four plans, and checkout.
class PlansPage extends StatefulWidget {
  const PlansPage({super.key, this.reference});

  /// Paystack's payment reference when the user comes back from paying.
  final String? reference;

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  Plan? _busy;

  @override
  void initState() {
    super.initState();
    final plans = context.services.plans;
    plans.refresh(force: true);
    final ref = widget.reference;
    if (ref != null && ref.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final ok = await plans.verify(ref);
          if (mounted) toast(context, ok ? 'Payment received. Your plan is on.' : 'Payment is still processing. Your plan turns on once it clears.');
        } on ApiException catch (e) {
          if (mounted) toast(context, 'Could not confirm the payment', description: e.message);
        }
        if (mounted) context.go('/plans');
      });
    }
  }

  Future<void> _choose(Plan target, PlanInfo info) async {
    final plans = context.services.plans;
    if (!info.paymentsEnabled) {
      toast(context, 'Plans open soon', description: 'Payments are being switched on. Thanks for your patience.');
      return;
    }
    if (info.plan.isPaid && !info.cancelled) {
      final ok = await confirm(context,
          title: 'Switch to ${target.label}?',
          message: 'We stop renewing ${info.plan.label} and start ${target.label} now. You pay for ${target.label} from today.',
          action: 'Switch',
          destructive: false);
      if (!ok || !mounted) return;
    }
    setState(() => _busy = target);
    try {
      if (info.plan.isPaid && !info.cancelled) await plans.cancel();
      final url = await plans.checkout(target);
      await launchUrl(url, webOnlyWindowName: '_self', mode: LaunchMode.platformDefault);
    } on ApiException catch (e) {
      if (mounted) toast(context, 'Could not open checkout', description: e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _cancel(PlanInfo info) async {
    final ok = await confirm(context,
        title: 'Cancel ${info.plan.label}?',
        message: 'It stays on until the end of the month you paid for, then you move to Free. Nothing else changes.',
        action: 'Cancel plan');
    if (!ok || !mounted) return;
    try {
      await context.services.plans.cancel();
      if (mounted) toast(context, 'Your plan will not renew');
    } on ApiException catch (e) {
      if (mounted) toast(context, 'Could not cancel', description: e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final plans = context.services.plans;
    return ListenableBuilder(
      listenable: plans,
      builder: (context, _) {
        final info = plans.info;
        return PageBody(maxWidth: 1180, children: [
          PageTitle('Plans'),
          const SizedBox(height: 8),
          Text('Every plan includes the whole of DSCVR. Paid plans give Pinda more room to work.',
              style: AppTheme.sans(fontSize: 14.5, color: c.inkMuted)),
          const SizedBox(height: 22),
          UsageCard(info: info, onCancel: info.plan.isPaid && !info.cancelled ? () => _cancel(info) : null),
          const SizedBox(height: 26),
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth >= 1000 ? 4 : (box.maxWidth >= 620 ? 2 : 1);
            final w = (box.maxWidth - 16 * (cols - 1)) / cols;
            return Wrap(spacing: 16, runSpacing: 16, children: [
              for (final p in [Plan.free, ...Plan.purchasable])
                SizedBox(
                  width: w,
                  child: PlanCard(
                    plan: p,
                    current: info.plan == p,
                    highlight: p == Plan.researchPlus,
                    busy: _busy == p,
                    onChoose: p == Plan.free || info.plan == p || info.plan == Plan.enterprise ? null : () => _choose(p, info),
                  ),
                ),
            ]);
          }),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.line)),
            child: Row(children: [
              Icon(Ic.enterprise, size: 20, color: c.ink),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('DSCVR Enterprise', style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text(r'For teams: $0.40 per member on days they use it, capped at $8 a month. No daily limit.',
                      style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted)),
                ]),
              ),
              const SizedBox(width: 12),
              AppButton.secondary(size: BtnSize.sm, onPressed: () => context.go('/team'), label: const Text('Set up a team')),
            ]),
          ),
          const SizedBox(height: 14),
          Text('Prices in US dollars, billed monthly through Paystack. Cancel any time; your plan runs to the end of the month you paid for.',
              style: AppTheme.sans(fontSize: 12.5, color: c.inkFaint)),
        ]);
      },
    );
  }
}

/// The usage meter: today's and this month's share of the plan's allowance.
class UsageCard extends StatelessWidget {
  const UsageCard({super.key, required this.info, this.onCancel, this.compact = false});
  final PlanInfo info;
  final VoidCallback? onCancel;
  final bool compact;

  String _resets(DateTime? at) {
    if (at == null) return '';
    final d = at.difference(DateTime.now());
    if (d.inDays >= 1) return 'Resets in ${d.inDays} day${d.inDays == 1 ? '' : 's'}';
    if (d.inHours >= 1) return 'Resets in ${d.inHours}h ${d.inMinutes % 60}m';
    return 'Resets in ${d.inMinutes.clamp(1, 59)}m';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget meter(String label, int? pct, DateTime? resets) {
      final p = (pct ?? 0).clamp(0, 100);
      final color = p >= 90 ? c.danger : c.ink;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
          const Spacer(),
          Text('$p% used', style: AppTheme.sans(fontSize: 12.5, color: p >= 90 ? c.danger : c.inkMuted)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: p / 100),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: color, backgroundColor: c.chip),
          ),
        ),
        const SizedBox(height: 6),
        Text(_resets(resets), style: AppTheme.sans(fontSize: 12, color: c.inkFaint)),
      ]);
    }

    final status = info.cancelled && info.endsAt != null
        ? 'Ends ${MaterialLocalizations.of(context).formatMediumDate(info.endsAt!)}'
        : info.pastDue
            ? 'Payment failed. Paystack will retry; update your card from their email.'
            : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(info.plan.icon, size: 18, color: c.ink),
          const SizedBox(width: 10),
          Text(info.plan.label, style: context.text.titleMedium),
          if (status != null) ...[
            const SizedBox(width: 10),
            Flexible(child: Text(status, style: AppTheme.sans(fontSize: 12.5, color: info.pastDue ? c.danger : c.inkMuted))),
          ],
          const Spacer(),
          if (onCancel != null) AppButton.ghost(size: BtnSize.sm, onPressed: onCancel, label: const Text('Cancel plan')),
        ]),
        const SizedBox(height: 16),
        if (info.dayPct == null)
          Text('Your organisation covers your usage. No daily limit.', style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted))
        else
          Flex(
            direction: compact ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) meter('Today', info.dayPct, info.dayResetsAt) else Expanded(child: meter('Today', info.dayPct, info.dayResetsAt)),
              SizedBox(width: 24, height: compact ? 14 : 0),
              if (compact)
                meter('This month', info.monthPct, info.monthResetsAt)
              else
                Expanded(child: meter('This month', info.monthPct, info.monthResetsAt)),
            ],
          ),
      ]),
    );
  }
}

/// One plan, in the same style as the edition cards at sign-up.
class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.current, required this.onChoose, this.highlight = false, this.busy = false});
  final Plan plan;
  final bool current;
  final bool highlight;
  final bool busy;
  final VoidCallback? onChoose;

  Color _tint(DscvrColors c) {
    final base = switch (plan) {
      Plan.studentPlus => const Color(0xFFDDE9F7),
      Plan.researchPlus => const Color(0xFFE3DDF8),
      Plan.max => const Color(0xFFF4E6CC),
      _ => const Color(0xFFE6E7EC),
    };
    return c.isDark ? Color.alphaBlend(base.withValues(alpha: .14), c.surfaceMuted) : base;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: current || highlight ? c.ink : c.line, width: current || highlight ? 1.6 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: highlight ? .08 : .04), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(color: _tint(c), borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(99)),
                child: Text(plan.label.toUpperCase(),
                    style: AppTheme.sans(fontSize: 11, fontWeight: FontWeight.w700, color: c.ink, letterSpacing: .8)),
              ),
              const Spacer(),
              if (highlight && !current)
                Text('Recommended', style: AppTheme.sans(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.ink)),
              if (current) Icon(Ic.check, size: 18, color: c.ink),
            ]),
            const SizedBox(height: 24),
            Text.rich(TextSpan(children: [
              TextSpan(text: plan.price, style: AppTheme.serif(fontSize: 36, fontWeight: FontWeight.w700, color: c.ink, height: 1)),
              TextSpan(text: ' /month', style: AppTheme.sans(fontSize: 14, fontWeight: FontWeight.w500, color: c.inkMuted)),
            ])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
          child: SizedBox(
            height: 40,
            child: Text(plan.blurb, maxLines: 2, style: AppTheme.sans(fontSize: 13.5, fontWeight: FontWeight.w500, color: c.ink, height: 1.4)),
          ),
        ),
        if (current)
          AppButton.secondary(onPressed: null, expand: true, label: const Text('Your plan'))
        else if (onChoose == null)
          AppButton.secondary(onPressed: null, expand: true, label: Text(plan == Plan.free ? 'Included' : plan.label))
        else
          (highlight ? AppButton.primary : AppButton.secondary)(
            onPressed: busy ? null : onChoose,
            loading: busy,
            expand: true,
            label: Text('Get ${plan.label}'),
          ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final perk in plan.perks)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Ic.check, size: 14, color: c.inkMuted)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(perk, style: AppTheme.sans(fontSize: 13.5, color: c.ink, height: 1.4))),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}
