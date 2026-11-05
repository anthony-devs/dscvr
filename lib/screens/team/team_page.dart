import 'dart:math' as math;

import 'package:dscvr/data/api.dart';
import 'package:dscvr/models/workspace.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/screens/library/shelf_page.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _usd = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
final _compact = NumberFormat.compact();

/// DSCVR Enterprise: create or join an organisation; admins manage members
/// and see live, usage-based billing.
class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  late Future<Organization?> _org = context.services.orgs.mine();

  void _reload() => setState(() => _org = context.services.orgs.mine());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Organization?>(
      future: _org,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const PageSpinner();
        if (snap.hasError) {
          return EmptyState(
            icon: Ic.warning,
            title: "Couldn't load your organisation",
            message: snap.error is ApiException ? (snap.error as ApiException).message : '${snap.error}',
            action: AppButton.secondary(onPressed: _reload, child: const Text('Try again')),
          );
        }
        final org = snap.data;
        return PageBody(maxWidth: 1040, children: [
          const SizedBox(height: 18),
          if (org == null) _Setup(onDone: _reload) else _Dashboard(org: org, onChanged: _reload),
        ]);
      },
    );
  }
}

// ── No organisation yet ──────────────────────────────────────────────

class _Setup extends StatefulWidget {
  const _Setup({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_Setup> createState() => _SetupState();
}

class _SetupState extends State<_Setup> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    final session = context.services.session;
    try {
      await action();
      await session.refreshProfile();
      widget.onDone();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pricing = const EnterprisePricing();
    final cards = [
      _Panel(
        icon: Ic.enterprise,
        title: 'Create an organisation',
        body: "You'll be its admin. Invite your team with a code and only pay for what they use.",
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppField(controller: _name, label: 'Organisation name', hint: 'e.g. Northwind Labs'),
          const SizedBox(height: 12),
          AppButton.primary(
            onPressed: _busy ? null : () => _run(() => context.services.orgs.create(_name.text.trim())),
            child: const Text('Create organisation'),
          ),
        ]),
      ),
      _Panel(
        icon: Ic.userPlus,
        title: 'Join your team',
        body: 'Ask an admin for your 8-character invite code.',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppField(controller: _code, label: 'Invite code', hint: 'e.g. NW7K2QXP', textCapitalization: TextCapitalization.characters),
          const SizedBox(height: 12),
          AppButton.secondary(
            onPressed: _busy ? null : () => _run(() => context.services.orgs.join(_code.text.trim())),
            child: const Text('Join organisation'),
          ),
        ]),
      ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageTitle('DSCVR Enterprise'),
      const SizedBox(height: 6),
      Text('A shared research desk for teams. No seats to buy up front.', style: AppTheme.sans(fontSize: 14.5, color: c.inkMuted, height: 1.5)),
      const SizedBox(height: 24),
      LayoutBuilder(
        builder: (context, box) => box.maxWidth < 720
            ? Column(children: [cards[0], const SizedBox(height: 12), cards[1]])
            : IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ]),
              ),
      ),
      const SizedBox(height: 28),
      const SectionLabel('How billing works'),
      const SizedBox(height: 10),
      _PricingTable(pricing: pricing),
    ]);
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.icon, required this.title, required this.body, required this.child});
  final IconData icon;
  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(icon, size: 20, color: c.ink),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: context.text.titleMedium)),
        ]),
        const SizedBox(height: 6),
        Text(body, style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted, height: 1.5)),
        const SizedBox(height: 16),
        const Spacer(),
        child,
      ]),
    );
  }
}

class _PricingTable extends StatelessWidget {
  const _PricingTable({required this.pricing});
  final EnterprisePricing pricing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = [
      ('Active seat', '${_usd.format(pricing.seatDayUsd)} per member, per day they use DSCVR', 'Capped at ${_usd.format(pricing.seatMonthCapUsd)} per member each month'),
      ('AI input', '${_usd.format(pricing.aiInputPerMillionUsd)} per million tokens', 'What Pinda reads: your sources and questions'),
      ('AI output', '${_usd.format(pricing.aiOutputPerMillionUsd)} per million tokens', 'What Pinda writes: answers, reports, recaps'),
      ('Everything else', 'Included', 'Library, Discover, sessions, voice, sharing, admin'),
    ];
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.line)),
      child: Column(children: [
        for (final (i, r) in rows.indexed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.line))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 130, child: Text(r.$1, style: AppTheme.sans(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.ink))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.$2, style: AppTheme.sans(fontSize: 13.5, color: c.ink)),
                  const SizedBox(height: 2),
                  Text(r.$3, style: context.text.labelSmall),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ── Organisation dashboard ───────────────────────────────────────────

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.org, required this.onChanged});
  final Organization org;
  final VoidCallback onChanged;

  Future<void> _act(BuildContext context, Future<void> Function() f, String done) async {
    try {
      await f();
      if (context.mounted) toast(context, done);
      onChanged();
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final orgs = context.services.orgs;
    final me = context.services.session.user.id;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DSCVR Enterprise', style: context.text.labelMedium),
            const SizedBox(height: 4),
            PageTitle(org.name),
          ]),
        ),
        AppButton.ghost(
          onPressed: () async {
            final ok = await confirm(context, title: 'Leave ${org.name}?', message: "You'll move back to DSCVR Researchers. Your own library stays with you.", action: 'Leave');
            if (!ok || !context.mounted) return;
            await _act(context, orgs.leave, 'You left ${org.name}');
            if (context.mounted) await context.services.session.refreshProfile();
          },
          child: const Text('Leave'),
        ),
      ]),
      const SizedBox(height: 22),
      if (!org.isAdmin)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.line)),
          child: Row(children: [
            Icon(Ic.info, size: 18, color: c.inkMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text("You're a member. Your usage is billed to ${org.name}, so there are no daily Pinda limits for you.",
                  style: AppTheme.sans(fontSize: 14, color: c.ink, height: 1.5)),
            ),
          ]),
        )
      else ...[
        _UsageSummary(org: org),
        const SizedBox(height: 28),
        Row(children: [
          SectionLabel('Members', count: org.members.length),
          const Spacer(),
          if (org.inviteCode != null)
            PillButton(
              label: 'Invite code  ${org.inviteCode}',
              icon: Ic.copy,
              onTap: () {
                Clipboard.setData(ClipboardData(text: org.inviteCode!));
                toast(context, 'Invite code copied', description: 'New members enter it in Team, under Join your team.');
              },
            ),
          const SizedBox(width: 6),
          AppIconButton(
            tooltip: 'New invite code (old one stops working)',
            onPressed: () => _act(context, () async => orgs.rotateInvite(), 'New invite code created'),
            icon: const Icon(Ic.retry, size: 17),
          ),
        ]),
        const SizedBox(height: 8),
        for (final m in org.members)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: c.chip,
                child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase(), style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.uid == me ? '${m.name} (you)' : m.name, style: AppTheme.sans(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
                  Text(m.email, style: context.text.labelSmall),
                ]),
              ),
              Text(m.isAdmin ? 'Admin' : 'Member', style: context.text.labelSmall),
              if (m.uid != me)
                MenuButton<String>(
                  tooltip: 'Manage',
                  onSelected: (v) async {
                    if (v == 'role') {
                      await _act(context, () => orgs.setRole(m.uid, m.isAdmin ? 'member' : 'admin'), 'Role updated');
                    } else if (v == 'remove') {
                      final ok = await confirm(context, title: 'Remove ${m.name}?', message: 'They lose access to ${org.name}. Their own library stays with them.', action: 'Remove');
                      if (ok && context.mounted) await _act(context, () => orgs.remove(m.uid), '${m.name} removed');
                    }
                  },
                  entries: () => [
                    MenuEntry(value: 'role', label: m.isAdmin ? 'Make member' : 'Make admin', icon: Ic.user),
                    const MenuEntry(value: 'remove', label: 'Remove from organisation', icon: Ic.trash, destructive: true),
                  ],
                  child: const IgnorePointer(child: AppIconButton(tooltip: 'Manage', onPressed: null, icon: Icon(Ic.more, size: 18))),
                ),
            ]),
          ),
        const SizedBox(height: 28),
        const _Invoices(),
      ],
    ]);
  }
}

class _UsageSummary extends StatelessWidget {
  const _UsageSummary({required this.org});
  final Organization org;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = org.estimate;
    final month = org.month == null ? 'This month' : DateFormat('MMMM yyyy').format(DateTime.parse('${org.month}-01'));
    final stats = [
      ('Active members', '${e.activeMembers}', '${e.seatDays} seat-days'),
      ('Seats', _usd.format(e.seatCostUsd), '${_usd.format(org.pricing.seatDayUsd)} per seat-day'),
      ('AI usage', _usd.format(e.aiCostUsd), '${_compact.format(e.inputTokens + e.outputTokens)} tokens, ${e.requests} requests'),
      ('Estimated bill', _usd.format(e.totalUsd), 'So far in $month'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionLabel('Usage, $month'),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, box) {
        final perRow = box.maxWidth < 560 ? 2 : 4;
        final w = (box.maxWidth - (perRow - 1) * 10) / perRow;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final (i, s) in stats.indexed)
            Container(
              width: w,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: i == 3 ? c.ink : c.surface,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: i == 3 ? c.ink : c.line),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.$1, style: AppTheme.sans(fontSize: 12.5, color: i == 3 ? c.inverseInk.withValues(alpha: 0.7) : c.inkMuted)),
                const SizedBox(height: 6),
                Text(s.$2, style: AppTheme.serif(fontSize: 26, fontWeight: FontWeight.w600, color: i == 3 ? c.inverseInk : c.ink)),
                const SizedBox(height: 4),
                Text(s.$3, maxLines: 2, style: AppTheme.sans(fontSize: 12, color: i == 3 ? c.inverseInk.withValues(alpha: 0.7) : c.inkMuted)),
              ]),
            ),
        ]);
      }),
      if (org.daily.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          height: 150,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: c.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Active members per day', style: context.text.labelSmall),
            const SizedBox(height: 8),
            Expanded(child: _Bars(values: [for (final d in org.daily) d.activeMembers], labels: [for (final d in org.daily) d.day.substring(8)])),
          ]),
        ),
      ],
    ]);
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.values, required this.labels});
  final List<int> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final top = math.max(1, values.fold<int>(0, math.max));
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 0; i < values.length; i++)
        Expanded(
          child: Tooltip(
            message: 'Day ${labels[i]}: ${values[i]} active',
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(
                child: FractionallySizedBox(
                  heightFactor: values[i] / top,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[i], style: AppTheme.sans(fontSize: 10, color: c.inkFaint)),
            ]),
          ),
        ),
    ]);
  }
}

class _Invoices extends StatefulWidget {
  const _Invoices();

  @override
  State<_Invoices> createState() => _InvoicesState();
}

class _InvoicesState extends State<_Invoices> {
  late final Future<List<UsageBill>> _future = context.services.orgs.invoices();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FutureBuilder<List<UsageBill>>(
      future: _future,
      builder: (context, snap) {
        final list = snap.data ?? const <UsageBill>[];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionLabel('Invoices'),
          const SizedBox(height: 4),
          Text('Each month is billed after it ends. We email the invoice to admins.', style: context.text.bodySmall),
          const SizedBox(height: 10),
          if (snap.connectionState != ConnectionState.done)
            const Skeleton(height: 48)
          else if (list.isEmpty)
            Text('No usage yet.', style: context.text.bodySmall)
          else
            for (final b in list)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                child: Row(children: [
                  Icon(Ic.receipt, size: 17, color: c.inkMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(b.month == null ? '-' : DateFormat('MMMM yyyy').format(DateTime.parse('${b.month}-01')),
                        style: AppTheme.sans(fontSize: 14, color: c.ink)),
                  ),
                  Text('${b.activeMembers} members', style: context.text.labelSmall),
                  const SizedBox(width: 16),
                  SizedBox(width: 84, child: Text(_usd.format(b.totalUsd), textAlign: TextAlign.right, style: AppTheme.sans(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink))),
                  const SizedBox(width: 12),
                  _StatusChip(status: b.status ?? 'open'),
                ]),
              ),
        ]);
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color) = switch (status) {
      'paid' => ('Paid', c.success),
      'due' => ('Due', c.danger),
      _ => ('In progress', c.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppTheme.sans(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
