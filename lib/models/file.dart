import 'package:dscvr/models/auth.dart';

class Note {
  String title;
  String body;
  DateTime edited;
  DateTime createdAt;
  String owner; //email

  Note ({required this.title, required this.body, required this.owner, required this.createdAt, required this.edited});
}