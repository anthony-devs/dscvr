/// Sharing models — Figma-style link sharing with view/fork/comment.

enum SharePermission {
  view('Can view'),
  comment('Can comment'),
  fork('Can fork');

  const SharePermission(this.label);
  final String label;

  static SharePermission fromString(String s) => switch (s) {
        'comment' => SharePermission.comment,
        'fork' => SharePermission.fork,
        _ => SharePermission.view,
      };
}

/// A share link for a category or topic.
class ShareLink {
  const ShareLink({
    required this.id,
    required this.ownerId,
    required this.targetType,
    required this.targetId,
    required this.permission,
    required this.createdAt,
    this.expiresAt,
    this.password,
    this.allowedEmails = const [],
    this.label,
    this.active = true,
  });

  final String id;
  final String ownerId;
  final String targetType; // 'category' | 'topic'
  final String targetId;
  final SharePermission permission;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? password;
  final List<String> allowedEmails;
  final String? label;
  final bool active;

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isValid => active && !isExpired;

  String get shareUrl => 'https://dscvr-9d362.web.app/s/$id';

  factory ShareLink.fromMap(String id, Map<String, dynamic> m) => ShareLink(
        id: id,
        ownerId: m['ownerId'] as String? ?? '',
        targetType: m['targetType'] as String? ?? 'category',
        targetId: m['targetId'] as String? ?? '',
        permission: SharePermission.fromString(m['permission'] as String? ?? 'view'),
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        expiresAt: m['expiresAt'] is String ? DateTime.tryParse(m['expiresAt'] as String) : null,
        password: m['password'] as String?,
        allowedEmails: (m['allowedEmails'] as List?)?.cast<String>() ?? [],
        label: m['label'] as String?,
        active: m['active'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'targetType': targetType,
        'targetId': targetId,
        'permission': permission.name,
        'createdAt': createdAt.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        if (password != null) 'password': password,
        'allowedEmails': allowedEmails,
        if (label != null) 'label': label,
        'active': active,
      };

  ShareLink copyWith({
    SharePermission? permission,
    DateTime? expiresAt,
    String? password,
    List<String>? allowedEmails,
    String? label,
    bool? active,
  }) =>
      ShareLink(
        id: id,
        ownerId: ownerId,
        targetType: targetType,
        targetId: targetId,
        permission: permission ?? this.permission,
        createdAt: createdAt,
        expiresAt: expiresAt ?? this.expiresAt,
        password: password ?? this.password,
        allowedEmails: allowedEmails ?? this.allowedEmails,
        label: label ?? this.label,
        active: active ?? this.active,
      );
}
