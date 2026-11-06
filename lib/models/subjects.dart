/// Every subject DSCVR knows about, across all fields, so anyone can find
/// theirs. Subjects with an arXiv category get the latest preprints from
/// arXiv; every other subject (and anything a user types) gets the newest
/// papers from OpenAlex, which covers all disciplines.
class Subject {
  const Subject(this.label, {this.arxiv, this.field = 'Other'});

  final String label;

  /// arXiv search query (e.g. `cat:cs.LG`), or null to use OpenAlex.
  final String? arxiv;

  /// Broad field, used to group subjects in pickers.
  final String field;

  /// A subject made from free text (a user's own category name or a typed search).
  factory Subject.custom(String label) => lookup(label) ?? Subject(label.trim(), field: 'Your subjects');

  bool get usesArxiv => arxiv != null;

  @override
  bool operator ==(Object other) => other is Subject && other.label.toLowerCase() == label.toLowerCase();

  @override
  int get hashCode => label.toLowerCase().hashCode;

  /// Finds a catalog subject by name, ignoring case and small differences.
  static Subject? lookup(String name) {
    final n = _norm(name);
    if (n.isEmpty) return null;
    for (final s in catalog) {
      if (_norm(s.label) == n) return s;
    }
    for (final MapEntry(:key, :value) in _aliases.entries) {
      if (_norm(key) == n) return catalog.firstWhere((s) => s.label == value);
    }
    return null;
  }

  /// Catalog subjects matching a search, best matches first.
  static List<Subject> search(String query, {int limit = 40}) {
    final q = _norm(query);
    if (q.isEmpty) return catalog;
    final starts = <Subject>[], contains = <Subject>[];
    for (final s in catalog) {
      final l = _norm(s.label);
      if (l.startsWith(q)) {
        starts.add(s);
      } else if (l.contains(q) || _norm(s.field).contains(q)) {
        contains.add(s);
      }
    }
    for (final MapEntry(:key, :value) in _aliases.entries) {
      final s = catalog.firstWhere((x) => x.label == value);
      if (_norm(key).startsWith(q) && !starts.contains(s) && !contains.contains(s)) starts.add(s);
    }
    return [...starts, ...contains].take(limit).toList();
  }

  static String _norm(String s) => s.toLowerCase().replaceAll('&', 'and').replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  /// Shown first in pickers before the user searches.
  static const popular = [
    'Computer Science', 'Medicine', 'Business', 'Law', 'Economics', 'Psychology', 'Biology', 'Engineering',
    'Nursing', 'Accounting', 'Mathematics', 'Physics', 'Chemistry', 'Education', 'Political Science', 'History',
    'Machine Learning', 'Public Health', 'Mass Communication', 'English Literature', 'Architecture', 'Pharmacy',
    'Agriculture', 'Finance',
  ];

  static const fields = [
    'Sciences', 'Computing & Technology', 'Engineering', 'Health & Medicine', 'Business & Management',
    'Social Sciences', 'Law & Government', 'Arts & Humanities', 'Education', 'Agriculture & Environment',
  ];

  static const _aliases = {
    'CS': 'Computer Science',
    'AI': 'Artificial Intelligence',
    'ML': 'Machine Learning',
    'NLP': 'Natural Language Processing',
    'Econ': 'Economics',
    'Maths': 'Mathematics',
    'Math': 'Mathematics',
    'Bio': 'Biology',
    'Psych': 'Psychology',
    'Med': 'Medicine',
    'MBBS': 'Medicine',
    'Language': 'Natural Language Processing',
    'Comms': 'Mass Communication',
    'Journalism': 'Mass Communication',
    'Literature': 'English Literature',
    'Business Administration': 'Business',
    'MBA': 'Business',
    'Politics': 'Political Science',
    'Electrical Engineering': 'Electrical & Electronic Engineering',
    'EEE': 'Electrical & Electronic Engineering',
    'Civil': 'Civil Engineering',
    'Mechanical': 'Mechanical Engineering',
    'Biochem': 'Biochemistry',
    'Micro': 'Microbiology',
    'Stats': 'Statistics',
    'Quant': 'Quantitative Finance',
    'Pharmacy': 'Pharmacy & Pharmacology',
    'Pharmacology': 'Pharmacy & Pharmacology',
    'Astronomy': 'Astronomy & Astrophysics',
    'Geology': 'Geology & Earth Science',
    'Genetics': 'Genetics & Genomics',
  };

  static const catalog = <Subject>[
    // Sciences
    Subject('Mathematics', arxiv: 'cat:math.ST OR cat:math.PR OR cat:math.CO OR cat:math.AP OR cat:math.NT OR cat:math.OC', field: 'Sciences'),
    Subject('Statistics', arxiv: 'cat:stat.ME OR cat:stat.TH OR cat:stat.AP', field: 'Sciences'),
    Subject('Physics', arxiv: 'cat:physics.gen-ph OR cat:cond-mat.stat-mech OR cat:hep-ph', field: 'Sciences'),
    Subject('Quantum Physics', arxiv: 'cat:quant-ph', field: 'Sciences'),
    Subject('Astronomy & Astrophysics', arxiv: 'cat:astro-ph.GA OR cat:astro-ph.CO OR cat:astro-ph.SR OR cat:astro-ph.EP', field: 'Sciences'),
    Subject('Chemistry', field: 'Sciences'),
    Subject('Biochemistry', field: 'Sciences'),
    Subject('Biology', arxiv: 'cat:q-bio.GN OR cat:q-bio.BM OR cat:q-bio.PE OR cat:q-bio.CB', field: 'Sciences'),
    Subject('Genetics & Genomics', arxiv: 'cat:q-bio.GN', field: 'Sciences'),
    Subject('Molecular Biology', arxiv: 'cat:q-bio.BM OR cat:q-bio.MN', field: 'Sciences'),
    Subject('Microbiology', field: 'Sciences'),
    Subject('Ecology', arxiv: 'cat:q-bio.PE', field: 'Sciences'),
    Subject('Zoology', field: 'Sciences'),
    Subject('Botany & Plant Science', field: 'Sciences'),
    Subject('Neuroscience', arxiv: 'cat:q-bio.NC', field: 'Sciences'),
    Subject('Geology & Earth Science', arxiv: 'cat:physics.geo-ph', field: 'Sciences'),
    Subject('Materials Science', arxiv: 'cat:cond-mat.mtrl-sci', field: 'Sciences'),
    Subject('Oceanography', arxiv: 'cat:physics.ao-ph', field: 'Sciences'),
    Subject('Meteorology & Climate', arxiv: 'cat:physics.ao-ph', field: 'Sciences'),
    // Computing & Technology
    Subject('Computer Science', arxiv: 'cat:cs.AI OR cat:cs.LG OR cat:cs.CL OR cat:cs.CV OR cat:cs.SE OR cat:cs.CR OR cat:cs.DS', field: 'Computing & Technology'),
    Subject('Artificial Intelligence', arxiv: 'cat:cs.AI', field: 'Computing & Technology'),
    Subject('Machine Learning', arxiv: 'cat:cs.LG OR cat:stat.ML', field: 'Computing & Technology'),
    Subject('Natural Language Processing', arxiv: 'cat:cs.CL', field: 'Computing & Technology'),
    Subject('Computer Vision', arxiv: 'cat:cs.CV', field: 'Computing & Technology'),
    Subject('Robotics', arxiv: 'cat:cs.RO', field: 'Computing & Technology'),
    Subject('Cybersecurity', arxiv: 'cat:cs.CR', field: 'Computing & Technology'),
    Subject('Software Engineering', arxiv: 'cat:cs.SE', field: 'Computing & Technology'),
    Subject('Data Science', arxiv: 'cat:cs.DB OR cat:stat.ML', field: 'Computing & Technology'),
    Subject('Human-Computer Interaction', arxiv: 'cat:cs.HC', field: 'Computing & Technology'),
    Subject('Networking & Distributed Systems', arxiv: 'cat:cs.NI OR cat:cs.DC', field: 'Computing & Technology'),
    Subject('Information Technology', field: 'Computing & Technology'),
    Subject('Information Theory', arxiv: 'cat:cs.IT', field: 'Computing & Technology'),
    Subject('Blockchain & Cryptography', arxiv: 'cat:cs.CR', field: 'Computing & Technology'),
    // Engineering
    Subject('Engineering', field: 'Engineering'),
    Subject('Electrical & Electronic Engineering', arxiv: 'cat:eess.SY OR cat:eess.SP', field: 'Engineering'),
    Subject('Mechanical Engineering', field: 'Engineering'),
    Subject('Civil Engineering', field: 'Engineering'),
    Subject('Chemical Engineering', field: 'Engineering'),
    Subject('Computer Engineering', arxiv: 'cat:cs.AR OR cat:eess.SY', field: 'Engineering'),
    Subject('Biomedical Engineering', field: 'Engineering'),
    Subject('Petroleum Engineering', field: 'Engineering'),
    Subject('Aerospace Engineering', field: 'Engineering'),
    Subject('Agricultural Engineering', field: 'Engineering'),
    Subject('Industrial Engineering', field: 'Engineering'),
    Subject('Signal Processing', arxiv: 'cat:eess.SP', field: 'Engineering'),
    Subject('Renewable Energy', field: 'Engineering'),
    Subject('Architecture', field: 'Engineering'),
    Subject('Urban & Regional Planning', field: 'Engineering'),
    // Health & Medicine
    Subject('Medicine', field: 'Health & Medicine'),
    Subject('Nursing', field: 'Health & Medicine'),
    Subject('Pharmacy & Pharmacology', field: 'Health & Medicine'),
    Subject('Public Health', field: 'Health & Medicine'),
    Subject('Epidemiology', field: 'Health & Medicine'),
    Subject('Anatomy & Physiology', field: 'Health & Medicine'),
    Subject('Dentistry', field: 'Health & Medicine'),
    Subject('Medical Laboratory Science', field: 'Health & Medicine'),
    Subject('Nutrition & Dietetics', field: 'Health & Medicine'),
    Subject('Physiotherapy', field: 'Health & Medicine'),
    Subject('Radiography & Imaging', arxiv: 'cat:eess.IV', field: 'Health & Medicine'),
    Subject('Mental Health & Psychiatry', field: 'Health & Medicine'),
    Subject('Veterinary Medicine', field: 'Health & Medicine'),
    Subject('Optometry', field: 'Health & Medicine'),
    Subject('Health Informatics', field: 'Health & Medicine'),
    // Business & Management
    Subject('Business', field: 'Business & Management'),
    Subject('Accounting', field: 'Business & Management'),
    Subject('Finance', arxiv: 'cat:q-fin.GN', field: 'Business & Management'),
    Subject('Quantitative Finance', arxiv: 'cat:q-fin.ST OR cat:q-fin.PM OR cat:q-fin.RM OR cat:q-fin.CP OR cat:q-fin.TR', field: 'Business & Management'),
    Subject('Banking', field: 'Business & Management'),
    Subject('Marketing', field: 'Business & Management'),
    Subject('Management', field: 'Business & Management'),
    Subject('Entrepreneurship', field: 'Business & Management'),
    Subject('Human Resource Management', field: 'Business & Management'),
    Subject('Supply Chain & Logistics', field: 'Business & Management'),
    Subject('Insurance & Actuarial Science', field: 'Business & Management'),
    Subject('Real Estate', field: 'Business & Management'),
    Subject('Hospitality & Tourism', field: 'Business & Management'),
    Subject('Project Management', field: 'Business & Management'),
    // Social Sciences
    Subject('Economics', arxiv: 'cat:econ.GN OR cat:econ.TH OR cat:econ.EM', field: 'Social Sciences'),
    Subject('Psychology', field: 'Social Sciences'),
    Subject('Sociology', field: 'Social Sciences'),
    Subject('Anthropology', field: 'Social Sciences'),
    Subject('Geography', field: 'Social Sciences'),
    Subject('Demography', field: 'Social Sciences'),
    Subject('Social Work', field: 'Social Sciences'),
    Subject('Criminology', field: 'Social Sciences'),
    Subject('Development Studies', field: 'Social Sciences'),
    Subject('Gender Studies', field: 'Social Sciences'),
    Subject('Mass Communication', field: 'Social Sciences'),
    Subject('Library & Information Science', field: 'Social Sciences'),
    // Law & Government
    Subject('Law', field: 'Law & Government'),
    Subject('Constitutional Law', field: 'Law & Government'),
    Subject('Criminal Law', field: 'Law & Government'),
    Subject('Commercial & Corporate Law', field: 'Law & Government'),
    Subject('International Law', field: 'Law & Government'),
    Subject('Human Rights', field: 'Law & Government'),
    Subject('Political Science', field: 'Law & Government'),
    Subject('International Relations', field: 'Law & Government'),
    Subject('Public Administration', field: 'Law & Government'),
    Subject('Public Policy', field: 'Law & Government'),
    // Arts & Humanities
    Subject('History', field: 'Arts & Humanities'),
    Subject('Philosophy', field: 'Arts & Humanities'),
    Subject('English Literature', field: 'Arts & Humanities'),
    Subject('Linguistics', field: 'Arts & Humanities'),
    Subject('Languages & Translation', field: 'Arts & Humanities'),
    Subject('Religious Studies', field: 'Arts & Humanities'),
    Subject('Theology', field: 'Arts & Humanities'),
    Subject('Fine Arts', field: 'Arts & Humanities'),
    Subject('Music', field: 'Arts & Humanities'),
    Subject('Theatre & Film', field: 'Arts & Humanities'),
    Subject('Design', field: 'Arts & Humanities'),
    Subject('Fashion', field: 'Arts & Humanities'),
    Subject('African Studies', field: 'Arts & Humanities'),
    Subject('Archaeology', field: 'Arts & Humanities'),
    Subject('Cultural Studies', field: 'Arts & Humanities'),
    // Education
    Subject('Education', field: 'Education'),
    Subject('Educational Psychology', field: 'Education'),
    Subject('Curriculum & Teaching', field: 'Education'),
    Subject('Early Childhood Education', field: 'Education'),
    Subject('Special Education', field: 'Education'),
    Subject('Educational Technology', field: 'Education'),
    Subject('Guidance & Counselling', field: 'Education'),
    Subject('Physical & Health Education', field: 'Education'),
    // Agriculture & Environment
    Subject('Agriculture', field: 'Agriculture & Environment'),
    Subject('Agricultural Economics', field: 'Agriculture & Environment'),
    Subject('Animal Science', field: 'Agriculture & Environment'),
    Subject('Crop & Soil Science', field: 'Agriculture & Environment'),
    Subject('Food Science & Technology', field: 'Agriculture & Environment'),
    Subject('Fisheries & Aquaculture', field: 'Agriculture & Environment'),
    Subject('Forestry', field: 'Agriculture & Environment'),
    Subject('Environmental Science', field: 'Agriculture & Environment'),
    Subject('Climate Change', field: 'Agriculture & Environment'),
    Subject('Sustainability', field: 'Agriculture & Environment'),
  ];
}
