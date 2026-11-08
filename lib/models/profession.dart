import 'package:dscvr/models/subjects.dart';

/// What the user studies or does. Picking one fills in a starter set of
/// subjects, tunes Pinda's language and safety notes on the server, and
/// decides which study tools and sources show first.
enum Profession {
  medicine('medicine', 'Medicine', 'Doctors and medical students', [
    'Medicine', 'Clinical Guidelines', 'Internal Medicine', 'Surgery', 'Paediatrics', 'Obstetrics & Gynaecology',
    'Infectious Diseases', 'Anatomy & Physiology', 'Community & Family Medicine', 'Pathology',
  ]),
  nursing('nursing', 'Nursing & midwifery', 'Nurses, midwives and students', [
    'Nursing', 'Adult & Medical-Surgical Nursing', 'Midwifery', 'Paediatric Nursing', 'Community Health Nursing',
    'Mental Health Nursing', 'Patient Safety', 'Infection Prevention & Control', 'Clinical Guidelines', 'Nursing Education',
  ]),
  pharmacy('pharmacy', 'Pharmacy', 'Pharmacists and pharmacy students', [
    'Pharmacy & Pharmacology', 'Clinical Pharmacy', 'Pharmaceutics', 'Pharmacovigilance & Drug Safety',
    'Pharmaceutical Chemistry', 'Pharmacognosy & Natural Products', 'Antimicrobial Resistance', 'Toxicology',
  ]),
  publicHealth('public_health', 'Public health', 'Epidemiology, global and community health', [
    'Public Health', 'Epidemiology', 'Global Health', 'Maternal & Child Health', 'Vaccines & Immunisation',
    'Health Policy & Systems', 'Biostatistics', 'Environmental Health', 'Malaria', 'HIV/AIDS',
  ]),
  law('law', 'Law', 'Lawyers, law students and legal researchers', [
    'Law', 'Constitutional Law', 'Contract Law', 'Tort Law', 'Criminal Law', 'Land & Property Law', 'Evidence',
    'Commercial & Corporate Law', 'Equity & Trusts', 'Human Rights',
  ]),
  engineering('engineering', 'Engineering', 'Engineers and engineering students', [
    'Engineering', 'Electrical & Electronic Engineering', 'Mechanical Engineering', 'Civil Engineering',
    'Computer Engineering', 'Chemical Engineering', 'Renewable Energy', 'Structural Engineering',
  ]),
  business('business', 'Business & finance', 'Business, accounting, finance and economics', [
    'Business', 'Accounting', 'Finance', 'Economics', 'Marketing', 'Management', 'Entrepreneurship', 'Fintech',
  ]),
  education('education', 'Education', 'Teachers and education students', [
    'Education', 'Curriculum & Teaching', 'Educational Psychology', 'Educational Technology', 'Science Education',
    'Higher Education', 'Special Education', 'Assessment & Measurement',
  ]),
  computing('computing', 'Computing & tech', 'Software, data and AI', [
    'Computer Science', 'Artificial Intelligence', 'Machine Learning', 'Software Engineering', 'Data Science',
    'Cybersecurity',
  ]),
  sciences('sciences', 'Sciences', 'Biology, chemistry, physics, maths', [
    'Biology', 'Chemistry', 'Physics', 'Mathematics', 'Biochemistry', 'Microbiology', 'Statistics',
  ]),
  social('social', 'Social sciences & humanities', 'Psychology, politics, history, communication', [
    'Psychology', 'Sociology', 'Political Science', 'History', 'Mass Communication', 'English Literature', 'Philosophy',
  ]),
  other('other', 'Something else', 'Pick your own subjects', []);

  const Profession(this.id, this.label, this.blurb, this.starter);

  /// Stored on the profile and sent to the server.
  final String id;
  final String label;
  final String blurb;

  /// Subject labels picked automatically (the user can change them).
  final List<String> starter;

  List<Subject> get subjects => [for (final s in starter) ?Subject.lookup(s)];

  bool get isHealth => this == medicine || this == nursing || this == pharmacy || this == publicHealth;
  bool get isLaw => this == law;

  static Profession? fromId(String? id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// A best guess from subjects the user already picked (for people who
  /// signed up before professions existed).
  static Profession? guess(Iterable<String> subjects) {
    final scores = <Profession, int>{};
    for (final label in subjects) {
      final s = Subject.lookup(label);
      if (s == null) continue;
      for (final p in values) {
        if (p.starter.contains(s.label)) scores[p] = (scores[p] ?? 0) + 2;
      }
      if (s.isLaw) scores[law] = (scores[law] ?? 0) + 1;
      if (s.field == 'Health & Medicine') scores[medicine] = (scores[medicine] ?? 0) + 1;
    }
    if (scores.isEmpty) return null;
    return (scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }
}
