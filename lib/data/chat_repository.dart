import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import 'storage_service.dart';

class ChatRepository {
  ChatRepository(this._db, this._storage);
  final FirebaseFirestore _db;
  final StorageService _storage;

  CollectionReference<Map<String, dynamic>> _col(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('messages');

  /// Newest first, last 150 messages.
  Stream<List<ChatMessage>> stream(String coupleId) => _col(coupleId)
      .orderBy('createdAt', descending: true)
      .limit(150)
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromDoc).toList());

  Future<void> sendText(String coupleId, String uid, String text) =>
      _col(coupleId).add({
        'fromUid': uid,
        'text': text.trim(),
        'imageUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'deliveredAt': null,
        'readAt': null,
      });

  Future<void> sendImage(String coupleId, String uid, XFile file) async {
    final ref = _col(coupleId).doc();
    final url = await _storage.upload('couples/$coupleId/chat/${ref.id}.jpg', file);
    await ref.set({
      'fromUid': uid,
      'text': null,
      'imageUrl': url,
      'createdAt': FieldValue.serverTimestamp(),
      'deliveredAt': null,
      'readAt': null,
    });
  }

  Future<void> markDelivered(String coupleId, List<String> ids) async {
    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_col(coupleId).doc(id), {'deliveredAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  Future<void> markRead(String coupleId, List<String> ids) async {
    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_col(coupleId).doc(id), {
        'readAt': FieldValue.serverTimestamp(),
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
