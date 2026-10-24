import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lightweight markdown renderer for Pinda replies, notes and article text.
///
/// Supports headings, paragraphs, bullet and numbered lists, block quotes,
/// fenced code, horizontal rules, and inline bold, italic, code and links.
class MarkdownView extends StatefulWidget {
  const MarkdownView(this.source, {super.key, this.scale = 1.0, this.serifBody = false});

  final String source;
  final double scale;

  /// Use the serif face for body text (long-form reading).
  final bool serifBody;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final c = context.colors;
    final s = widget.scale;
    final body = widget.serifBody
        ? AppTheme.serif(fontSize: 17.5 * s, height: 1.65, color: c.ink)
        : AppTheme.sans(fontSize: 14.5 * s, height: 1.6, color: c.ink);

    final blocks = <Widget>[];
    final lines = widget.source.replaceAll('\r\n', '\n').split('\n');
    var i = 0;
    final para = <String>[];

    void flushPara() {
      if (para.isEmpty) return;
      blocks.add(_spaced(Text.rich(_inline(para.join(' '), body, c))));
      para.clear();
    }

    while (i < lines.length) {
      final raw = lines[i];
      final line = raw.trimRight();
      final t = line.trimLeft();

      if (t.startsWith('```')) {
        flushPara();
        final code = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          code.add(lines[i]);
          i++;
        }
        i++;
        blocks.add(_spaced(Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: c.line),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(code.join('\n'), style: AppTheme.mono(fontSize: 12.5 * s, color: c.ink)),
          ),
        )));
        continue;
      }

      if (t.isEmpty) {
        flushPara();
        i++;
        continue;
      }

      final heading = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(t);
      if (heading != null) {
        flushPara();
        final level = heading.group(1)!.length;
        final size = switch (level) { 1 => 24.0, 2 => 20.0, 3 => 17.0, _ => 15.0 } * s;
        blocks.add(Padding(
          padding: EdgeInsets.only(top: blocks.isEmpty ? 0 : 10, bottom: 6),
          child: Text.rich(_inline(heading.group(2)!,
              AppTheme.serif(fontSize: size, fontWeight: FontWeight.w600, height: 1.3, color: c.ink), c)),
        ));
        i++;
        continue;
      }

      if (RegExp(r'^(-{3,}|\*{3,})$').hasMatch(t)) {
        flushPara();
        blocks.add(_spaced(Divider(color: c.line)));
        i++;
        continue;
      }

      if (t.startsWith('>')) {
        flushPara();
        final quote = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
          quote.add(lines[i].trimLeft().substring(1).trim());
          i++;
        }
        blocks.add(_spaced(Container(
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: c.inkFaint, width: 2.5))),
          child: Text.rich(_inline(quote.join(' '), body.copyWith(color: c.inkMuted, fontStyle: FontStyle.italic), c)),
        )));
        continue;
      }

      final bullet = RegExp(r'^[-*+]\s+(.*)$');
      final number = RegExp(r'^(\d+)[.)]\s+(.*)$');
      if (bullet.hasMatch(t) || number.hasMatch(t)) {
        flushPara();
        final items = <Widget>[];
        while (i < lines.length) {
          final l = lines[i].trimLeft();
          final indent = lines[i].length - l.length;
          final b = bullet.firstMatch(l);
          final n = number.firstMatch(l);
          if (b == null && n == null) break;
          final marker = n != null ? '${n.group(1)}.' : '•';
          final content = n != null ? n.group(2)! : b!.group(1)!;
          items.add(Padding(
            padding: EdgeInsets.only(left: indent >= 2 ? 18.0 : 0, bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: n != null ? 24 * s : 16 * s,
                child: Text(marker, style: body.copyWith(color: c.inkMuted)),
              ),
              Expanded(child: Text.rich(_inline(content, body, c))),
            ]),
          ));
          i++;
        }
        blocks.add(_spaced(Column(crossAxisAlignment: CrossAxisAlignment.start, children: items)));
        continue;
      }

      para.add(t);
      i++;
    }
    flushPara();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }

  Widget _spaced(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: w);

  static final _inlinePattern = RegExp(
      r'(\*\*[^*]+\*\*)|(__[^_]+__)|(`[^`]+`)|(\[[^\]]+\]\([^)\s]+\))|(\*[^*\s][^*]*\*)|(_[^_\s][^_]*_)');

  TextSpan _inline(String text, TextStyle base, DscvrColors c) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inlinePattern.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final tok = m.group(0)!;
      if (m.group(1) != null || m.group(2) != null) {
        spans.add(TextSpan(text: tok.substring(2, tok.length - 2), style: const TextStyle(fontWeight: FontWeight.w700)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
          text: tok.substring(1, tok.length - 1),
          style: AppTheme.mono(fontSize: (base.fontSize ?? 14) * 0.88, color: c.ink)
              .copyWith(backgroundColor: c.surfaceMuted),
        ));
      } else if (m.group(4) != null) {
        final lm = RegExp(r'^\[([^\]]+)\]\(([^)\s]+)\)$').firstMatch(tok)!;
        final url = lm.group(2)!;
        final r = TapGestureRecognizer()
          ..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        _recognizers.add(r);
        spans.add(TextSpan(
          text: lm.group(1),
          recognizer: r,
          style: TextStyle(decoration: TextDecoration.underline, decorationColor: c.inkFaint),
        ));
      } else {
        spans.add(TextSpan(text: tok.substring(1, tok.length - 1), style: const TextStyle(fontStyle: FontStyle.italic)));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: base, children: spans);
  }
}
