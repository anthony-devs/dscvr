// auth_widgets.dart
// Shared widgets used by both signup.dart and login.dart.
// Import this file in both pages.

import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// LOGO
// ══════════════════════════════════════════════════════════════════════════════

class DscvrLogo extends StatelessWidget {
  const DscvrLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo mark — 2×2 grid of shapes
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: CustomPaint(painter: _LogoMarkPainter()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'DSCVR',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.4,
            color: Color(0xFF111111),
          ),
        ),
      ],
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final half = size.width / 2;
    final gap = 2.0;
    final tile = half - gap;

    // top-left: square
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, tile, tile),
        const Radius.circular(3),
      ),
      paint,
    );

    // top-right: circle
    paint.color = Colors.white.withOpacity(0.5);
    canvas.drawCircle(
      Offset(half + gap + tile / 2, tile / 2),
      tile / 2,
      paint,
    );

    // bottom-left: circle
    canvas.drawCircle(
      Offset(tile / 2, half + gap + tile / 2),
      tile / 2,
      paint,
    );

    // bottom-right: square
    paint.color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(half + gap, half + gap, tile, tile),
        const Radius.circular(3),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
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
    return AutofillGroup(
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        style: const TextStyle(
          fontFamily: 'Geist',
          fontSize: 16, // 16px stops iOS auto-zoom on focus
          color: Color(0xFF111111),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 15,
            color: Color(0xFFCCCCCC),
          ),
          filled: true,
          fillColor: const Color(0xFFFAF9F6),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: suffixLabel != null
              ? GestureDetector(
                  onTap: onSuffixTap,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Text(
                      suffixLabel!,
                      style: const TextStyle(
                        fontFamily: 'DMMono',
                        fontSize: 11,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ),
                )
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0DDD6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0DDD6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF999999)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDDAA99)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCC6655)),
          ),
          errorStyle: const TextStyle(
            fontFamily: 'DMMono',
            fontSize: 10.5,
            color: Color(0xFFCC6655),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PRIMARY BUTTON
// ══════════════════════════════════════════════════════════════════════════════

class AuthButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const AuthButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF111111),
          disabledBackgroundColor: const Color(0xFF444444),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GOOGLE BUTTON
// ══════════════════════════════════════════════════════════════════════════════

class GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const GoogleButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: loading ? null : onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE0DDD6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF333333),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google G logo via CustomPaint
            SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(painter: _GoogleLogoPainter()),
            ),
            const SizedBox(width: 10),
            const Text(
              'Continue with Google',
              style: TextStyle(
                fontFamily: 'DMMono',
                fontSize: 13,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Simplified Google G mark
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..style = PaintingStyle.fill;

    // Blue arc (top)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -1.57, 3.14, true, paint);

    // Green arc (bottom-right)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.57, 1.0, true, paint);

    // Yellow arc (bottom-left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.57, 0.9, true, paint);

    // Red arc (left)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -1.57, -1.2, true, paint);

    // White centre cutout
    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.32,
      paint,
    );

    // White right bar (the inner part of G)
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.5, size.height * 0.38,
          size.width * 0.5, size.height * 0.24),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// OR DIVIDER
// ══════════════════════════════════════════════════════════════════════════════

class OrDivider extends StatelessWidget {
  const OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: Color(0xFFECE9E2), thickness: 1),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(
              fontFamily: 'DMMono',
              fontSize: 11,
              color: Color(0xFFCCCCCC),
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: Color(0xFFECE9E2), thickness: 1),
        ),
      ],
    );
  }
}