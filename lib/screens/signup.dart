import 'package:dscvr/models/auth.dart';
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await _auth.registerWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        displayName: _nameCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully')),
      );
      // The router redirects to onboarding once the session updates.
    } on DSCVRAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google sign-in failed')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your library',
      subtitle: 'Free forever. Your materials stay private unless you share them.',
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
            const SizedBox(height: 20),
            AuthButton(label: 'Create account', loading: _loading, onTap: _submit),
            const SizedBox(height: 18),
            const OrDivider(),
            const SizedBox(height: 18),
            GoogleButton(loading: _loading, onTap: _googleSignIn),
            const SizedBox(height: 18),
            Text(
              "By signing up you agree to DSCVR's Terms and Privacy Policy.",
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
