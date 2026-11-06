import 'package:dscvr/config/env.dart';
import 'package:dscvr/data/api.dart';
import 'package:dscvr/models/plan.dart';
import 'package:flutter/foundation.dart';

/// The user's plan, usage meter and Paystack checkout.
class PlanService extends ChangeNotifier {
  PlanService(this.api);
  final DscvrApi api;

  PlanInfo _info = PlanInfo.free;
  PlanInfo get info => _info;
  DateTime? _loadedAt;

  /// Refreshes at most every 30 s unless [force].
  Future<PlanInfo> refresh({bool force = false}) async {
    if (!force && _loadedAt != null && DateTime.now().difference(_loadedAt!) < const Duration(seconds: 30)) return _info;
    if (Env.demo) {
      _info = PlanInfo(plan: Plan.free, dayPct: 35, monthPct: 12, dayResetsAt: DateTime.now().add(const Duration(hours: 7)),
          monthResetsAt: DateTime.now().add(const Duration(days: 24)));
    } else {
      try {
        _info = PlanInfo.fromMap(await api.get('/billing/me'));
      } on ApiException catch (e) {
        debugPrint('Plan refresh failed: $e');
        return _info;
      }
    }
    _loadedAt = DateTime.now();
    notifyListeners();
    return _info;
  }

  void clear() {
    _info = PlanInfo.free;
    _loadedAt = null;
    notifyListeners();
  }

  /// A Paystack payment page for [plan].
  Future<Uri> checkout(Plan plan) async {
    if (Env.demo) throw const ApiException('Payments are not available in the demo.');
    final r = await api.post('/billing/checkout', {'plan': plan.id});
    final url = r['url'] as String?;
    if (url == null) throw const ApiException('Could not start checkout. Try again.');
    return Uri.parse(url);
  }

  /// After Paystack sends the user back to the app.
  Future<bool> verify(String reference) async {
    final r = await api.post('/billing/verify', {'reference': reference});
    await refresh(force: true);
    return r['status'] == 'success';
  }

  /// Stops renewal; the plan stays on until the end of the paid month.
  Future<void> cancel() async {
    await api.post('/billing/cancel');
    await refresh(force: true);
  }
}
