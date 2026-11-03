import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import 'storage_service.dart';

class MemoryRepository {
  MemoryRepository(this._db, this._storage);
  final FirebaseFirestore _db;
  final StorageService _storage;

  CollectionReference<Map<String, dynamic>> _col(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('memories');

  Stream<List<Memory>> stream(String coupleId) => _col(coupleId)
      .orderBy('date', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Memory.fromDoc).toList());

  Future<void> add({
    required String coupleId,
    required String uid,
    required String title,
    required DateTime date,
    XFile? photo,
  }) async {
    final ref = _col(coupleId).doc();
    String? url;
    if (photo != null) {
      url = await _storage.upload('couples/$coupleId/memories/${ref.id}.jpg', photo);
    }
    await ref.set({
      'title': title.trim(),
      'photoUrl': url,
      // Noon avoids the date shifting across time zones.
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day, 12)),
      'addedBy': uid,
      'saved': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setSaved(String coupleId, String id, bool saved) =>
      _col(coupleId).doc(id).update({'saved': saved});

  Future<void> delete(String coupleId, Memory m) async {
    await _col(coupleId).doc(m.id).delete();
    if (m.photoUrl != null) await _storage.deleteByUrl(m.photoUrl!);
  }
}
