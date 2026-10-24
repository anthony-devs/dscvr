import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// What Pinda is allowed to read for a conversation.
enum PindaScope { general, category, topic, material }

@immutable
class PindaContext {
  const PindaContext({required this.scope, this.id, this.label = 'Everything'});

  const PindaContext.general()
      : scope = PindaScope.general,
        id = null,
        label = 'General';

  final PindaScope scope;
  final String? id;
  final String label;

  Map<String, dynamic> toMap() => {'scope': scope.name, 'id': id, 'label': label};

  factory PindaContext.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const PindaContext.general();
    return PindaContext(
      scope: PindaScope.values.firstWhere((e) => e.name == m['scope'],
          orElse: () => PindaScope.general),
      id: m['id'] as String?,
      label: m['label'] as String? ?? 'General',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PindaContext && other.scope == scope && other.id == id;

  @override
  int get hashCode => Object.hash(scope, id);
}

enum ChatRole { user, assistant }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.pending = false,
    this.error,
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;

  /// True while the assistant reply is still streaming.
  final bool pending;
  final String? error;

  ChatMessage copyWith({String? text, bool? pending, String? error}) =>
      ChatMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        createdAt: createdAt,
        pending: pending ?? this.pending,
        error: error,
      );

  factory ChatMessage.fromMap(String id, Map<String, dynamic> m) => ChatMessage(
        id: id,
        role: m['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
        text: m['text'] as String? ?? '',
        createdAt: (m['createdAt'] is Timestamp)
            ? (m['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'role': role.name,
        'text': text,
        'createdAt': createdAt,
      };
}

@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.context,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final PindaContext context;
  final DateTime updatedAt;

  factory Conversation.fromMap(String id, Map<String, dynamic> m) =>
      Conversation(
        id: id,
        title: m['title'] as String? ?? 'New conversation',
        context: PindaContext.fromMap(
            (m['context'] as Map?)?.cast<String, dynamic>()),
        updatedAt: (m['updatedAt'] is Timestamp)
            ? (m['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
}

/// Ready-made prompts shown as actions in the Pinda panel.
enum PindaAction {
  summarize('Summarize', 'Summarize this in a few tight paragraphs, then list the key takeaways.'),
  explain('Explain simply', 'Explain the core ideas here as if to a smart first-year student. Use one concrete example.'),
  questions('Key questions', 'What are the most important open questions or critiques this raises?'),
  studyGuide('Study guide', 'Write a study guide: key terms with definitions, main arguments, and 5 review questions.'),
  quiz('Quiz me', 'Quiz me with 5 multiple-choice questions, one at a time. Wait for my answer before revealing the correct one.'),
  factCheck('Fact-check', 'Identify the main factual claims and assess how well each is supported. Flag anything that looks wrong or overstated.');

  const PindaAction(this.label, this.prompt);
  final String label;
  final String prompt;
}
