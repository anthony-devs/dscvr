import 'package:dscvr/models/paper.dart';
import 'package:dscvr/screens/add/add_material_sheet.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/cite_sheet.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/pdf/dscvr_pdf_viewer.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens a search result's PDF in DSCVR's reader without saving it first.
void openPdfReader(BuildContext context, Paper p) => context.push('/read', extra: p);

/// Reads a PDF that isn't in the library yet. Asking Pinda saves it first,
/// so Pinda can read the whole paper, then continues in the full reader.
class PdfReadPage extends StatelessWidget {
  const PdfReadPage({super.key, this.paper});
  final Paper? paper;

  Future<void> _saveThen(BuildContext context, {String? ask}) async {
    final item = await savePaperFlow(context, paper!);
    if (item == null || !context.mounted) return;
    context.pushReplacement('/m/${item.id}', extra: ask);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = paper;
    if (p == null || p.pdfUrl == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Ic.pdf,
          title: 'Nothing to read',
          message: 'Open a paper from Discover or your library.',
          action: AppButton.secondary(onPressed: () => context.go('/discover'), child: const Text('Go to Discover')),
        ),
      );
    }
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: AppIconButton(
          tooltip: 'Back',
          icon: const Icon(Ic.back, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/discover'),
        ),
        titleSpacing: 0,
        title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: AppTheme.sans(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
        actions: [
          AppIconButton(tooltip: 'Cite', onPressed: () => showCiteSheet(context, CiteSource.fromPaper(p)), icon: const Icon(Ic.quote, size: 19)),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: AppButton.primary(
              size: BtnSize.sm,
              onPressed: () => _saveThen(context),
              icon: const Icon(Ic.add, size: 15),
              label: const Text('Save to library'),
            ),
          ),
        ],
      ),
      body: DscvrPdfViewer(
        url: p.pdfUrl!,
        title: p.title,
        onAsk: (passage) => _saveThen(context, ask: passage),
        onNote: (passage) => _saveThen(context),
        onFactCheck: (passage) => _saveThen(context, ask: passage),
      ),
    );
  }
}
