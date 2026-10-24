/// Subscription tiers and billing models for DSCVR.

enum SubscriptionTier {
  free('Free'),
  pro('Pro'),
  team('Team');

  const SubscriptionTier(this.label);
  final String label;
}

enum BillingInterval {
  monthly('Monthly'),
  yearly('Yearly');

  const BillingInterval(this.label);
  final String label;
}

/// Tier limits: what each plan allows.
class TierLimits {
  const TierLimits({
    required this.pindaDaily,
    required this.libraryItems,
    required this.categories,
    required this.pdfSizeMb,
    required this.parliamentEnabled,
    required this.sharingEnabled,
    required this.exportEnabled,
    required this.teamMembers,
  });

  final int pindaDaily;
  final int libraryItems;
  final int categories;
  final int pdfSizeMb;
  final bool parliamentEnabled;
  final bool sharingEnabled;
  final bool exportEnabled;
  final int teamMembers;

  static const free = TierLimits(
    pindaDaily: 25,
    libraryItems: 100,
    categories: 5,
    pdfSizeMb: 10,
    parliamentEnabled: false,
    sharingEnabled: false,
    exportEnabled: false,
    teamMembers: 0,
  );

  static const pro = TierLimits(
    pindaDaily: 500,
    libraryItems: -1, // unlimited
    categories: -1,
    pdfSizeMb: 50,
    parliamentEnabled: true,
    sharingEnabled: true,
    exportEnabled: true,
    teamMembers: 0,
  );

  static const team = TierLimits(
    pindaDaily: 2000,
    libraryItems: -1,
    categories: -1,
    pdfSizeMb: 100,
    parliamentEnabled: true,
    sharingEnabled: true,
    exportEnabled: true,
    teamMembers: 50,
  );

  static TierLimits forTier(SubscriptionTier tier) => switch (tier) {
        SubscriptionTier.free => free,
        SubscriptionTier.pro => pro,
        SubscriptionTier.team => team,
      };

  bool isUnlimited(int v) => v < 0;
}

/// A user's active subscription state.
class Subscription {
  const Subscription({
    required this.tier,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.interval = BillingInterval.monthly,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
  });

  final SubscriptionTier tier;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final BillingInterval interval;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  bool get isPaid => tier != SubscriptionTier.free;
  bool get isActive => isPaid && (currentPeriodEnd?.isAfter(DateTime.now()) ?? false);
  TierLimits get limits => TierLimits.forTier(tier);

  factory Subscription.free() => const Subscription(tier: SubscriptionTier.free);

  factory Subscription.fromMap(Map<String, dynamic> map) => Subscription(
        tier: SubscriptionTier.values.firstWhere(
          (e) => e.name == map['tier'],
          orElse: () => SubscriptionTier.free,
        ),
        stripeCustomerId: map['stripeCustomerId'] as String?,
        stripeSubscriptionId: map['stripeSubscriptionId'] as String?,
        interval: BillingInterval.values.firstWhere(
          (e) => e.name == map['interval'],
          orElse: () => BillingInterval.monthly,
        ),
        currentPeriodEnd: map['currentPeriodEnd'] is String
            ? DateTime.tryParse(map['currentPeriodEnd'])
            : null,
        cancelAtPeriodEnd: map['cancelAtPeriodEnd'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'tier': tier.name,
        if (stripeCustomerId != null) 'stripeCustomerId': stripeCustomerId,
        if (stripeSubscriptionId != null) 'stripeSubscriptionId': stripeSubscriptionId,
        'interval': interval.name,
        if (currentPeriodEnd != null) 'currentPeriodEnd': currentPeriodEnd!.toIso8601String(),
        'cancelAtPeriodEnd': cancelAtPeriodEnd,
      };
}

/// Pricing info for display.
class PlanPricing {
  const PlanPricing({
    required this.tier,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.features,
  });

  final SubscriptionTier tier;
  final double monthlyPrice;
  final double yearlyPrice;
  final List<String> features;

  double price(BillingInterval interval) =>
      interval == BillingInterval.yearly ? yearlyPrice : monthlyPrice;

  static const plans = [
    PlanPricing(
      tier: SubscriptionTier.free,
      monthlyPrice: 0,
      yearlyPrice: 0,
      features: [
        '25 Pinda queries per day',
        'Up to 100 library items',
        '5 collections',
        '10 MB PDF uploads',
        'arXiv & Semantic Scholar search',
      ],
    ),
    PlanPricing(
      tier: SubscriptionTier.pro,
      monthlyPrice: 12,
      yearlyPrice: 96,
      features: [
        '500 Pinda queries per day',
        'Unlimited library items',
        'Unlimited collections',
        '50 MB PDF uploads',
        'Parliament Fact-Check',
        'Share & collaborate on collections',
        'Export to BibTeX, Markdown, CSV',
      ],
    ),
    PlanPricing(
      tier: SubscriptionTier.team,
      monthlyPrice: 29,
      yearlyPrice: 240,
      features: [
        '2,000 Pinda queries per day',
        'Everything in Pro',
        '100 MB PDF uploads',
        'Up to 50 team members',
        'Shared team library',
        'Admin dashboard',
        'Priority support',
      ],
    ),
  ];
}
