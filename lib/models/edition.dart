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
  ),
  researchers(
    label: 'DSCVR Researchers',
    short: 'Researchers',
    tagline: 'Find, read and write up research with an assistant that knows your sources.',
    icon: Ic.researchers,
    price: 'Free',
  ),
  enterprise(
    label: 'DSCVR Enterprise',
    short: 'Enterprise',
    tagline: 'A shared research desk for teams, billed only for what you use.',
    icon: Ic.enterprise,
    price: 'Usage-based',
  );

  const Edition({required this.label, required this.short, required this.tagline, required this.icon, required this.price});

  final String label;
  final String short;
  final String tagline;
  final IconData icon;
  final String price;

  static Edition parse(String? v, {String? role}) {
    for (final e in Edition.values) {
      if (e.name == v) return e;
    }
    // Older profiles only stored a free-text role.
    if (role != null && role.toLowerCase().contains('student')) return Edition.students;
    return Edition.researchers;
  }

  /// What the onboarding card promises for each edition.
  List<String> get highlights => switch (this) {
        Edition.students => const [
            'Study guides, flashcards and quizzes from your readings',
            'Focus sessions with a timer and an end-of-session recap',
            'Voice notes in lectures, turned into clean notes',
            'Study groups with live sessions',
          ],
        Edition.researchers => const [
            'arXiv and Semantic Scholar in one search, PDFs saved to your library',
            'Pinda answers from your papers, with citations',
            'Literature reviews and reports drafted from your sources',
            'Parliament fact-check, ratings and related-paper suggestions',
          ],
        Edition.enterprise => const [
            'A shared organisation with admins and invite codes',
            'Everything in Researchers for every member',
            'Pay per active seat-day and AI usage, nothing up front',
            'Live usage and monthly invoices for admins',
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
