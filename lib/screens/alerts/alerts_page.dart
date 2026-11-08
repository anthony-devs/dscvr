import 'package:dscvr/data/alerts_service.dart';
import 'package:dscvr/screens/add/add_material_sheet.dart';
import 'package:dscvr/screens/library/shelf_page.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/cite_sheet.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// New papers, guidelines and judgments in the subjects the user follows.
class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  late final AlertsService _svc = AlertsService(context.services.session.user.id);
  late final Stream<List<AlertItem>> _stream = _svc.watch();
  bool _checking = false;

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    try {
      final r = await context.services.api.post('/alerts/check');
      final n = (r['new'] as num?)?.toInt() ?? 0;
      if (mounted) toast(context, n > 0 ? '$n new' : 'Nothing new yet', description: n > 0 ? null : 'We check every day.');
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = context.services.session.user;
    return StreamBuilder<List<AlertItem>>(
      stream: _stream,
      builder: (context, snap) {
        final items = snap.data ?? const <AlertItem>[];
        final unread = items.where((a) => !a.read).toList();
        return PageBody(maxWidth: 900, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Expanded(child: PageTitle('Alerts')),
            if (user.alertsOn) ...[
              AppButton.ghost(
                size: BtnSize.sm,
                onPressed: _checking ? null : _checkNow,
                loading: _checking,
                icon: const Icon(Ic.retry, size: 14),
                label: const Text('Check now'),
              ),
              if (unread.isNotEmpty)
                AppButton.ghost(size: BtnSize.sm, onPressed: () => _svc.markAllRead(items), label: const Text('Mark all read')),
            ],
          ]),
          const SizedBox(height: 8),
          Text(
            user.alertsOn
                ? 'New items in ${user.interests.take(8).join(', ')}. Checked once a day.'
                : 'Get new papers, clinical guidelines and judgments in your subjects, once a day.',
            style: AppTheme.sans(fontSize: 14.5, color: c.inkMuted, height: 1.5),
          ),
          const SizedBox(height: 22),
          if (!user.alertsOn)
            EmptyState(
              icon: Ic.lightning,
              title: 'Alerts are off',
              message: user.interests.isEmpty
                  ? 'Follow a few subjects first, then turn alerts on.'
                  : 'Turn them on to hear about new work in your subjects.',
              action: AppButton.primary(
                onPressed: () async {
                  if (user.interests.isEmpty) {
                    context.go('/settings');
                    return;
                  }
                  await context.services.session.setAlerts(enabled: true, email: false);
                  if (mounted) await _checkNow();
                },
                label: Text(user.interests.isEmpty ? 'Choose subjects' : 'Turn on alerts'),
              ),
            )
          else if (snap.connectionState == ConnectionState.waiting && items.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: Spinner(size: 22)))
          else if (items.isEmpty)
            const EmptyState(icon: Ic.lightning, title: 'Nothing new yet', message: 'New items will appear here as they are published.')
          else
            for (final a in items) _AlertRow(alert: a, svc: _svc),
        ]);
      },
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.svc});
  final AlertItem alert;
  final AlertsService svc;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = alert.paper;
    final meta = [
      alert.subject,
      p.sourceLabel,
      if (p.venue != null && p.venue!.isNotEmpty) p.venue!,
      if (p.year != null) '${p.year}',
      DateFormat('d MMM').format(alert.createdAt),
    ].join('  ·  ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 12),
          child: Semantics(
            label: alert.read ? null : 'Unread',
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: alert.read ? Colors.transparent : c.ink, shape: BoxShape.circle),
            ),
          ),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.title,
                style: AppTheme.serif(fontSize: 17, fontWeight: alert.read ? FontWeight.w500 : FontWeight.w600, color: c.ink, height: 1.3)),
            const SizedBox(height: 5),
            Text(meta, style: context.text.labelSmall),
            if (p.summary.isNotEmpty && !p.isJudgment) ...[
              const SizedBox(height: 8),
              Text(p.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted, height: 1.5)),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              PillButton(
                label: 'Save to library',
                icon: Ic.add,
                onTap: () {
                  svc.markRead(alert.id);
                  savePaperFlow(context, p);
                },
              ),
              if (p.url != null)
                PillButton(
                  label: 'Open',
                  icon: Ic.external,
                  onTap: () {
                    svc.markRead(alert.id);
                    launchUrl(Uri.parse(p.url!), mode: LaunchMode.externalApplication);
                  },
                ),
              PillButton(label: 'Cite', icon: Ic.quote, onTap: () => showCiteSheet(context, CiteSource.fromPaper(p))),
              PillButton(label: 'Dismiss', icon: Ic.close, onTap: () => svc.remove(alert.id)),
            ]),
          ]),
        ),
      ]),
    );
  }
}
