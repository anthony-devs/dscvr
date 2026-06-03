import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

@immutable
class Note {
  final String title;
  final String content;
  final DateTime edited;
  final DateTime createdAt;
  final String owner;
  final List<String>? artifacts;
  final bool public;
  final List<String>? tags;


  Note ({required this.title, required this.content, required this.owner, required this.createdAt, required this.edited, this.artifacts, this.tags, this.public = true});

  factory Note.fromMap(Map<String, dynamic> map) => Note(
  content: map['content'] as String,
  title: map['name'] as String,
  edited: (map['edited'] as Timestamp).toDate(),      // ✅ Timestamp → DateTime
  createdAt: (map['created'] as Timestamp).toDate(),  // ✅ Timestamp → DateTime
  owner: map['owner'] as String,
  artifacts: (map['artifacts'] as List?)?.cast<String>(),
  public: map['public'] as bool? ?? true,
  tags: (map['tags'] as List?)?.cast<String>(),
);
}