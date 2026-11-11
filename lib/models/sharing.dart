/// Sharing models: link sharing for a category or topic, view-only or view-and-copy.

enum SharePermission {
  view('Can view'),
  comment('Can comment'),
  fork('Can view and copy');

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

  String get shareUrl => 'https://app.askpinda.com/s/$id';

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

/// One item in a shared collection, as the server hands it to a viewer.
class SharedItem {
  const SharedItem({
    required this.id,
    required this.kind,
    required this.title,
    this.authors = const [],
    this.year,
    this.summary = '',
    this.content = '',
    this.url,
    this.pdfUrl,
    this.siteName,
    this.source,
    this.externalId,
    this.thumbnailUrl,
    this.topicId,
    this.privateFile = false,
  });

  final String id;
  final String kind;
  final String title;
  final List<String> authors;
  final int? year;
  final String summary;
  final String content;
  final String? url;
  final String? pdfUrl;
  final String? siteName;
  final String? source;
  final String? externalId;
  final String? thumbnailUrl;
  final String? topicId;

  /// The owner uploaded this file; viewers see its title but not the file.
  final bool privateFile;

  /// Where a viewer can read it, if anywhere.
  String? get openUrl => (url != null && url!.isNotEmpty) ? url : (pdfUrl != null && pdfUrl!.isNotEmpty ? pdfUrl : null);

  factory SharedItem.fromMap(Map<String, dynamic> m) => SharedItem(
        id: m['id'] as String? ?? '',
        kind: m['kind'] as String? ?? 'link',
        title: m['title'] as String? ?? 'Untitled',
        authors: (m['authors'] as List?)?.whereType<String>().toList() ?? const [],
        year: (m['year'] as num?)?.toInt(),
        summary: m['summary'] as String? ?? '',
        content: m['content'] as String? ?? '',
        url: m['url'] as String?,
        pdfUrl: m['pdfUrl'] as String?,
        siteName: m['siteName'] as String?,
        source: m['source'] as String?,
        externalId: m['externalId'] as String?,
        thumbnailUrl: m['thumbnailUrl'] as String?,
        topicId: m['topicId'] as String?,
        privateFile: m['privateFile'] as bool? ?? false,
      );
}

/// A category or topic someone shared, opened from a link.
class SharedCollection {
  const SharedCollection({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.ownerName,
    required this.canFork,
    required this.mine,
    required this.topics,
    required this.items,
  });

  final String id;
  final String type;
  final String name;
  final String description;
  final String ownerName;
  final bool canFork;
  final bool mine;

  /// (id, name) of the topics inside a shared category.
  final List<(String, String)> topics;
  final List<SharedItem> items;

  factory SharedCollection.fromMap(Map<String, dynamic> m) => SharedCollection(
        id: m['id'] as String? ?? '',
        type: m['type'] as String? ?? 'category',
        name: m['name'] as String? ?? 'Untitled',
        description: m['description'] as String? ?? '',
        ownerName: m['ownerName'] as String? ?? 'A DSCVR user',
        canFork: m['canFork'] as bool? ?? false,
        mine: m['mine'] as bool? ?? false,
        topics: [
          for (final t in (m['topics'] as List? ?? const []))
            if (t is Map) (t['id'] as String? ?? '', t['name'] as String? ?? 'Untitled'),
        ],
        items: [
          for (final i in (m['items'] as List? ?? const []))
            if (i is Map) SharedItem.fromMap(i.cast<String, dynamic>()),
        ],
      );
}
