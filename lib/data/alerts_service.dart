import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dscvr/config/env.dart';
import 'package:dscvr/models/paper.dart';

/// One new item found in a followed subject (written by the server).
class AlertItem {
  const AlertItem({required this.id, required this.subject, required this.paper, required this.read, required this.createdAt});
  final String id;
  final String subject;
  final Paper paper;
  final bool read;
  final DateTime createdAt;

  factory AlertItem.fromDoc(String id, Map<String, dynamic> d) => AlertItem(
        id: id,
        subject: d['subject'] as String? ?? '',
        read: d['read'] as bool? ?? false,
        createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        paper: Paper.fromMap({
          'id': d['paperId'] ?? id,
          'title': d['title'],
          'source': d['source'],
          'authors': d['authors'],
          'year': d['year'],
          'summary': d['summary'],
          'url': d['url'],
          'pdfUrl': d['pdfUrl'],
          'venue': d['venue'],
          'kind': d['kind'],
          'citation': d['source'] == 'uk_caselaw' ? d['venue'] : null,
        }),
      );
}

class AlertsService {
  AlertsService(this.uid);
  final String uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('alerts');

  Stream<List<AlertItem>> watch({int limit = 100}) {
    if (Env.demo || uid.isEmpty) return Stream.value(const []);
    return _col.orderBy('createdAt', descending: true).limit(limit).snapshots().map(
          (q) => [for (final d in q.docs) AlertItem.fromDoc(d.id, d.data())],
        );
  }

  Stream<int> unread() {
    if (Env.demo || uid.isEmpty) return Stream.value(0);
    return _col.where('read', isEqualTo: false).limit(99).snapshots().map((q) => q.size);
  }

  Future<void> markRead(String id) => _col.doc(id).update({'read': true});

  Future<void> markAllRead(List<AlertItem> items) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final a in items.where((a) => !a.read)) {
      batch.update(_col.doc(a.id), {'read': true});
    }
    await batch.commit();
  }

  Future<void> remove(String id) => _col.doc(id).delete();
}
