import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/widgets.dart';

/// Paid plans on top of the free editions. Usage is a budget that resets
/// daily and monthly (see server/plans.py); users see percentages.
enum Plan {
  free(
    id: 'free',
    label: 'Free',
    price: r'$0',
    icon: Ic.students,
    blurb: 'Everything in DSCVR, with a daily Pinda allowance.',
  ),
  studentPlus(
    id: 'student_plus',
    label: 'Student Plus',
    price: r'$4.99',
    icon: Ic.students,
    blurb: 'For students who lean on Pinda every day.',
  ),
  researchPlus(
    id: 'research_plus',
    label: 'Research Plus',
    price: r'$9.99',
    icon: Ic.researchers,
    blurb: 'For researchers who read, write and review all week.',
  ),
  max(
    id: 'max',
    label: 'DSCVR Max',
    price: r'$24.99',
    icon: Ic.crown,
    blurb: 'Our best model everywhere and the most usage.',
  ),
  enterprise(
    id: 'enterprise',
    label: 'Enterprise',
    price: 'Usage-based',
    icon: Ic.enterprise,
    blurb: 'Covered by your organisation.',
  );

  const Plan({required this.id, required this.label, required this.price, required this.icon, required this.blurb});

  final String id;
  final String label;
  final String price;
  final IconData icon;
  final String blurb;

  bool get isPaid => this == studentPlus || this == researchPlus || this == max;

  static Plan parse(String? v) => Plan.values.firstWhere((p) => p.id == v, orElse: () => Plan.free);

  /// The plans people can buy, in order.
  static const purchasable = [studentPlus, researchPlus, max];

  /// What each plan includes, for the plan cards. Only real features.
  List<String> get perks => switch (this) {
        Plan.free => const [
            'Pinda on our fast model',
            'A daily Pinda allowance that resets every day',
            'Library, reader, notes and voice notes',
            'Reports, focus sessions and study rooms',
            'arXiv, Semantic Scholar and journals in Discover',
          ],
        Plan.studentPlus => const [
            '5x the daily Pinda usage of Free',
            'A bigger monthly allowance',
            'More study guides, quizzes and recaps every day',
            'Ask out loud as much as you like within your allowance',
            'Everything in Free',
          ],
        Plan.researchPlus => const [
            '10x the daily Pinda usage of Free',
            'Our best model for reports, recaps and fact-checks',
            'Longer literature reviews across more papers',
            'More Parliament fact-checks every day',
            'Everything in Free',
          ],
        Plan.max => const [
            '30x the daily Pinda usage of Free',
            'Our best model for everything, including chat',
            'The largest monthly allowance',
            'Built for heavy reading, writing and reviewing',
            'Everything in Research Plus',
          ],
        Plan.enterprise => const ['No daily limit', 'Billed to your organisation'],
      };
}

/// The signed-in user's plan and usage meter, from /billing/me.
class PlanInfo {
  const PlanInfo({
    required this.plan,
    this.status,
    this.endsAt,
    this.dayPct,
    this.monthPct,
    this.dayResetsAt,
    this.monthResetsAt,
    this.paymentsEnabled = false,
  });

  final Plan plan;
  final String? status;
  final DateTime? endsAt;
  final int? dayPct;
  final int? monthPct;
  final DateTime? dayResetsAt;
  final DateTime? monthResetsAt;
  final bool paymentsEnabled;

  bool get cancelled => status == 'cancelled';
  bool get pastDue => status == 'past_due';

  static const free = PlanInfo(plan: Plan.free);

  factory PlanInfo.fromMap(Map<String, dynamic> m) {
    final u = (m['usage'] as Map?)?.cast<String, dynamic>();
    DateTime? d(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
    return PlanInfo(
      plan: Plan.parse(m['plan'] as String?),
      status: m['planStatus'] as String?,
      endsAt: d(m['planEndsAt']),
      dayPct: (u?['dayPct'] as num?)?.toInt(),
      monthPct: (u?['monthPct'] as num?)?.toInt(),
      dayResetsAt: d(u?['dayResetsAt']),
      monthResetsAt: d(u?['monthResetsAt']),
      paymentsEnabled: m['paymentsEnabled'] == true,
    );
  }
}
