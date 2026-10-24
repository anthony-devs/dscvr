// auth_widgets.dart
// Shared widgets used by both signup.dart and login.dart.
// Restyled onto the DSCVR theme (light + dark); public APIs are unchanged.

import 'package:dscvr/models/library.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/material_card.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// LOGO
// ══════════════════════════════════════════════════════════════════════════════

class DscvrLogo extends StatelessWidget {
  const DscvrLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const DscvrMark(size: 52),
        const SizedBox(height: 12),
        Text(
          'DSCVR',
          style: AppTheme.sans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
            color: context.colors.ink,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LAYOUT
// ══════════════════════════════════════════════════════════════════════════════

/// Auth page frame: a showcase panel on wide screens, the form on the right.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.form, required this.footer});

  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final formColumn = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!wide) ...[const Center(child: DscvrLogo()), const SizedBox(height: 32)],
            Text(title, style: context.text.displaySmall, textAlign: wide ? TextAlign.start : TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: AppTheme.sans(fontSize: 14.5, color: c.inkMuted, height: 1.5),
                textAlign: wide ? TextAlign.start : TextAlign.center),
            const SizedBox(height: 28),
            form,
            const SizedBox(height: 28),
            footer,
          ]),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: wide
            ? Row(children: [
                const Expanded(flex: 11, child: _Showcase()),
                Expanded(flex: 9, child: formColumn),
              ])
            : formColumn,
      ),
    );
  }
}

/// Decorative collage of sample material cards for the auth screens.
class _Showcase extends StatelessWidget {
  const _Showcase();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    LibraryItem sample(String t, List<String> a, int y, int color, double p, int n) => LibraryItem(
        id: t, kind: MaterialKind.paper, title: t, authors: a, year: y, categoryId: '', colorIndex: color,
        progress: p, noteCount: n, createdAt: now, updatedAt: now);
    final cards = [
      (sample('The Market for "Lemons"', ['George A. Akerlof'], 1970, 3, 1, 3), 'Economics'),
      (sample('Attention Is All You Need', ['Ashish Vaswani', 'Noam Shazeer', 'Niki Parmar'], 2017, 0, 0.6, 4), 'Computer Science'),
      (sample('A Mathematical Theory of Communication', ['Claude E. Shannon'], 1948, 5, 0.3, 2), 'Information'),
      (sample('The Neural Basis of Loss Aversion', ['Sabrina M. Tom', 'Craig R. Fox'], 2007, 1, 0.8, 1), 'Neuroscience'),
    ];
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: c.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Wordmark(size: 28),
        const Spacer(),
        Text('A quiet place\nfor serious reading.', style: context.text.displayMedium),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text(
            'Collect papers, PDFs, articles and lectures into one library. Read without noise, take notes, and ask Pinda about anything you have saved.',
            style: AppTheme.sans(fontSize: 15, color: c.inkMuted, height: 1.6),
          ),
        ),
        const SizedBox(height: 32),
        IgnorePointer(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: MaterialGrid(minTileWidth: 120, children: [
              for (final (item, label) in cards) MaterialCard(item: item, collectionLabel: label, onTap: () {}),
            ]),
          ),
        ),
        const Spacer(),
        Text('Free forever. Supported by readers.', style: context.text.labelMedium),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FIELD
// ══════════════════════════════════════════════════════════════════════════════

class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final String? suffixLabel;
  final VoidCallback? onSuffixTap;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.suffixLabel,
    this.onSuffixTap,
    this.onFieldSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: AppTheme.sans(fontSize: 15, color: c.ink),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        suffixIcon: suffixLabel == null
            ? null
            : TextButton(
                onPressed: onSuffixTap,
                child: Text(suffixLabel!, style: AppTheme.sans(fontSize: 12.5, color: c.inkMuted)),
              ),
        errorStyle: AppTheme.sans(fontSize: 12, color: c.danger),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BUTTONS
// ══════════════════════════════════════════════════════════════════════════════

class AuthButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const AuthButton({super.key, required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: loading ? null : onTap,
        child: loading
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.inverseInk))
            : Text(label),
      ),
    );
  }
}

class GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const GoogleButton({super.key, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: loading ? null : onTap,
        style: OutlinedButton.styleFrom(backgroundColor: context.colors.surface),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 18, height: 18, child: CustomPaint(painter: _GoogleLogoPainter())),
          const SizedBox(width: 10),
          Text('Continue with Google', style: AppTheme.sans(fontSize: 14, fontWeight: FontWeight.w500, color: context.colors.ink)),
        ]),
      ),
    );
  }
}

/// The four-colour Google "G", drawn so no image asset is needed.
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, s - stroke, s - stroke);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = 3.14159265 / 180;
    canvas.drawArc(rect, -40 * deg, -100 * deg, false, p(const Color(0xFFEA4335)));
    canvas.drawArc(rect, -140 * deg, -90 * deg, false, p(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, -230 * deg, -95 * deg, false, p(const Color(0xFF34A853)));
    canvas.drawArc(rect, -325 * deg, -35 * deg, false, p(const Color(0xFF4285F4)));
    canvas.drawRect(
      Rect.fromLTWH(s * 0.5, s * 0.5 - stroke / 2, s * 0.5, stroke),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Expanded(child: Divider(color: c.line)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('or', style: AppTheme.sans(fontSize: 12.5, color: c.inkFaint)),
      ),
      Expanded(child: Divider(color: c.line)),
    ]);
  }
}

class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({super.key, required this.prompt, required this.action, required this.onTap});
  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(prompt, style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted)),
      TextButton(onPressed: onTap, child: Text(action, style: AppTheme.sans(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.ink))),
    ]);
  }
}
