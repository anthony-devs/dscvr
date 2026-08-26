import 'package:flutter/material.dart';

/// Icon + accent color for a file, derived once from its name instead of
/// running the same extension checks twice (as the original icon/color
/// methods did).
class FileTypeStyle {
  const FileTypeStyle._(this.icon, this.color);

  final IconData icon;
  final Color color;

  factory FileTypeStyle.fromFileName(String name) {
    final ext = name.toLowerCase();

    if (ext.endsWith('.pdf')) {
      return const FileTypeStyle._(Icons.picture_as_pdf, Color(0xFFE53935));
    }
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png')) {
      return const FileTypeStyle._(Icons.image, Color(0xFF43A047));
    }
    if (ext.endsWith('.txt')) {
      return const FileTypeStyle._(Icons.description, Color(0xFF1E88E5));
    }
    return const FileTypeStyle._(Icons.insert_drive_file, Color(0xFF757575));
  }
}