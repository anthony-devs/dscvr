import 'package:dscvr/config/env.dart';
import 'package:dscvr/data/api.dart';
import 'package:dscvr/models/workspace.dart';

/// Enterprise organisations: create, join, members, usage and invoices.
/// Membership changes go through the server so nobody can grant themselves
/// admin or move between organisations by writing to Firestore directly.
class OrgService {
  OrgService(this.api);
  final DscvrApi api;

  Organization _org(Map<String, dynamic> body) => Organization.fromMap((body['org'] as Map).cast<String, dynamic>());

  Future<Organization?> mine() async {
    if (Env.demo) return _demo;
    try {
      return _org(await api.get('/orgs/me'));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<Organization> create(String name) async => Env.demo ? _demo : _org(await api.post('/orgs', {'name': name}));
  Future<Organization> join(String code) async => Env.demo ? _demo : _org(await api.post('/orgs/join', {'code': code}));
  Future<void> leave() => api.post('/orgs/leave');
  Future<String> rotateInvite() async => (await api.post('/orgs/invite/rotate'))['inviteCode'] as String;
  Future<void> remove(String uid) => api.post('/orgs/members/$uid/remove');
  Future<void> setRole(String uid, String role) => api.post('/orgs/members/$uid/role', {'role': role});

  Future<List<UsageBill>> invoices() async {
    if (Env.demo) return [UsageBill.fromMap({..._demoBill, 'month': '2026-10', 'status': 'due'})];
    final body = await api.get('/orgs/invoices');
    return [for (final i in (body['invoices'] as List? ?? const [])) UsageBill.fromMap((i as Map).cast<String, dynamic>())];
  }

  Future<UsageBill> pay(String month, Map<String, dynamic> paymentToken) async {
    final body = await api.post('/orgs/invoices/$month/pay', {'paymentToken': paymentToken});
    return UsageBill.fromMap((body['invoice'] as Map).cast<String, dynamic>());
  }

  /// Counts today's active user (and an enterprise seat). Fire and forget.
  Future<void> pingActivity() async {
    if (Env.demo) return;
    try {
      await api.post('/activity');
    } catch (_) {}
  }

  static const _demoBill = {
    'activeMembers': 6, 'seatDays': 74, 'inputTokens': 2400000, 'outputTokens': 310000, 'requests': 412,
    'seatCostUsd': 29.6, 'aiCostUsd': 15.8, 'totalUsd': 45.4,
  };

  static final _demo = Organization.fromMap({
    'id': 'demo_org',
    'name': 'Northwind Labs',
    'role': 'admin',
    'inviteCode': 'NW7K2QXP',
    'month': '2026-11',
    'members': [
      {'uid': 'demo', 'name': 'Anthony Ude', 'email': 'demo@dscvr.app', 'role': 'admin'},
      {'uid': 'm2', 'name': 'Ada Obi', 'email': 'ada@northwind.dev', 'role': 'member'},
      {'uid': 'm3', 'name': 'Kemi Bello', 'email': 'kemi@northwind.dev', 'role': 'member'},
    ],
    'estimate': _demoBill,
    'daily': [
      for (var d = 1; d <= 14; d++)
        {'day': '2026-11-${d.toString().padLeft(2, '0')}', 'activeMembers': 3 + (d % 4), 'inputTokens': 120000 + d * 9000, 'outputTokens': 16000 + d * 900, 'requests': 18 + d * 2},
    ],
  });
}
