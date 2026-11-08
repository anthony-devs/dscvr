import 'package:dscvr/models/citation.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/download/download.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

export 'package:dscvr/models/citation.dart' show CiteSource, CiteStyle;

/// The last style picked, so the next citation opens in it.
CiteStyle _lastStyle = CiteStyle.apa;

/// A sheet that formats one or more sources in any style, copies them, and
/// exports BibTeX or RIS for Zotero, Mendeley and EndNote.
Future<void> showCiteSheet(BuildContext context, CiteSource source) => showCiteSheetFor(context, [source]);

Future<void> showCiteSheetFor(BuildContext context, List<CiteSource> sources) => showAdaptiveSheet<void>(
      context,
      maxWidth: 620,
      builder: (ctx) => _CiteSheet(sources: sources),
    );

class _CiteSheet extends StatefulWidget {
  const _CiteSheet({required this.sources});
  final List<CiteSource> sources;

  @override
  State<_CiteSheet> createState() => _CiteSheetState();
}

class _CiteSheetState extends State<_CiteSheet> {
  late CiteStyle _style = widget.sources.every((s) => s.isJudgment) && !_lastStyle.isLegal ? CiteStyle.oscola : _lastStyle;

  List<String> get _formatted => [for (final s in widget.sources) Citations.format(s, _style)];

  Future<void> _copy() async {
    final text = _formatted.map(Citations.plain).join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) toast(context, widget.sources.length == 1 ? 'Citation copied' : '${widget.sources.length} citations copied');
  }

  void _export(String ext) {
    final text = ext == 'bib' ? Citations.bibtex(widget.sources) : Citations.ris(widget.sources);
    if (canDownload) {
      downloadText('dscvr-references.$ext', text, mime: ext == 'bib' ? 'application/x-bibtex' : 'application/x-research-info-systems');
    } else {
      Clipboard.setData(ClipboardData(text: text));
      toast(context, '${ext == 'bib' ? 'BibTeX' : 'RIS'} copied');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final many = widget.sources.length > 1;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetHeader(
        title: many ? 'Cite ${widget.sources.length} items' : 'Cite',
        subtitle: 'Check every citation against your style guide before you submit.',
      ),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppSelect<CiteStyle>(
              label: 'Style',
              options: [for (final s in CiteStyle.values) SelectOption(s, s.label)],
              value: _style,
              onChanged: (s) => setState(() => _style = _lastStyle = s),
            ),
            const SizedBox(height: 16),
            for (final f in _formatted)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: c.line),
                ),
                child: SelectableText.rich(_rich(f, AppTheme.serif(fontSize: 15, color: c.ink, height: 1.5))),
              ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              AppButton.primary(onPressed: _copy, icon: const Icon(Ic.copy, size: 15), label: Text(many ? 'Copy all' : 'Copy')),
              AppButton.secondary(onPressed: () => _export('bib'), label: const Text('BibTeX')),
              AppButton.secondary(onPressed: () => _export('ris'), label: const Text('RIS (EndNote, Zotero)')),
            ]),
            if (widget.sources.any((s) => s.isJudgment && s.caseCitation == null)) ...[
              const SizedBox(height: 14),
              Text('Add the law report citation (for example NWLR or LPELR) by hand. DSCVR never guesses one.',
                  style: AppTheme.sans(fontSize: 12.5, color: c.inkFaint, height: 1.45)),
            ],
          ]),
        ),
      ),
    ]);
  }

  /// Renders *italic* spans from the formatter.
  static TextSpan _rich(String s, TextStyle base) {
    final spans = <TextSpan>[];
    final parts = s.split('*');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(text: parts[i], style: i.isOdd ? base.copyWith(fontStyle: FontStyle.italic) : base));
    }
    return TextSpan(children: spans, style: base);
  }
}
