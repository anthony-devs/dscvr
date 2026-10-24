import 'package:dscvr/models/auth.dart';
import 'package:dscvr/screens/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  final DSCVRAuth _auth = DSCVRAuth();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      await _auth.signInWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      // DSCVRAuth().userStream emits the signed-in user →
      // StreamBuilder in main.dart rebuilds → navigates to HomePage.
      // No manual Navigator call needed here, same as signup.
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
      // Same pattern — auth state change handles navigation automatically.
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

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email above first')),
      );
      return;
    }
    try {
      // Fix: was _auth.sendPasswordReset — correct name is sendPasswordResetEmail
      await _auth.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    } on DSCVRAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send reset email')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to pick up where you left off.',
      form: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              suffixLabel: _obscure ? 'Show' : 'Hide',
              onSuffixTap: () => setState(() => _obscure = !_obscure),
              validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _forgotPassword, child: const Text('Forgot password?')),
            ),
            const SizedBox(height: 8),
            AuthButton(label: 'Sign in', loading: _loading, onTap: _submit),
            const SizedBox(height: 18),
            const OrDivider(),
            const SizedBox(height: 18),
            GoogleButton(loading: _loading, onTap: _googleSignIn),
          ]),
        ),
      ),
      footer: AuthSwitchLink(
        prompt: "Don't have an account?",
        action: 'Create one',
        onTap: () => context.go('/signup'),
      ),
    );
  }
}
