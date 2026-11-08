/// Where a subject's newest items come from.
enum Feed {
  arxiv('arXiv'),
  openalex('journals'),
  europepmc('Europe PMC'),
  caselaw('UK case law');

  const Feed(this.label);
  final String label;
}

/// Every subject DSCVR knows about, across all fields, so anyone can find
/// theirs. Each subject has a feed: arXiv preprints, OpenAlex journals (any
/// field), Europe PMC for health (PubMed, PMC and clinical guidelines), or
/// UK judgments for areas of law. Anything a user types gets OpenAlex.
class Subject {
  const Subject(this.label, {this.arxiv, this.field = 'Other', this.query, this.source, this.guidelines = false});

  final String label;

  /// arXiv search query (e.g. `cat:cs.LG`), when arXiv covers the subject.
  final String? arxiv;

  /// Broad field, used to group subjects in pickers.
  final String field;

  /// Words to search for, when they differ from the label.
  final String? query;

  /// Explicit feed; otherwise picked from [arxiv] and [field].
  final Feed? source;

  /// Health subjects: only clinical practice guidelines.
  final bool guidelines;

  /// A subject made from free text (a user's own category name or a typed search).
  factory Subject.custom(String label) => lookup(label) ?? Subject(label.trim(), field: 'Your subjects');

  Feed get feed => source ?? (arxiv != null ? Feed.arxiv : field == 'Health & Medicine' ? Feed.europepmc : Feed.openalex);

  bool get usesArxiv => feed == Feed.arxiv;
  bool get isLaw => field == 'Law & Government' && feed == Feed.caselaw;
  bool get isHealth => field == 'Health & Medicine';

  /// What to send to the feed.
  String get searchText => feed == Feed.arxiv ? arxiv! : (query ?? label);

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
    final starts = <Subject>[], words = <Subject>[], contains = <Subject>[];
    for (final s in catalog) {
      final l = _norm(s.label);
      if (l.startsWith(q)) {
        starts.add(s);
      } else if (l.split(' ').any((w) => w.startsWith(q))) {
        words.add(s);
      } else if (l.contains(q) || _norm(s.field).contains(q)) {
        contains.add(s);
      }
    }
    for (final MapEntry(:key, :value) in _aliases.entries) {
      final s = catalog.firstWhere((x) => x.label == value);
      if (_norm(key).startsWith(q) && !starts.contains(s) && !words.contains(s) && !contains.contains(s)) starts.add(s);
    }
    return [...starts, ...words, ...contains].take(limit).toList();
  }

  /// Catalog subjects in a field, in catalog order.
  static List<Subject> inField(String field) => [for (final s in catalog) if (s.field == field) s];

  static String _norm(String s) => s.toLowerCase().replaceAll('&', 'and').replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  /// Shown first in pickers before the user searches.
  static const popular = [
    'Medicine', 'Nursing', 'Law', 'Computer Science', 'Business', 'Economics', 'Pharmacy & Pharmacology', 'Public Health',
    'Engineering', 'Psychology', 'Accounting', 'Biology', 'Education', 'Mathematics', 'Political Science', 'Physics',
    'Chemistry', 'Machine Learning', 'Mass Communication', 'English Literature', 'Architecture', 'Agriculture', 'Finance',
    'History',
  ];

  static const fields = [
    'Health & Medicine', 'Law & Government', 'Sciences', 'Computing & Technology', 'Engineering', 'Business & Management',
    'Social Sciences', 'Arts & Humanities', 'Education', 'Agriculture & Environment',
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
    'MBChB': 'Medicine',
    'Clinical Medicine': 'Medicine',
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
    'O&G': 'Obstetrics & Gynaecology',
    'OBGYN': 'Obstetrics & Gynaecology',
    'Obstetrics': 'Obstetrics & Gynaecology',
    'Gynaecology': 'Obstetrics & Gynaecology',
    'Gynecology': 'Obstetrics & Gynaecology',
    'Paeds': 'Paediatrics',
    'Peds': 'Paediatrics',
    'Pediatrics': 'Paediatrics',
    'ENT': 'Otorhinolaryngology (ENT)',
    'Anesthesia': 'Anaesthesia',
    'Anesthesiology': 'Anaesthesia',
    'Psychiatry': 'Mental Health & Psychiatry',
    'Orthopedics': 'Orthopaedics',
    'Hematology': 'Haematology',
    'Diabetes': 'Endocrinology & Diabetes',
    'Guidelines': 'Clinical Guidelines',
    'Community Medicine': 'Community & Family Medicine',
    'Family Medicine': 'Community & Family Medicine',
    'Primary Care': 'Community & Family Medicine',
    'Medical-Surgical Nursing': 'Adult & Medical-Surgical Nursing',
    'Med-Surg': 'Adult & Medical-Surgical Nursing',
    'ICU': 'Critical Care',
    'Intensive Care': 'Critical Care',
    'Physiotherapy': 'Physiotherapy & Rehabilitation',
    'Physical Therapy': 'Physiotherapy & Rehabilitation',
    'Contract': 'Contract Law',
    'Contracts': 'Contract Law',
    'Tort': 'Tort Law',
    'Torts': 'Tort Law',
    'Land Law': 'Land & Property Law',
    'Property Law': 'Land & Property Law',
    'Equity': 'Equity & Trusts',
    'Trusts': 'Equity & Trusts',
    'Company Law': 'Commercial & Corporate Law',
    'Corporate Law': 'Commercial & Corporate Law',
    'IP': 'Intellectual Property',
    'ADR': 'Arbitration & ADR',
    'Arbitration': 'Arbitration & ADR',
    'Jurisprudence': 'Jurisprudence & Legal Theory',
    'Employment Law': 'Labour & Employment Law',
    'Labour Law': 'Labour & Employment Law',
    'Oil and Gas Law': 'Energy, Oil & Gas Law',
    'Energy Law': 'Energy, Oil & Gas Law',
    'Shipping Law': 'Maritime & Admiralty Law',
    'Data Protection': 'Technology & Data Protection Law',
    'Legal Ethics': 'Legal Ethics & Professional Practice',
    'Sharia': 'Islamic Law',
    'Accountancy': 'Accounting',
    'Audit': 'Auditing',
    'Tax': 'Taxation',
  };

  static const catalog = <Subject>[
    // Health & Medicine: newest from Europe PMC (PubMed, PMC, guidelines)
    Subject('Medicine', field: 'Health & Medicine', query: 'medicine OR clinical'),
    Subject('Clinical Guidelines', field: 'Health & Medicine', query: 'clinical management', guidelines: true),
    Subject('Internal Medicine', field: 'Health & Medicine'),
    Subject('Surgery', field: 'Health & Medicine', query: 'surgery OR surgical'),
    Subject('Paediatrics', field: 'Health & Medicine', query: 'paediatric OR pediatric OR children'),
    Subject('Obstetrics & Gynaecology', field: 'Health & Medicine', query: 'obstetric OR pregnancy OR gynecologic'),
    Subject('Cardiology', field: 'Health & Medicine', query: 'cardiology OR cardiovascular OR heart failure'),
    Subject('Oncology', field: 'Health & Medicine', query: 'cancer OR oncology'),
    Subject('Infectious Diseases', field: 'Health & Medicine', query: 'infectious disease OR infection'),
    Subject('Tropical Medicine', field: 'Health & Medicine', query: 'tropical disease OR neglected tropical'),
    Subject('Malaria', field: 'Health & Medicine'),
    Subject('HIV/AIDS', field: 'Health & Medicine', query: 'HIV'),
    Subject('Tuberculosis', field: 'Health & Medicine'),
    Subject('Sickle Cell Disease', field: 'Health & Medicine', query: 'sickle cell'),
    Subject('Emergency Medicine', field: 'Health & Medicine', query: 'emergency medicine OR emergency department'),
    Subject('Critical Care', field: 'Health & Medicine', query: 'intensive care OR critical care'),
    Subject('Anaesthesia', field: 'Health & Medicine', query: 'anaesthesia OR anesthesia'),
    Subject('Neurology', field: 'Health & Medicine', query: 'neurology OR stroke OR epilepsy'),
    Subject('Mental Health & Psychiatry', field: 'Health & Medicine', query: 'psychiatry OR mental health'),
    Subject('Dermatology', field: 'Health & Medicine'),
    Subject('Ophthalmology', field: 'Health & Medicine', query: 'ophthalmology OR eye disease'),
    Subject('Otorhinolaryngology (ENT)', field: 'Health & Medicine', query: 'otolaryngology OR otorhinolaryngology'),
    Subject('Orthopaedics', field: 'Health & Medicine', query: 'orthopaedic OR orthopedic OR fracture'),
    Subject('Radiography & Imaging', arxiv: null, field: 'Health & Medicine', query: 'radiology OR medical imaging'),
    Subject('Pathology', field: 'Health & Medicine'),
    Subject('Haematology', field: 'Health & Medicine', query: 'haematology OR hematology OR anaemia'),
    Subject('Endocrinology & Diabetes', field: 'Health & Medicine', query: 'diabetes OR endocrine'),
    Subject('Nephrology', field: 'Health & Medicine', query: 'kidney disease OR nephrology'),
    Subject('Gastroenterology', field: 'Health & Medicine', query: 'gastroenterology OR liver disease'),
    Subject('Respiratory Medicine', field: 'Health & Medicine', query: 'asthma OR COPD OR respiratory'),
    Subject('Community & Family Medicine', field: 'Health & Medicine', query: 'primary care OR family medicine OR community health'),
    Subject('Anatomy & Physiology', field: 'Health & Medicine', query: 'anatomy OR physiology'),
    Subject('Medical Education', field: 'Health & Medicine', query: 'medical education OR medical students'),
    Subject('Dentistry', field: 'Health & Medicine', query: 'dental OR dentistry OR oral health'),
    Subject('Medical Laboratory Science', field: 'Health & Medicine', query: 'laboratory diagnosis OR clinical laboratory'),
    Subject('Nutrition & Dietetics', field: 'Health & Medicine', query: 'nutrition OR malnutrition OR diet'),
    Subject('Physiotherapy & Rehabilitation', field: 'Health & Medicine', query: 'physiotherapy OR rehabilitation'),
    Subject('Optometry', field: 'Health & Medicine', query: 'optometry OR refractive error OR vision'),
    Subject('Veterinary Medicine', field: 'Health & Medicine', query: 'veterinary'),
    Subject('Health Informatics', field: 'Health & Medicine', query: 'health informatics OR electronic health records'),
    // Nursing and midwifery
    Subject('Nursing', field: 'Health & Medicine', query: 'nursing OR nurses'),
    Subject('Adult & Medical-Surgical Nursing', field: 'Health & Medicine', query: 'medical-surgical nursing OR adult nursing'),
    Subject('Midwifery', field: 'Health & Medicine', query: 'midwifery OR midwives OR childbirth'),
    Subject('Paediatric Nursing', field: 'Health & Medicine', query: 'pediatric nursing OR paediatric nursing'),
    Subject('Mental Health Nursing', field: 'Health & Medicine', query: 'psychiatric nursing OR mental health nursing'),
    Subject('Community Health Nursing', field: 'Health & Medicine', query: 'community health nursing OR public health nursing'),
    Subject('Critical Care Nursing', field: 'Health & Medicine', query: 'critical care nursing OR ICU nurses'),
    Subject('Nursing Leadership & Management', field: 'Health & Medicine', query: 'nursing leadership OR nurse managers'),
    Subject('Nursing Education', field: 'Health & Medicine', query: 'nursing education OR nursing students'),
    Subject('Infection Prevention & Control', field: 'Health & Medicine', query: 'infection prevention OR infection control'),
    Subject('Patient Safety', field: 'Health & Medicine', query: 'patient safety OR medication error'),
    Subject('Wound Care', field: 'Health & Medicine', query: 'wound care OR pressure ulcer'),
    Subject('Gerontology & Elderly Care', field: 'Health & Medicine', query: 'older adults OR geriatric OR elderly care'),
    // Pharmacy
    Subject('Pharmacy & Pharmacology', field: 'Health & Medicine', query: 'pharmacology OR pharmacy'),
    Subject('Clinical Pharmacy', field: 'Health & Medicine', query: 'clinical pharmacy OR pharmacist'),
    Subject('Pharmaceutics', field: 'Health & Medicine', query: 'drug delivery OR formulation OR pharmaceutics'),
    Subject('Pharmacognosy & Natural Products', field: 'Health & Medicine', query: 'medicinal plants OR natural products OR pharmacognosy'),
    Subject('Pharmaceutical Chemistry', field: 'Health & Medicine', query: 'medicinal chemistry OR drug design'),
    Subject('Pharmacovigilance & Drug Safety', field: 'Health & Medicine', query: 'adverse drug reaction OR pharmacovigilance OR drug interaction'),
    Subject('Toxicology', field: 'Health & Medicine', query: 'toxicology OR poisoning'),
    Subject('Antimicrobial Resistance', field: 'Health & Medicine', query: 'antimicrobial resistance OR antibiotic resistance'),
    // Public health
    Subject('Public Health', field: 'Health & Medicine', query: 'public health'),
    Subject('Epidemiology', field: 'Health & Medicine', query: 'epidemiology OR prevalence OR incidence'),
    Subject('Global Health', field: 'Health & Medicine', query: 'global health OR low-income countries'),
    Subject('Maternal & Child Health', field: 'Health & Medicine', query: 'maternal health OR child health OR neonatal'),
    Subject('Vaccines & Immunisation', field: 'Health & Medicine', query: 'vaccine OR immunization OR vaccination'),
    Subject('Health Policy & Systems', field: 'Health & Medicine', query: 'health policy OR health systems OR universal health coverage'),
    Subject('Health Economics', field: 'Health & Medicine', query: 'health economics OR cost-effectiveness'),
    Subject('Environmental Health', field: 'Health & Medicine', query: 'environmental health OR air pollution OR water sanitation'),
    Subject('Occupational Health', field: 'Health & Medicine', query: 'occupational health OR workplace safety'),
    Subject('Health Promotion', field: 'Health & Medicine', query: 'health promotion OR health education OR behaviour change'),
    Subject('Biostatistics', field: 'Health & Medicine', query: 'biostatistics OR statistical methods clinical'),
    // Law: judgments from UK Find Case Law; scholarship via search
    Subject('Law', field: 'Law & Government', source: Feed.caselaw, query: 'judgment'),
    Subject('Constitutional Law', field: 'Law & Government', source: Feed.caselaw, query: 'constitutional'),
    Subject('Criminal Law', field: 'Law & Government', source: Feed.caselaw, query: 'criminal conviction appeal'),
    Subject('Criminal Procedure', field: 'Law & Government', source: Feed.caselaw, query: 'criminal procedure OR sentencing'),
    Subject('Contract Law', field: 'Law & Government', source: Feed.caselaw, query: 'breach of contract'),
    Subject('Tort Law', field: 'Law & Government', source: Feed.caselaw, query: 'negligence OR nuisance OR defamation'),
    Subject('Land & Property Law', field: 'Law & Government', source: Feed.caselaw, query: 'land OR lease OR easement OR mortgage'),
    Subject('Equity & Trusts', field: 'Law & Government', source: Feed.caselaw, query: 'trust OR fiduciary OR equitable'),
    Subject('Evidence', field: 'Law & Government', source: Feed.caselaw, query: 'admissibility of evidence OR hearsay'),
    Subject('Civil Procedure', field: 'Law & Government', source: Feed.caselaw, query: 'civil procedure OR strike out OR summary judgment'),
    Subject('Administrative Law', field: 'Law & Government', source: Feed.caselaw, query: 'judicial review'),
    Subject('Commercial & Corporate Law', field: 'Law & Government', source: Feed.caselaw, query: 'company OR shareholder OR director'),
    Subject('Banking & Finance Law', field: 'Law & Government', source: Feed.caselaw, query: 'bank OR guarantee OR loan'),
    Subject('Insolvency', field: 'Law & Government', source: Feed.caselaw, query: 'insolvency OR liquidation OR bankruptcy'),
    Subject('Family Law', field: 'Law & Government', source: Feed.caselaw, query: 'divorce OR custody OR matrimonial'),
    Subject('Labour & Employment Law', field: 'Law & Government', source: Feed.caselaw, query: 'unfair dismissal OR employment'),
    Subject('Taxation Law', field: 'Law & Government', source: Feed.caselaw, query: 'tax OR HMRC'),
    Subject('Intellectual Property', field: 'Law & Government', source: Feed.caselaw, query: 'patent OR trade mark OR copyright'),
    Subject('Energy, Oil & Gas Law', field: 'Law & Government', source: Feed.caselaw, query: 'oil OR gas OR energy'),
    Subject('Environmental Law', field: 'Law & Government', source: Feed.caselaw, query: 'environmental OR pollution OR planning'),
    Subject('Maritime & Admiralty Law', field: 'Law & Government', source: Feed.caselaw, query: 'charterparty OR vessel OR admiralty'),
    Subject('Arbitration & ADR', field: 'Law & Government', source: Feed.caselaw, query: 'arbitration OR arbitral award'),
    Subject('Medical Law & Ethics', field: 'Law & Government', source: Feed.caselaw, query: 'clinical negligence OR medical treatment consent'),
    Subject('Technology & Data Protection Law', field: 'Law & Government', source: Feed.caselaw, query: 'data protection OR privacy'),
    Subject('Immigration & Asylum Law', field: 'Law & Government', source: Feed.caselaw, query: 'asylum OR immigration OR deportation'),
    Subject('Human Rights', field: 'Law & Government', source: Feed.caselaw, query: 'human rights OR article 8 OR article 6'),
    Subject('International Law', field: 'Law & Government', query: 'international law'),
    Subject('Jurisprudence & Legal Theory', field: 'Law & Government', query: 'jurisprudence OR legal theory OR legal philosophy'),
    Subject('Legal Ethics & Professional Practice', field: 'Law & Government', query: 'legal profession ethics lawyers'),
    Subject('Islamic Law', field: 'Law & Government', query: 'Islamic law OR Sharia'),
    Subject('Customary Law', field: 'Law & Government', query: 'customary law Africa'),
    Subject('Election & Electoral Law', field: 'Law & Government', query: 'electoral law OR election petition'),
    Subject('Political Science', field: 'Law & Government'),
    Subject('International Relations', field: 'Law & Government'),
    Subject('Public Administration', field: 'Law & Government'),
    Subject('Public Policy', field: 'Law & Government'),
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
    Subject('Structural Engineering', field: 'Engineering', query: 'structural engineering OR reinforced concrete'),
    Subject('Geotechnical Engineering', field: 'Engineering', query: 'geotechnical OR soil mechanics'),
    Subject('Power Systems', arxiv: 'cat:eess.SY', field: 'Engineering', query: 'power systems OR electricity grid'),
    Subject('Telecommunications', arxiv: 'cat:eess.SP OR cat:cs.NI', field: 'Engineering'),
    Subject('Mechatronics', field: 'Engineering'),
    Subject('Water Resources Engineering', field: 'Engineering', query: 'water resources OR hydrology OR irrigation'),
    Subject('Environmental Engineering', field: 'Engineering', query: 'wastewater treatment OR environmental engineering'),
    Subject('Surveying & Geoinformatics', field: 'Engineering', query: 'surveying OR GIS OR remote sensing'),
    Subject('Metallurgical & Materials Engineering', field: 'Engineering', query: 'metallurgy OR materials engineering'),
    Subject('Marine & Naval Engineering', field: 'Engineering', query: 'marine engineering OR naval architecture'),
    Subject('Mining Engineering', field: 'Engineering'),
    Subject('Automotive Engineering', field: 'Engineering', query: 'automotive OR electric vehicles'),
    Subject('Construction Management', field: 'Engineering', query: 'construction management OR building projects'),
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
    Subject('Auditing', field: 'Business & Management'),
    Subject('Taxation', field: 'Business & Management'),
    Subject('Corporate Governance', field: 'Business & Management'),
    Subject('Strategy', field: 'Business & Management', query: 'business strategy OR competitive advantage'),
    Subject('Operations Management', field: 'Business & Management'),
    Subject('Digital Marketing', field: 'Business & Management'),
    Subject('Fintech', arxiv: 'cat:q-fin.GN', field: 'Business & Management', query: 'fintech OR mobile money OR digital payments'),
    Subject('Business Analytics', field: 'Business & Management'),
    Subject('Leadership', field: 'Business & Management', query: 'leadership organisations'),
    Subject('Small Business & SMEs', field: 'Business & Management', query: 'SMEs OR small business'),
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
    Subject('Science Education', field: 'Education'),
    Subject('Mathematics Education', field: 'Education'),
    Subject('Language & Literacy Education', field: 'Education', query: 'literacy OR language teaching'),
    Subject('Educational Administration', field: 'Education', query: 'school leadership OR educational administration'),
    Subject('Assessment & Measurement', field: 'Education', query: 'educational assessment OR psychometrics'),
    Subject('Higher Education', field: 'Education'),
    Subject('Adult & Continuing Education', field: 'Education', query: 'adult education OR lifelong learning'),
    Subject('Inclusive Education', field: 'Education', query: 'inclusive education OR disability students'),
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
