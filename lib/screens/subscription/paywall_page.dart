import 'package:dscvr/config/env.dart';
import 'package:dscvr/data/payment_service.dart';
import 'package:dscvr/models/subscription.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';

/// Full-screen pricing page showing the three tiers. Users can upgrade,
/// downgrade, or manage their current plan from here.
class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  BillingInterval _interval = BillingInterval.yearly;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final compact = context.isCompact;
    final user = context.services.session.user;
    final currentTier = user.subscription.tier;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text('Choose your plan', style: AppTheme.serif(fontSize: 22, fontWeight: FontWeight.w600, color: c.ink)),
        leading: Pressable(
          onTap: () => Navigator.of(context).pop(),
          child: Icon(Ic.back, color: c.ink),
        ),
      ),
      body: Stack(children: [SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 32, vertical: 20),
        child: Column(
          children: [
            // Billing toggle
            _BillingToggle(
              interval: _interval,
              onChanged: (v) => setState(() => _interval = v),
            ),
            const SizedBox(height: 28),
            // Plan cards
            if (compact)
              Column(
                children: [
                  for (final plan in PlanPricing.plans) ...[
                    _PlanCard(
                      plan: plan,
                      interval: _interval,
                      isCurrent: plan.tier == currentTier,
                      onSelect: plan.tier == currentTier ? null : () => _selectPlan(plan.tier),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, plan) in PlanPricing.plans.indexed) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(
                      child: _PlanCard(
                        plan: plan,
                        interval: _interval,
                        isCurrent: plan.tier == currentTier,
                        onSelect: plan.tier == currentTier ? null : () => _selectPlan(plan.tier),
                        highlight: plan.tier == SubscriptionTier.pro,
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 40),
            // FAQ section
            _FaqSection(),
          ],
        ),
      ),
      if (_loading) Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: const Center(child: CircularProgressIndicator()),
      ),
      ]),
    );
  }

  bool _loading = false;
  final _paymentService = PaymentService();

  Future<void> _selectPlan(SubscriptionTier tier) async {
    if (tier == SubscriptionTier.free) {
      // Downgrade — cancel via the Flask server
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Downgrade to Free?', style: AppTheme.serif(fontSize: 20, fontWeight: FontWeight.w600)),
          content: Text(
            'You will lose access to Pro features at the end of your current billing period.',
            style: AppTheme.sans(fontSize: 14, color: ctx.colors.inkMuted),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel subscription'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      await _cancelSubscription();
      return;
    }

    // Upgrade — Google Pay flow
    if (Env.demo) {
      Toasts.show(context, 'Demo mode', kind: ToastKind.info,
          description: 'Google Pay is disabled in demo mode.');
      return;
    }

    setState(() => _loading = true);
    try {
      // In a real app, you would use the `pay` package to show the
      // Google Pay sheet and get the payment token. For now, we show
      // a confirmation dialog that simulates the flow.
      final confirmed = await _showGooglePaySheet(tier);
      if (!confirmed || !mounted) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // The paymentToken would come from GooglePayButton.onPaymentResult
      // For now, send a placeholder that the server can validate against
      final result = await _paymentService.verifyAndActivate(
        tier: tier.name,
        interval: _interval.name,
        paymentToken: {
          'apiVersion': 2,
          'apiVersionMinor': 0,
          'paymentMethodData': {
            'type': 'CARD',
            'tokenizationData': {
              'type': 'PAYMENT_GATEWAY',
              'token': 'pending_real_token',
            },
            'info': {
              'cardNetwork': 'VISA',
              'cardDetails': '4242',
            },
          },
        },
      );

      if (!mounted) return;
      Toasts.show(context, result['message'] as String? ?? 'Subscription activated!',
          kind: ToastKind.success);

      // Refresh the user's subscription state
      context.services.session.refreshSubscription();
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        Toasts.show(context, 'Payment failed', kind: ToastKind.error,
            description: e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _showGooglePaySheet(SubscriptionTier tier) async {
    final plan = PlanPricing.plans.firstWhere((p) => p.tier == tier);
    final price = plan.price(_interval);

    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Ic.googlePay, size: 24, color: ctx.colors.ink),
          const SizedBox(width: 10),
          Text('Google Pay', style: AppTheme.serif(fontSize: 20, fontWeight: FontWeight.w600)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'DSCVR ${tier.label} — ${_interval.label}',
            style: AppTheme.sans(fontSize: 16, fontWeight: FontWeight.w600, color: ctx.colors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${price.toStringAsFixed(0)}/${_interval == BillingInterval.yearly ? 'year' : 'month'}',
            style: AppTheme.serif(fontSize: 28, fontWeight: FontWeight.w700, color: ctx.colors.ink),
          ),
          const SizedBox(height: 16),
          Text(
            'You will be charged via Google Pay. Cancel anytime from Settings.',
            style: AppTheme.sans(fontSize: 13, color: ctx.colors.inkMuted),
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Ic.googlePay, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Pay', style: TextStyle(color: Colors.white)),
            ]),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _cancelSubscription() async {
    if (Env.demo) return;
    setState(() => _loading = true);
    try {
      await _paymentService.cancelSubscription();
      if (!mounted) return;
      Toasts.show(context, 'Subscription cancelled',
          kind: ToastKind.success,
          description: 'You will retain access until the end of your billing period.');
      context.services.session.refreshSubscription();
    } catch (e) {
      if (mounted) {
        Toasts.show(context, 'Could not cancel subscription', kind: ToastKind.error,
            description: e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _BillingToggle extends StatelessWidget {
  const _BillingToggle({required this.interval, required this.onChanged});
  final BillingInterval interval;
  final ValueChanged<BillingInterval> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(
        color: c.surfaceMuted,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final bi in BillingInterval.values)
            Pressable(
              onTap: () => onChanged(bi),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: ShapeDecoration(
                  color: interval == bi ? c.surface : Colors.transparent,
                  shape: const StadiumBorder(),
                  shadows: interval == bi
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bi.label,
                      style: AppTheme.sans(
                        fontSize: 13.5,
                        fontWeight: interval == bi ? FontWeight.w600 : FontWeight.w500,
                        color: interval == bi ? c.ink : c.inkMuted,
                      ),
                    ),
                    if (bi == BillingInterval.yearly) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Save 33%', style: AppTheme.sans(fontSize: 11, fontWeight: FontWeight.w600, color: c.success)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.interval,
    required this.isCurrent,
    this.onSelect,
    this.highlight = false,
  });

  final PlanPricing plan;
  final BillingInterval interval;
  final bool isCurrent;
  final VoidCallback? onSelect;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final price = plan.price(interval);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: c.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
          side: BorderSide(
            color: highlight ? c.ink : c.line,
            width: highlight ? 1.5 : 1,
          ),
        ),
        shadows: highlight
            ? [BoxShadow(color: c.ink.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(plan.tier.label, style: AppTheme.serif(fontSize: 22, fontWeight: FontWeight.w600, color: c.ink)),
              const Spacer(),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: ShapeDecoration(
                    color: c.ink.withValues(alpha: 0.08),
                    shape: const StadiumBorder(),
                  ),
                  child: Text('Current', style: AppTheme.sans(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink)),
                ),
              if (highlight && !isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: ShapeDecoration(
                    color: c.ink,
                    shape: const StadiumBorder(),
                  ),
                  child: Text('Popular', style: AppTheme.sans(fontSize: 12, fontWeight: FontWeight.w600, color: c.inverseInk)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price == 0 ? 'Free' : '\$${price.toStringAsFixed(0)}',
                style: AppTheme.serif(fontSize: 36, fontWeight: FontWeight.w700, color: c.ink, height: 1),
              ),
              if (price > 0) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    interval == BillingInterval.yearly ? '/year' : '/month',
                    style: AppTheme.sans(fontSize: 14, color: c.inkMuted),
                  ),
                ),
              ],
            ],
          ),
          if (interval == BillingInterval.yearly && plan.monthlyPrice > 0) ...[
            const SizedBox(height: 4),
            Text(
              '\$${(plan.yearlyPrice / 12).toStringAsFixed(0)}/month, billed annually',
              style: AppTheme.sans(fontSize: 12.5, color: c.inkFaint),
            ),
          ],
          const SizedBox(height: 20),
          // CTA button
          SizedBox(
            width: double.infinity,
            child: isCurrent
                ? OutlinedButton(
                    onPressed: null,
                    child: Text('Current plan', style: AppTheme.sans(fontSize: 14, fontWeight: FontWeight.w500)),
                  )
                : highlight
                    ? FilledButton(
                        onPressed: onSelect,
                        child: Text(
                          plan.tier == SubscriptionTier.free ? 'Downgrade' : 'Upgrade to ${plan.tier.label}',
                        ),
                      )
                    : OutlinedButton(
                        onPressed: onSelect,
                        child: Text(
                          plan.tier == SubscriptionTier.free ? 'Downgrade' : 'Upgrade to ${plan.tier.label}',
                        ),
                      ),
          ),
          const SizedBox(height: 20),
          Divider(color: c.line),
          const SizedBox(height: 16),
          // Features list
          for (final feature in plan.features) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Ic.check, size: 16, color: c.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feature,
                      style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  static const _faqs = [
    (
      'Can I cancel anytime?',
      'Yes. You can cancel your subscription at any time from Settings. '
          'You will retain access to paid features until the end of your current billing period.'
    ),
    (
      'What payment methods are accepted?',
      'We accept all major credit and debit cards through Google Pay, including Visa, Mastercard, Amex, and Discover.'
    ),
    (
      'Can I switch between monthly and yearly?',
      'Yes. When you switch to yearly billing, you will be credited for the remaining time on your monthly plan.'
    ),
    (
      'Is there a student discount?',
      'Yes! Students with a valid .edu email get 50% off Pro. Contact support with your student email to get started.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Frequently asked questions', style: AppTheme.serif(fontSize: 20, fontWeight: FontWeight.w600, color: c.ink)),
        const SizedBox(height: 16),
        for (final (q, a) in _faqs) ...[
          _FaqTile(question: q, answer: a),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => setState(() => _open = !_open),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: ShapeDecoration(
          color: c.surface,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            side: BorderSide(color: c.line),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.question, style: AppTheme.sans(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Ic.caretDown, size: 16, color: c.inkMuted),
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(widget.answer, style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted, height: 1.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
