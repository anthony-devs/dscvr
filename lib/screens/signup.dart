import 'dart:async';

import 'package:dscvr/data/api.dart';
import 'package:dscvr/models/auth.dart';
import 'package:dscvr/screens/consent.dart';
import 'package:dscvr/screens/growth/growth.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth_widgets.dart';
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final DSCVRAuth _auth = DSCVRAuth();
  bool _obscure = true;
  bool _loading = false;
  bool _terms = false;
  bool _updates = false;
  bool _tried = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Runs after the account exists, even if the page has already moved on:
  /// records the consent choices, then sends the branded verification email.
  static Future<void> _afterSignup(DscvrApi api, bool updates) async {
    try {
      await api.post('/me/consent', {'terms': true, 'updates': updates});
    } catch (_) {
      // The terms prompt asks again on first open if this didn't reach the server.
    }
    try {
      await Growth.sendVerification(api);
    } catch (_) {
      // The banner in the app offers "Resend".
    }
  }

  Future<void> _submit() async {
    setState(() => _tried = true);
    if (!(_formKey.currentState?.validate() ?? false) || !_terms) return;
    final api = context.services.api;
    final updates = _updates;
    setState(() => _loading = true);
    try {
      await _auth.registerWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        displayName: _nameCtrl.text.trim(),
      );
      unawaited(_afterSignup(api, updates));
      if (!mounted) return;
      Toasts.success(context, 'Account created successfully');
      // The router redirects to onboarding once the session updates.
    } on DSCVRAuthException catch (e) {
      if (!mounted) return;
      Toasts.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      Toasts.error(context, 'Something went wrong');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      await _auth.signInWithGoogle();
    } on DSCVRAuthException catch (e) {
      if (!mounted) return;
      Toasts.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      Toasts.error(context, 'Google sign-in failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your library',
      subtitle: 'Free to start. Your materials stay private unless you share them.',
      form: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AuthField(
              controller: _nameCtrl,
              hint: 'Full name',
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            AuthField(
              controller: _emailCtrl,
              hint: 'Email address',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 12),
            AuthField(
              controller: _passCtrl,
              hint: 'Password',
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => _submit(),
              suffixLabel: _obscure ? 'Show' : 'Hide',
              onSuffixTap: () => setState(() => _obscure = !_obscure),
              validator: (v) => (v?.length ?? 0) < 6 ? 'Password must be 6+ characters' : null,
            ),
            const SizedBox(height: 16),
            ConsentChecks(
              terms: _terms,
              updates: _updates,
              onTerms: (v) => setState(() => _terms = v),
              onUpdates: (v) => setState(() => _updates = v),
              showError: _tried,
            ),
            const SizedBox(height: 16),
            AuthButton(label: 'Create account', loading: _loading, onTap: _submit),
            const SizedBox(height: 18),
            const OrDivider(),
            const SizedBox(height: 18),
            GoogleButton(loading: _loading, onTap: _googleSignIn),
            const SizedBox(height: 18),
            Text(
              "Continuing with Google means you agree to DSCVR's Terms and Privacy Policy.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]),
        ),
      ),
      footer: AuthSwitchLink(
        prompt: 'Already have an account?',
        action: 'Sign in',
        onTap: () => context.go('/login'),
      ),
    );
  }
}
