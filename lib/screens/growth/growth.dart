import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dscvr/config/env.dart';
import 'package:dscvr/data/api.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/star_rating.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Email verification, invites (referrals) and "Rate DSCVR".
class Growth {
  Growth._();

  static const _refKey = 'growth.pendingRef';

  /// Remembers an invite code from a link like /signup?ref=CODE, so it can be
  /// used once the new account is set up and its email is verified.
  static Future<void> captureInviteFromUrl() async {
    if (!kIsWeb || Env.demo) return;
    final code = Uri.base.queryParameters['ref']?.trim();
    if (code == null || code.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_refKey, code.toUpperCase());
    } catch (_) {}
  }

  /// True for accounts that signed up with email and haven't clicked the link yet.
  static bool needsVerification(User? u) =>
      u != null && !u.emailVerified && u.providerData.any((p) => p.providerId == 'password');

  /// Tells the server whether the email is verified, then uses a waiting invite
  /// code if there is one. Returns a message to show, or null.
  static Future<String?> afterSignIn(DscvrApi api) async {
    if (Env.demo) return null;
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      await api.post('/me/sync');
    } catch (_) {}
    String? code;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      code = prefs.getString(_refKey);
    } catch (_) {}
    if (code == null) return null;
    if (needsVerification(FirebaseAuth.instance.currentUser)) return null; // try again once verified
    try {
      final r = await api.post('/referrals/redeem', {'code': code});
      await prefs?.remove(_refKey);
      final days = (r['days'] as num?)?.toInt() ?? 30;
      return 'Invite accepted: you have ${_x(r['boost'])} Pinda usage for $days days.';
    } on ApiException catch (e) {
      if (e.status != 403) await prefs?.remove(_refKey);
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _x(Object? boost) {
    final b = (boost as num?)?.toDouble() ?? 2;
    return b == 2 ? 'double' : '${b.toStringAsFixed(b % 1 == 0 ? 0 : 1)}x';
  }
}

/// A slim bar asking email sign-ups to verify their address.
class VerifyEmailBanner extends StatefulWidget {
  const VerifyEmailBanner({super.key});

  @override
  State<VerifyEmailBanner> createState() => _VerifyEmailBannerState();
}

class _VerifyEmailBannerState extends State<VerifyEmailBanner> {
  bool _hidden = false;
  bool _busy = false;
  bool _sent = false;

  User? get _user => Env.demo ? null : FirebaseAuth.instance.currentUser;

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await _user?.sendEmailVerification();
      if (mounted) {
        setState(() => _sent = true);
        toast(context, 'Verification email sent', description: 'Check your inbox and spam folder.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) toast(context, e.code == 'too-many-requests' ? 'Please wait a minute before trying again.' : (e.message ?? 'Could not send the email.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      await _user?.reload();
      if (!Growth.needsVerification(FirebaseAuth.instance.currentUser)) {
        if (!mounted) return;
        final api = context.services.api;
        setState(() => _hidden = true);
        toast(context, 'Email verified. Thank you.');
        final msg = await Growth.afterSignIn(api);
        if (msg != null && mounted) toast(context, msg);
      } else if (mounted) {
        toast(context, 'Not verified yet', description: 'Open the link in the email, then tap this again.');
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden || !Growth.needsVerification(_user)) return const SizedBox.shrink();
    final c = context.colors;
    final email = _user?.email ?? 'your email';
    return Material(
      color: c.surfaceMuted,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Icon(Ic.info, size: 16, color: c.inkMuted),
              Text(
                _sent ? 'We sent a new link to $email.' : 'Verify your email: we sent a link to $email.',
                style: AppTheme.sans(fontSize: 13, color: c.ink),
              ),
              AppButton.ghost(size: BtnSize.sm, onPressed: _busy ? null : _resend, child: const Text('Resend')),
              AppButton.secondary(size: BtnSize.sm, onPressed: _busy ? null : _check, child: const Text("I've verified")),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings: invite friends, use a code, product update emails, and Rate DSCVR.
class GrowthSettings extends StatefulWidget {
  const GrowthSettings({super.key});

  @override
  State<GrowthSettings> createState() => _GrowthSettingsState();
}

class _GrowthSettingsState extends State<GrowthSettings> {
  Map<String, dynamic>? _ref;
  bool? _updates;
  int? _stars;
  final _code = TextEditingController();
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (Env.demo) {
      setState(() {
        _ref = {'code': 'DEMO123', 'link': 'https://app.askpinda.com/signup?ref=DEMO123', 'referred': 2, 'redeemed': false, 'boost': 2, 'days': 30};
        _updates = false;
      });
      return;
    }
    final s = context.services;
    final uid = s.session.user.id;
    unawaited(s.api.get('/referrals/me').then((r) => mounted ? setState(() => _ref = r) : null).catchError((_) => null));
    unawaited(s.api.get('/feedback/rating').then((r) => mounted ? setState(() => _stars = (r['stars'] as num?)?.toInt()) : null).catchError((_) => null));
    try {
      final d = await FirebaseFirestore.instance.doc('users/$uid').get();
      if (mounted) setState(() => _updates = d.data()?['emailUpdates'] == true);
    } catch (_) {
      if (mounted) setState(() => _updates = false);
    }
  }

  Future<void> _redeem() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() => _redeeming = true);
    try {
      final r = await context.services.api.post('/referrals/redeem', {'code': code});
      if (!mounted) return;
      toast(context, 'Invite accepted', description: 'You have ${Growth._x(r['boost'])} Pinda usage for ${r['days']} days.');
      _code.clear();
      unawaited(context.services.plans.refresh(force: true));
      await _load();
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  Future<void> _setUpdates(bool on) async {
    setState(() => _updates = on);
    try {
      if (!Env.demo) await context.services.api.post('/me/email-updates', {'on': on});
      if (mounted && on && Growth.needsVerification(FirebaseAuth.instance.currentUser)) {
        toast(context, 'Verify your email to get updates', description: 'Use the link we sent when you signed up.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _updates = !on);
        toast(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = _ref;
    final until = r?['boostUntil'] is String ? DateTime.tryParse(r!['boostUntil'] as String) : null;
    final boostText = '${Growth._x(r?['boost'])} Pinda usage for ${r?['days'] ?? 30} days';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Block(
        title: 'Invite friends, get more Pinda',
        description: 'When a friend signs up with your link and verifies their email, you both get $boostText.'
            '${until != null ? ' Your boost runs until ${DateFormat('d MMMM').format(until.toLocal())}.' : ''}',
        child: r == null
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Spinner(size: 18))
            : Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                PillButton(
                  label: 'Copy invite link',
                  icon: Ic.linkSimple,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: r['link'] as String));
                    toast(context, 'Invite link copied');
                  },
                ),
                PillButton(
                  label: 'Code ${r['code']}',
                  icon: Ic.copy,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: r['code'] as String));
                    toast(context, 'Code copied');
                  },
                ),
                Text('${r['referred'] ?? 0} joined', style: context.text.labelMedium),
              ]),
      ),
      if (r != null && r['redeemed'] != true)
        _Block(
          title: 'Have an invite code?',
          description: 'Use it in your first 14 days, after verifying your email.',
          child: Row(children: [
            Expanded(child: AppField(controller: _code, label: 'Invite code', hint: 'e.g. K7Q2MNX', textCapitalization: TextCapitalization.characters)),
            const SizedBox(width: 10),
            AppButton.secondary(onPressed: _redeeming ? null : _redeem, loading: _redeeming, child: const Text('Use code')),
          ]),
        ),
      _Block(
        title: 'Product updates by email',
        description: 'An occasional email about new features. Unsubscribe from any email.',
        trailing: _updates == null ? null : AppSwitch(value: _updates!, onChanged: _setUpdates, label: 'Product updates by email'),
      ),
      _Block(
        title: 'Rate DSCVR',
        description: _stars == null ? 'Tell us how DSCVR is working for you. It takes ten seconds.' : 'You rated DSCVR $_stars out of 5. Thank you. Tap to change it.',
        trailing: Semantics(
          button: true,
          label: 'Rate DSCVR',
          child: Pressable(
            onTap: () async {
              final stars = await showRateApp(context, initial: _stars ?? 0);
              if (stars != null && mounted) setState(() => _stars = stars);
            },
            child: StarRating(value: _stars ?? 0, size: 22),
          ),
        ),
      ),
      if (Growth.needsVerification(Env.demo ? null : FirebaseAuth.instance.currentUser))
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Text('Your email is not verified yet. Look for our email, or use Resend at the top of the page.',
              style: AppTheme.sans(fontSize: 12.5, color: c.inkMuted)),
        ),
    ]);
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.description, this.child, this.trailing});
  final String title;
  final String description;
  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTheme.sans(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.ink)),
              const SizedBox(height: 3),
              Text(description, style: AppTheme.sans(fontSize: 13, color: c.inkMuted, height: 1.45)),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ]),
        if (child != null) ...[const SizedBox(height: 12), child!],
      ]),
    );
  }
}

/// Asks for 1-5 stars and an optional comment. Returns the stars saved.
Future<int?> showRateApp(BuildContext context, {int initial = 0}) {
  return showAdaptiveSheet<int>(context, builder: (_) => _RateSheet(initial: initial));
}

class _RateSheet extends StatefulWidget {
  const _RateSheet({required this.initial});
  final int initial;

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  late int _stars = widget.initial;
  final _comment = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_stars < 1) return;
    setState(() => _saving = true);
    try {
      if (!Env.demo) {
        await context.services.api.post('/feedback/rating', {
          'stars': _stars,
          'comment': _comment.text.trim(),
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(_stars);
      toast(context, 'Thanks for rating DSCVR');
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const labels = ['', 'Not for me', 'Needs work', "It's okay", 'Really good', 'I love it'];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHeader(title: 'Rate DSCVR', subtitle: 'How is DSCVR working for you?'),
          Center(child: StarRating(value: _stars, size: 36, spacing: 8, onChanged: (v) => setState(() => _stars = v))),
          const SizedBox(height: 8),
          Center(child: Text(labels[_stars.clamp(0, 5)], style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted))),
          const SizedBox(height: 16),
          AppField(
            controller: _comment,
            label: _stars > 0 && _stars <= 3 ? 'What should we fix? (optional)' : 'Anything to add? (optional)',
            minLines: 2,
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            AppButton.ghost(onPressed: () => Navigator.of(context).pop(), child: const Text('Not now')),
            const SizedBox(width: 8),
            AppButton.primary(onPressed: _stars < 1 || _saving ? null : _save, loading: _saving, child: const Text('Send')),
          ]),
        ]),
      ),
    );
  }
}
