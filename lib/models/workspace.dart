import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dscvr/models/edition.dart';
import 'package:flutter/foundation.dart';

/// Reports, sessions, live rooms, devices and organisations.
///
/// Firestore layout:
///   users/{uid}/reports/{id}
///   users/{uid}/sessions/{id}          focus sessions
///   users/{uid}/devices/{id}           signed-in devices
///   rooms/{id}                         live group sessions
///   rooms/{id}/members/{uid}
///   rooms/{id}/messages/{id}

DateTime _date(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

DateTime? _dateOrNull(Object? v) => v == null ? null : _date(v);

List<String> _strings(Object? v) => (v is List) ? v.whereType<String>().toList() : const <String>[];

// ── Reports ──────────────────────────────────────────────────────────

@immutable
class Report {
  const Report({
    required this.id,
    required this.title,
    required this.kind,
    this.body = '',
    this.sourceIds = const [],
    this.instructions = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final ReportKind kind;

  /// Markdown.
  final String body;
  final List<String> sourceIds;
  final String instructions;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get wordCount => body.trim().isEmpty ? 0 : body.trim().split(RegExp(r'\s+')).length;

  factory Report.fromMap(String id, Map<String, dynamic> m) => Report(
        id: id,
        title: m['title'] as String? ?? 'Untitled report',
        kind: ReportKind.parse(m['kind'] as String?),
        body: m['body'] as String? ?? '',
        sourceIds: _strings(m['sourceIds']),
        instructions: m['instructions'] as String? ?? '',
        createdAt: _date(m['createdAt']),
        updatedAt: _date(m['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'kind': kind.wire,
        'body': body,
        'sourceIds': sourceIds,
        'instructions': instructions,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  Report copyWith({String? title, ReportKind? kind, String? body, List<String>? sourceIds, String? instructions}) => Report(
        id: id,
        title: title ?? this.title,
        kind: kind ?? this.kind,
        body: body ?? this.body,
        sourceIds: sourceIds ?? this.sourceIds,
        instructions: instructions ?? this.instructions,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

// ── Focus sessions ───────────────────────────────────────────────────

@immutable
class FocusSession {
  const FocusSession({
    required this.id,
    required this.title,
    this.itemIds = const [],
    this.notes = '',
    this.summary = '',
    this.plannedMinutes = 25,
    required this.startedAt,
    this.endedAt,
    this.roomId,
  });

  final String id;
  final String title;
  final List<String> itemIds;
  final String notes;
  final String summary;
  final int plannedMinutes;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// Set when the session was a live group session.
  final String? roomId;

  bool get active => endedAt == null;
  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  factory FocusSession.fromMap(String id, Map<String, dynamic> m) => FocusSession(
        id: id,
        title: m['title'] as String? ?? 'Session',
        itemIds: _strings(m['itemIds']),
        notes: m['notes'] as String? ?? '',
        summary: m['summary'] as String? ?? '',
        plannedMinutes: (m['plannedMinutes'] as num?)?.toInt() ?? 25,
        startedAt: _date(m['startedAt']),
        endedAt: _dateOrNull(m['endedAt']),
        roomId: m['roomId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'itemIds': itemIds,
        'notes': notes,
        'summary': summary,
        'plannedMinutes': plannedMinutes,
        'startedAt': startedAt,
        'endedAt': endedAt,
        'roomId': roomId,
      };

  FocusSession copyWith({String? title, List<String>? itemIds, String? notes, String? summary, DateTime? endedAt}) =>
      FocusSession(
        id: id,
        title: title ?? this.title,
        itemIds: itemIds ?? this.itemIds,
        notes: notes ?? this.notes,
        summary: summary ?? this.summary,
        plannedMinutes: plannedMinutes,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        roomId: roomId,
      );
}

// ── Live rooms ───────────────────────────────────────────────────────

/// A paper or link shared into a live room (copied, since members can't
/// read each other's libraries).
@immutable
class SharedPaper {
  const SharedPaper({required this.title, this.url, this.authors = const [], this.year, this.sharedBy = ''});
  final String title;
  final String? url;
  final List<String> authors;
  final int? year;
  final String sharedBy;

  factory SharedPaper.fromMap(Map<String, dynamic> m) => SharedPaper(
        title: m['title'] as String? ?? 'Untitled',
        url: m['url'] as String?,
        authors: _strings(m['authors']),
        year: (m['year'] as num?)?.toInt(),
        sharedBy: m['sharedBy'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'title': title, 'url': url, 'authors': authors, 'year': year, 'sharedBy': sharedBy};
}

@immutable
class Room {
  const Room({
    required this.id,
    required this.title,
    required this.code,
    required this.hostUid,
    required this.hostName,
    this.topic = '',
    this.papers = const [],
    this.memberUids = const [],
    this.focusUntil,
    required this.createdAt,
    this.endedAt,
  });

  final String id;
  final String title;

  /// Six-character join code.
  final String code;
  final String hostUid;
  final String hostName;
  final String topic;
  final List<SharedPaper> papers;
  final List<String> memberUids;

  /// When the host starts a shared focus timer, everyone sees it count down.
  final DateTime? focusUntil;
  final DateTime createdAt;
  final DateTime? endedAt;

  bool get live => endedAt == null;

  factory Room.fromMap(String id, Map<String, dynamic> m) => Room(
        id: id,
        title: m['title'] as String? ?? 'Live session',
        code: m['code'] as String? ?? '',
        hostUid: m['hostUid'] as String? ?? '',
        hostName: m['hostName'] as String? ?? '',
        topic: m['topic'] as String? ?? '',
        papers: [for (final p in (m['papers'] as List? ?? const [])) if (p is Map) SharedPaper.fromMap(p.cast<String, dynamic>())],
        memberUids: _strings(m['memberUids']),
        focusUntil: _dateOrNull(m['focusUntil']),
        createdAt: _date(m['createdAt']),
        endedAt: _dateOrNull(m['endedAt']),
      );
}

@immutable
class RoomMember {
  const RoomMember({required this.uid, required this.name, required this.lastSeen});
  final String uid;
  final String name;
  final DateTime lastSeen;

  bool get online => DateTime.now().difference(lastSeen) < const Duration(seconds: 75);

  factory RoomMember.fromMap(String uid, Map<String, dynamic> m) =>
      RoomMember(uid: uid, name: m['name'] as String? ?? 'Member', lastSeen: _date(m['lastSeen']));
}

@immutable
class RoomMessage {
  const RoomMessage({required this.id, required this.uid, required this.name, required this.text, required this.createdAt});
  final String id;
  final String uid;
  final String name;
  final String text;
  final DateTime createdAt;

  factory RoomMessage.fromMap(String id, Map<String, dynamic> m) => RoomMessage(
        id: id,
        uid: m['uid'] as String? ?? '',
        name: m['name'] as String? ?? '',
        text: m['text'] as String? ?? '',
        createdAt: _date(m['createdAt']),
      );
}

// ── Devices ──────────────────────────────────────────────────────────

@immutable
class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.label,
    required this.platform,
    required this.signedInAt,
    required this.lastActiveAt,
    this.revoked = false,
  });

  final String id;
  final String label;
  final String platform;
  final DateTime signedInAt;
  final DateTime lastActiveAt;
  final bool revoked;

  factory DeviceSession.fromMap(String id, Map<String, dynamic> m) => DeviceSession(
        id: id,
        label: m['label'] as String? ?? 'Unknown device',
        platform: m['platform'] as String? ?? '',
        signedInAt: _date(m['signedInAt']),
        lastActiveAt: _date(m['lastActiveAt']),
        revoked: m['revoked'] as bool? ?? false,
      );
}

// ── Organisations ────────────────────────────────────────────────────

@immutable
class OrgMember {
  const OrgMember({required this.uid, required this.name, required this.email, required this.role});
  final String uid;
  final String name;
  final String email;
  final String role;
  bool get isAdmin => role == 'admin';

  factory OrgMember.fromMap(Map<String, dynamic> m) => OrgMember(
        uid: m['uid'] as String? ?? '',
        name: m['name'] as String? ?? '',
        email: m['email'] as String? ?? '',
        role: m['role'] as String? ?? 'member',
      );
}

/// A month's metered usage and what it costs.
@immutable
class UsageBill {
  const UsageBill({
    required this.activeMembers,
    required this.seatDays,
    required this.inputTokens,
    required this.outputTokens,
    required this.requests,
    required this.seatCostUsd,
    required this.aiCostUsd,
    required this.totalUsd,
    this.month,
    this.status,
  });

  final int activeMembers;
  final int seatDays;
  final int inputTokens;
  final int outputTokens;
  final int requests;
  final double seatCostUsd;
  final double aiCostUsd;
  final double totalUsd;
  final String? month;
  final String? status;

  static const empty = UsageBill(
      activeMembers: 0, seatDays: 0, inputTokens: 0, outputTokens: 0, requests: 0, seatCostUsd: 0, aiCostUsd: 0, totalUsd: 0);

  factory UsageBill.fromMap(Map<String, dynamic>? m) {
    if (m == null) return empty;
    double d(String k) => (m[k] as num?)?.toDouble() ?? 0;
    int i(String k) => (m[k] as num?)?.toInt() ?? 0;
    return UsageBill(
      activeMembers: i('activeMembers'),
      seatDays: i('seatDays'),
      inputTokens: i('inputTokens'),
      outputTokens: i('outputTokens'),
      requests: i('requests'),
      seatCostUsd: d('seatCostUsd'),
      aiCostUsd: d('aiCostUsd'),
      totalUsd: d('totalUsd'),
      month: m['month'] as String?,
      status: m['status'] as String?,
    );
  }
}

@immutable
class DailyUsage {
  const DailyUsage({required this.day, required this.activeMembers, required this.tokens, required this.requests});
  final String day;
  final int activeMembers;
  final int tokens;
  final int requests;

  factory DailyUsage.fromMap(Map<String, dynamic> m) => DailyUsage(
        day: m['day'] as String? ?? '',
        activeMembers: (m['activeMembers'] as num?)?.toInt() ?? 0,
        tokens: ((m['inputTokens'] as num?)?.toInt() ?? 0) + ((m['outputTokens'] as num?)?.toInt() ?? 0),
        requests: (m['requests'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class EnterprisePricing {
  const EnterprisePricing({
    this.seatDayUsd = 0.40,
    this.seatMonthCapUsd = 8.00,
    this.aiInputPerMillionUsd = 4.00,
    this.aiOutputPerMillionUsd = 20.00,
  });
  final double seatDayUsd;
  final double seatMonthCapUsd;
  final double aiInputPerMillionUsd;
  final double aiOutputPerMillionUsd;

  factory EnterprisePricing.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const EnterprisePricing();
    double d(String k, double f) => (m[k] as num?)?.toDouble() ?? f;
    return EnterprisePricing(
      seatDayUsd: d('seatDayUsd', 0.40),
      seatMonthCapUsd: d('seatMonthCapUsd', 8.00),
      aiInputPerMillionUsd: d('aiInputPerMillionUsd', 4.00),
      aiOutputPerMillionUsd: d('aiOutputPerMillionUsd', 20.00),
    );
  }
}

@immutable
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.role,
    this.inviteCode,
    this.members = const [],
    this.month,
    this.estimate = UsageBill.empty,
    this.daily = const [],
    this.pricing = const EnterprisePricing(),
  });

  final String id;
  final String name;
  final String role;
  final String? inviteCode;
  final List<OrgMember> members;
  final String? month;
  final UsageBill estimate;
  final List<DailyUsage> daily;
  final EnterprisePricing pricing;

  bool get isAdmin => role == 'admin';

  factory Organization.fromMap(Map<String, dynamic> m) => Organization(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        role: m['role'] as String? ?? 'member',
        inviteCode: m['inviteCode'] as String?,
        members: [for (final x in (m['members'] as List? ?? const [])) if (x is Map) OrgMember.fromMap(x.cast<String, dynamic>())],
        month: m['month'] as String?,
        estimate: UsageBill.fromMap((m['estimate'] as Map?)?.cast<String, dynamic>()),
        daily: [for (final x in (m['daily'] as List? ?? const [])) if (x is Map) DailyUsage.fromMap(x.cast<String, dynamic>())],
        pricing: EnterprisePricing.fromMap((m['pricing'] as Map?)?.cast<String, dynamic>()),
      );
}

/// Community rating for a paper.
@immutable
class PaperRating {
  const PaperRating({this.average, this.count = 0, this.mine});
  final double? average;
  final int count;
  final int? mine;

  factory PaperRating.fromMap(Map<String, dynamic>? m) => PaperRating(
        average: (m?['average'] as num?)?.toDouble(),
        count: (m?['count'] as num?)?.toInt() ?? 0,
        mine: (m?['mine'] as num?)?.toInt(),
      );
}
