import 'package:dscvr/models/pinda.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/widgets.dart';

/// The three ways DSCVR is used. One app; the edition tailors the home
/// screen, wording, Pinda's tone and which tools are put first.
enum Edition {
  students(
    label: 'DSCVR Students',
    short: 'Students',
    tagline: 'Study smarter from your own notes, readings and lectures.',
    icon: Ic.students,
    price: 'Free',
    amount: r'$0',
    unit: '/forever',
    forWho: 'Perfect for students and exam prep',
  ),
  researchers(
    label: 'DSCVR Researchers',
    short: 'Researchers',
    tagline: 'Find, read and write up research with an assistant that knows your sources.',
    icon: Ic.researchers,
    price: 'Free',
    amount: r'$0',
    unit: '/forever',
    forWho: 'Perfect for researchers and postgrads',
  ),
  enterprise(
    label: 'DSCVR Enterprise',
    short: 'Enterprise',
    tagline: 'A shared research desk for teams, billed only for what you use.',
    icon: Ic.enterprise,
    price: 'Usage-based',
    amount: r'$0.40',
    unit: '/member a day',
    forWho: 'For labs, companies and departments',
  );

  const Edition({
    required this.label,
    required this.short,
    required this.tagline,
    required this.icon,
    required this.price,
    required this.amount,
    required this.unit,
    required this.forWho,
  });

  final String label;
  final String short;
  final String tagline;
  final IconData icon;
  final String price;

  /// Big price on the plan card, and what it is per.
  final String amount;
  final String unit;

  /// One line under the price: who the plan is for.
  final String forWho;

  /// Small print under the price block.
  String get priceNote => switch (this) {
        Edition.enterprise => r'Only on days they use DSCVR. Never more than $8 a member a month.',
        Edition.students => r'No card needed. Want more Pinda? Student Plus is $4.99/mo.',
        Edition.researchers => r'No card needed. Want more Pinda? Research Plus is $9.99/mo.',
      };

  static Edition parse(String? v, {String? role}) {
    for (final e in Edition.values) {
      if (e.name == v) return e;
    }
    // Older profiles only stored a free-text role.
    if (role != null && role.toLowerCase().contains('student')) return Edition.students;
    return Edition.researchers;
  }

  /// Everything the plan includes, shown as a checklist on the plan card.
  /// Only list things the app really does.
  List<String> get highlights => switch (this) {
        Edition.students => const [
            'Pinda, your AI tutor, free every day',
            'Pinda explains any reading in plain language',
            'Study notes and summaries from your sources',
            'Study guides and "Quiz me" on your own notes',
            'Focus sessions with a timer and an AI recap',
            'Live study rooms with friends: chat and a shared timer',
            'Voice notes: dictate during lectures',
            'Ask Pinda out loud and hear the answer',
            'Save PDFs, links, YouTube lectures and notes',
            'Notes on any material, organised by subject',
            'Rate your materials and sort by what mattered',
            'Phone, tablet and laptop, always in sync',
          ],
        Edition.researchers => const [
            'Paste an arXiv link: the full PDF lands in your library',
            'Search arXiv and Semantic Scholar together',
            'Related papers next to everything you read',
            'Pinda reads your PDFs and cites them, free every day',
            'Literature reviews drafted from the sources you pick',
            'Executive summaries and paper comparisons',
            'Edit reports, then export them as Markdown',
            'Parliament fact-check: three AI readers vote on a claim',
            'Rate papers and see how other readers rated them',
            'Voice notes and spoken questions while you read',
            'Focus sessions and live research rooms',
            'Share any material to view, comment or fork',
            'Every device in sync; sign out any of them remotely',
          ],
        Edition.enterprise => const [
            'Everything in Researchers, for every member',
            'No daily Pinda limit',
            'One organisation with invite codes',
            'Admin and member roles',
            'Team study and research rooms with shared papers',
            'Live usage dashboard for admins',
            'One monthly invoice for the whole team',
            'Pay only for days people use it',
            r'Capped at $8 a member each month',
            'AI billed by the tokens you use, no flat fee',
            'Add or remove members any time',
          ],
      };

  /// Pinda shortcuts shown first for this edition.
  List<PindaAction> get pindaActions => switch (this) {
        Edition.students => const [PindaAction.explain, PindaAction.studyGuide, PindaAction.quiz, PindaAction.summarize],
        Edition.researchers => const [PindaAction.summarize, PindaAction.questions, PindaAction.factCheck, PindaAction.explain],
        Edition.enterprise => const [PindaAction.summarize, PindaAction.questions, PindaAction.factCheck, PindaAction.studyGuide],
      };

  /// The report types offered first.
  List<ReportKind> get reportKinds => switch (this) {
        Edition.students => const [ReportKind.studyNotes, ReportKind.summary, ReportKind.comparison, ReportKind.literatureReview],
        _ => const [ReportKind.literatureReview, ReportKind.summary, ReportKind.comparison, ReportKind.studyNotes],
      };

  String get sessionNoun => this == Edition.students ? 'study session' : 'research session';
}

/// Kinds of report Pinda can draft. Names match the server's REPORT_KINDS.
enum ReportKind {
  literatureReview('literature_review', 'Literature review', 'Themes, agreements, disagreements and gaps across your sources.'),
  summary('summary', 'Executive summary', 'Key findings, why they matter and what to do next.'),
  studyNotes('study_notes', 'Study notes', 'Concepts, definitions, arguments and review questions.'),
  comparison('comparison', 'Comparison', 'Aims, methods, results and limitations side by side.');

  const ReportKind(this.wire, this.label, this.description);
  final String wire;
  final String label;
  final String description;

  static ReportKind parse(String? v) =>
      ReportKind.values.firstWhere((k) => k.wire == v || k.name == v, orElse: () => ReportKind.summary);
}
