import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dscvr/config/env.dart';
import 'package:dscvr/data/api.dart';
import 'package:dscvr/models/library.dart';
import 'package:dscvr/models/workspace.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live group sessions, signed-in devices and session summaries.
class SessionService {
  SessionService(this.api);
  final DscvrApi api;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  CollectionReference<Map<String, dynamic>> get _rooms => _db.collection('rooms');

  // ── Summaries ──────────────────────────────────────────────────────

  Future<String> summarize({
    required String title,
    required Duration duration,
    required String notes,
    required List<String> itemIds,
    String transcript = '',
  }) async {
    if (Env.demo) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return '''You spent ${duration.inMinutes} minutes on **$title**, working through ${itemIds.length} source${itemIds.length == 1 ? '' : 's'}.

- The core idea held up across your sources.
- Your notes flag one open question worth checking.
- The second source adds the strongest evidence.

**Next steps**
- Re-read the method section of your top source.
- Turn your notes into a short report.''';
    }
    final body = await api.post('/sessions/summary', {
      'title': title,
      'minutes': duration.inMinutes,
      'notes': notes,
      'itemIds': itemIds,
      'transcript': transcript,
    });
    return body['summary'] as String? ?? '';
  }

  // ── Live rooms ─────────────────────────────────────────────────────

  static String _code() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => alphabet[r.nextInt(alphabet.length)]).join();
  }

  Stream<List<Room>> watchMyRooms() {
    if (Env.demo || _uid.isEmpty) return Stream.value(const []);
    return _rooms
        .where('memberUids', arrayContains: _uid)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((s) => s.docs.map((d) => Room.fromMap(d.id, d.data())).toList());
  }

  Future<String> createRoom({required String title, required String topic, required String hostName}) async {
    final ref = _rooms.doc();
    final batch = _db.batch();
    batch.set(ref, {
      'title': title,
      'topic': topic,
      'code': _code(),
      'hostUid': _uid,
      'hostName': hostName,
      'memberUids': [_uid],
      'papers': <Map<String, dynamic>>[],
      'focusUntil': null,
      'createdAt': FieldValue.serverTimestamp(),
      'endedAt': null,
    });
    batch.set(ref.collection('members').doc(_uid), {'name': hostName, 'lastSeen': FieldValue.serverTimestamp()});
    await batch.commit();
    return ref.id;
  }

  /// Joins by code through the server, which checks the code without
  /// letting clients list every room.
  Future<String> joinRoom(String code) async {
    final body = await api.post('/rooms/join', {'code': code});
    return body['roomId'] as String;
  }

  Stream<Room?> watchRoom(String id) =>
      _rooms.doc(id).snapshots().map((d) => d.data() == null ? null : Room.fromMap(d.id, d.data()!));

  Stream<List<RoomMember>> watchMembers(String id) => _rooms
      .doc(id)
      .collection('members')
      .snapshots()
      .map((s) => s.docs.map((d) => RoomMember.fromMap(d.id, d.data())).toList()..sort((a, b) => a.name.compareTo(b.name)));

  Stream<List<RoomMessage>> watchMessages(String id) => _rooms
      .doc(id)
      .collection('messages')
      .orderBy('createdAt')
      .limitToLast(200)
      .snapshots()
      .map((s) => s.docs.map((d) => RoomMessage.fromMap(d.id, d.data())).toList());

  Future<void> send(String roomId, {required String name, required String text}) =>
      _rooms.doc(roomId).collection('messages').add({
        'uid': _uid,
        'name': name,
        'text': text.length > 2000 ? text.substring(0, 2000) : text,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> sharePaper(String roomId, LibraryItem item, {required String sharedBy}) => _rooms.doc(roomId).update({
        'papers': FieldValue.arrayUnion([
          SharedPaper(title: item.title, url: item.url ?? item.pdfUrl, authors: item.authors.take(6).toList(), year: item.year, sharedBy: sharedBy)
              .toMap(),
        ]),
      });

  /// Marks this member as present. Called every 30s while the room is open.
  Future<void> heartbeat(String roomId, String name) => _rooms
      .doc(roomId)
      .collection('members')
      .doc(_uid)
      .set({'name': name, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  Future<void> startFocus(String roomId, int minutes) =>
      _rooms.doc(roomId).update({'focusUntil': Timestamp.fromDate(DateTime.now().add(Duration(minutes: minutes)))});

  Future<void> stopFocus(String roomId) => _rooms.doc(roomId).update({'focusUntil': null});

  Future<void> endRoom(String roomId) => _rooms.doc(roomId).update({'endedAt': FieldValue.serverTimestamp(), 'focusUntil': null});

  Future<void> leaveRoom(String roomId) async {
    final batch = _db.batch();
    batch.update(_rooms.doc(roomId), {'memberUids': FieldValue.arrayRemove([_uid])});
    batch.delete(_rooms.doc(roomId).collection('members').doc(_uid));
    await batch.commit();
  }

  // ── Devices ────────────────────────────────────────────────────────

  static const _deviceKey = 'dscvr.deviceId';

  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceKey);
    if (id == null) {
      id = List.generate(20, (_) => Random.secure().nextInt(36).toRadixString(36)).join();
      await prefs.setString(_deviceKey, id);
    }
    return id;
  }

  static String _platformLabel() {
    if (kIsWeb) return 'Web browser';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iPhone or iPad',
      TargetPlatform.android => 'Android',
      TargetPlatform.macOS => 'Mac',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      _ => 'Device',
    };
  }

  CollectionReference<Map<String, dynamic>> _devices(String uid) => _db.collection('users').doc(uid).collection('devices');

  /// Registers this device and calls [onRevoked] if it's signed out remotely.
  Future<StreamSubscription<void>?> registerDevice(String uid, {required VoidCallback onRevoked}) async {
    if (Env.demo) return null;
    final id = await deviceId();
    final ref = _devices(uid).doc(id);
    final existing = await ref.get();
    final data = existing.data();
    if (data != null && data['revoked'] == true) {
      // A fresh sign-in on a previously revoked device starts clean.
      await ref.set({'revoked': false, 'signedInAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    await ref.set({
      'label': _platformLabel(),
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      if (data == null) 'signedInAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
      'revoked': false,
    }, SetOptions(merge: true));
    return ref.snapshots().skip(1).listen((d) {
      if (d.data()?['revoked'] == true) onRevoked();
    });
  }

  Stream<List<DeviceSession>> watchDevices(String uid) {
    if (Env.demo) {
      final now = DateTime.now();
      return Stream.value([
        DeviceSession(id: 'this', label: _platformLabel(), platform: 'web', signedInAt: now.subtract(const Duration(days: 3)), lastActiveAt: now),
        DeviceSession(id: 'phone', label: 'iPhone or iPad', platform: 'iOS', signedInAt: now.subtract(const Duration(days: 9)), lastActiveAt: now.subtract(const Duration(hours: 5))),
      ]);
    }
    return _devices(uid)
        .orderBy('lastActiveAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => DeviceSession.fromMap(d.id, d.data())).where((d) => !d.revoked).toList());
  }

  Future<void> revokeDevice(String uid, String deviceId) =>
      _devices(uid).doc(deviceId).set({'revoked': true}, SetOptions(merge: true));

  Future<void> revokeOthers(String uid) async {
    final me = await deviceId();
    final all = await _devices(uid).get();
    final batch = _db.batch();
    for (final d in all.docs) {
      if (d.id != me) batch.set(d.reference, {'revoked': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
