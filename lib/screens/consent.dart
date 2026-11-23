import 'dart:async';

import 'package:dscvr/config/env.dart';
import 'package:dscvr/data/api.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const termsUrl = 'https://www.askpinda.com/terms';
const privacyUrl = 'https://www.askpinda.com/privacy';

/// The two tickboxes shown at sign-up and in the terms prompt: accepting the
/// Terms and Privacy Policy (needed), and getting product updates (optional, off
/// until the person ticks it).
class ConsentChecks extends StatefulWidget {
  const ConsentChecks({
    super.key,
    required this.terms,
    required this.updates,
    required this.onTerms,
    required this.onUpdates,
    this.showError = false,
  });

  final bool terms;
  final bool updates;
  final ValueChanged<bool> onTerms;
  final ValueChanged<bool> onUpdates;
  final bool showError;

  @override
  State<ConsentChecks> createState() => _ConsentChecksState();
}

class _ConsentChecksState extends State<ConsentChecks> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()..onTap = () => _open(termsUrl);
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()..onTap = () => _open(privacyUrl);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = AppTheme.sans(fontSize: 13, color: c.ink);
    final link = base.copyWith(decoration: TextDecoration.underline, fontWeight: FontWeight.w600);
    Widget row(bool value, ValueChanged<bool> onChanged, Widget label) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(!value),
                child: Padding(padding: const EdgeInsets.only(top: 5), child: label),
              ),
            ),
          ],
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      row(
        widget.terms,
        widget.onTerms,
        Text.rich(TextSpan(style: base, children: [
          const TextSpan(text: 'I agree to the '),
          TextSpan(text: 'Terms', style: link, recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
          const TextSpan(text: '.'),
        ])),
      ),
      if (widget.showError && !widget.terms)
        Padding(
          padding: const EdgeInsets.only(left: 34, top: 2),
          child: Text('Please accept to continue.', style: AppTheme.sans(fontSize: 12, color: c.danger)),
        ),
      const SizedBox(height: 6),
      row(
        widget.updates,
        widget.onUpdates,
        Text('Send me product updates and study tips now and then. I can unsubscribe in one click.', style: base),
      ),
    ]);
  }
}

/// Asks people who haven't accepted the current terms (Google sign-ups, and anyone
/// before consent existed) once, and stores the answer.
class Consent {
  Consent._();

  static Future<void> ensure(DscvrApi api, BuildContext? Function() context) async {
    if (Env.demo) return;
    try {
      // New email sign-ups send their answer a moment after the account exists.
      await Future<void>.delayed(const Duration(seconds: 3));
      final r = await api.get('/me/consent');
      if (r['terms'] == true) return;
      final ctx = context();
      if (ctx == null || !ctx.mounted) return;
      await showDialog<void>(context: ctx, barrierDismissible: false, builder: (_) => _ConsentDialog(api: api));
    } catch (_) {
      // Try again next time the app opens.
    }
  }
}

class _ConsentDialog extends StatefulWidget {
  const _ConsentDialog({required this.api});
  final DscvrApi api;

  @override
  State<_ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<_ConsentDialog> {
  bool _terms = false;
  bool _updates = false;
  bool _busy = false;
  bool _tried = false;
  String? _error;

  Future<void> _save() async {
    if (!_terms) {
      setState(() => _tried = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.post('/me/consent', {'terms': true, if (_updates) 'updates': true});
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('One quick thing'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Before you carry on, please confirm you have read how DSCVR works and how we handle your data.',
                style: AppTheme.sans(fontSize: 14, color: c.inkMuted)),
            const SizedBox(height: 16),
            ConsentChecks(
              terms: _terms,
              updates: _updates,
              onTerms: (v) => setState(() => _terms = v),
              onUpdates: (v) => setState(() => _updates = v),
              showError: _tried,
            ),
            if (_error != null)
              Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: AppTheme.sans(fontSize: 12, color: c.danger))),
          ]),
        ),
        actions: [
          AppButton.primary(onPressed: _busy ? null : _save, loading: _busy, child: const Text('Continue')),
        ],
      ),
    );
  }
}
