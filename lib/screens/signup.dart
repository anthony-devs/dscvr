import 'package:dscvr/models/auth.dart';
import 'package:dscvr/screens/login.dart';
import 'package:flutter/material.dart';
import 'auth_widgets.dart';
class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

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
      // StreamBuilder in main.dart handles navigation automatically
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 64),

                    // ── Logo ──────────────────────────────────────────────
                    const DscvrLogo(),
                    const SizedBox(height: 32),

                    // ── Title ─────────────────────────────────────────────
                    const Text(
                      'Create your account',
                      style: TextStyle(
                        fontFamily: 'InstrumentSerif',
                        fontSize: 26,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Fields ────────────────────────────────────────────
                    AuthField(
                      controller: _nameCtrl,
                      hint: 'Full name',
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Name is required' : null,
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
                      suffixLabel: _obscure ? 'show' : 'hide',
                      onSuffixTap: () =>
                          setState(() => _obscure = !_obscure),
                      validator: (v) => (v?.length ?? 0) < 6
                          ? 'Password must be 6+ characters'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // ── Submit ────────────────────────────────────────────
                    AuthButton(
                      label: 'Continue',
                      loading: _loading,
                      onTap: _submit,
                    ),
                    const SizedBox(height: 16),

                    // ── Divider ───────────────────────────────────────────
                    const OrDivider(),
                    const SizedBox(height: 14),

                    // ── Google ────────────────────────────────────────────
                    GoogleButton(
                      loading: _loading,
                      onTap: _googleSignIn,
                    ),
                    const SizedBox(height: 24),

                    // ── Terms ─────────────────────────────────────────────
                    Text.rich(
                      TextSpan(
                        text: "By signing up you agree to DSCVR's ",
                        children: [
                          TextSpan(
                            text: 'Terms',
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                              color: Color(0xFF555555),
                            ),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ],
                        style: const TextStyle(
                          fontFamily: 'DMMono',
                          fontSize: 10.5,
                          color: Color(0xFFAAAAAA),
                          height: 1.7,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const Spacer(),

                    // ── Login link ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'already have an account? ',
                            style: TextStyle(
                              fontFamily: 'DMMono',
                              fontSize: 11.5,
                              color: Color(0xFFAAAAAA),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            ),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                fontFamily: 'DMMono',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF111111),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}