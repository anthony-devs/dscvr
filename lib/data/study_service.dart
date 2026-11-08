import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dscvr/config/env.dart';
import 'package:dscvr/data/api.dart';

/// Study material Pinda makes from one library item.
enum StudyKind {
  flashcards('flashcards', 'Flashcards', 'Key ideas and terms to memorise'),
  quiz('quiz', 'Practice questions', 'Exam-style questions with explanations'),
  brief('brief', 'Case brief', 'Facts, issues, holding, ratio and obiter'),
  evidence('evidence', 'Evidence summary', 'Design, PICO, findings and limitations');

  const StudyKind(this.id, this.label, this.blurb);
  final String id;
  final String label;
  final String blurb;
}

class Flashcard {
  const Flashcard(this.front, this.back);
  final String front;
  final String back;
}

class QuizQuestion {
  const QuizQuestion({required this.question, required this.options, required this.answer, required this.explanation});
  final String question;
  final List<String> options;
  final int answer;
  final String explanation;
}

class StudySet {
  const StudySet({required this.kind, required this.data, required this.createdAt});
  final StudyKind kind;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  List<Flashcard> get cards => [
        for (final c in (data['cards'] as List? ?? const []))
          if (c is Map) Flashcard('${c['front'] ?? ''}', '${c['back'] ?? ''}'),
      ];

  List<QuizQuestion> get questions => [
        for (final q in (data['questions'] as List? ?? const []))
          if (q is Map && q['options'] is List && (q['options'] as List).length == 4)
            QuizQuestion(
              question: '${q['question'] ?? ''}',
              options: [for (final o in q['options'] as List) '$o'],
              answer: (q['answer'] as num?)?.toInt() ?? 0,
              explanation: '${q['explanation'] ?? ''}',
            ),
      ];
}

/// Makes study sets on the server and keeps them in users/{uid}/studySets so
/// reopening one doesn't use Pinda again.
class StudyService {
  StudyService({required this.api, required this.uid});
  final DscvrApi api;
  final String Function() uid;

  DocumentReference<Map<String, dynamic>> _doc(String itemId, StudyKind kind) =>
      FirebaseFirestore.instance.collection('users').doc(uid()).collection('studySets').doc('${itemId}_${kind.id}');

  Future<StudySet?> saved(String itemId, StudyKind kind) async {
    if (Env.demo || uid().isEmpty) return null;
    try {
      final snap = await _doc(itemId, kind).get();
      final d = snap.data();
      if (d == null || d['data'] is! Map) return null;
      return StudySet(
        kind: kind,
        data: (d['data'] as Map).cast<String, dynamic>(),
        createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<StudySet> make(String itemId, StudyKind kind, {int count = 12}) async {
    if (Env.demo) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return StudySet(kind: kind, data: _demo[kind]!, createdAt: DateTime.now());
    }
    final res = await api.post('/study', {'itemId': itemId, 'kind': kind.id, 'count': count});
    final data = Map<String, dynamic>.of(res)..remove('kind');
    final set = StudySet(kind: kind, data: data, createdAt: DateTime.now());
    if (!Env.demo && uid().isNotEmpty) {
      try {
        await _doc(itemId, kind).set({'itemId': itemId, 'kind': kind.id, 'data': data, 'createdAt': FieldValue.serverTimestamp()});
      } catch (_) {
        // Keeping a copy is a convenience; the set is still shown.
      }
    }
    return set;
  }
}

/// Sample output for demo builds (no server).
const _demo = <StudyKind, Map<String, dynamic>>{
  StudyKind.flashcards: {
    'cards': [
      {'front': 'What does self-attention compute?', 'back': 'A weighted sum of all positions in a sequence, with weights from query-key similarity.'},
      {'front': 'Why scale dot products by the square root of the key dimension?', 'back': 'Large dot products push softmax into regions with tiny gradients; scaling keeps them stable.'},
      {'front': 'What is multi-head attention?', 'back': 'Several attention functions run in parallel on different learned projections, then concatenated.'},
    ],
  },
  StudyKind.quiz: {
    'questions': [
      {
        'question': 'Which component lets the Transformer use word order without recurrence?',
        'options': ['Layer normalisation', 'Positional encodings', 'Residual connections', 'Label smoothing'],
        'answer': 1,
        'explanation': 'Positional encodings add order information to the embeddings. The others help training but carry no position.',
      },
    ],
  },
  StudyKind.brief: {
    'caseName': 'Sample v Example',
    'citation': 'Not stated in the text',
    'court': 'Court of Appeal',
    'facts': 'A demo case brief. In the live app Pinda briefs the judgment or law report you open.',
    'issues': ['Whether the contract was validly formed', 'Whether damages were too remote'],
    'holding': 'The contract was valid; the damages claimed were too remote.',
    'ratio': 'Damages are recoverable only for losses within the reasonable contemplation of the parties when they contracted.',
    'outcome': 'Appeal allowed in part.',
  },
  StudyKind.evidence: {
    'design': 'Randomised controlled trial',
    'level': 'Level 1b: a single well-run RCT',
    'population': 'Adults with uncontrolled hypertension in primary care',
    'intervention': 'Nurse-led medication titration',
    'comparison': 'Usual care',
    'outcomes': ['Systolic blood pressure at 12 months'],
    'findings': 'Demo data. In the live app numbers come exactly from the paper.',
    'limitations': ['Single country', 'Open label'],
    'practice': 'Supports nurse-led titration programmes; not advice for an individual patient.',
  },
};
