import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import 'storage_service.dart';

class LetterRepository {
  LetterRepository(this._db, this._storage);
  final FirebaseFirestore _db;
  final StorageService _storage;

  CollectionReference<Map<String, dynamic>> _col(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('letters');

  Stream<List<Letter>> stream(String coupleId) => _col(coupleId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Letter.fromDoc).toList());

  Future<LetterContent> content(String coupleId, String letterId) async {
    final snap = await _col(coupleId).doc(letterId).collection('content').doc('body').get();
    return LetterContent.fromDoc(snap);
  }

  /// Sends a letter. [openAt] null means "deliver now".
  ///
  /// The letter is split in two documents: public metadata (title, seal note)
  /// and a `content/body` document that security rules keep locked until
  /// [openAt], so a sealed letter really is sealed on the server.
  Future<void> send({
    required String coupleId,
    required String fromUid,
    required String toUid,
    required String title,
    required String body,
    List<XFile> photos = const [],
    DateTime? openAt,
    String? sealNote,
  }) async {
    final ref = _col(coupleId).doc();

    final urls = <String>[];
    for (var i = 0; i < photos.length; i++) {
      urls.add(await _storage.upload(
        'couples/$coupleId/letters/${ref.id}/$i.jpg',
        photos[i],
      ));
    }

    final scheduled = openAt != null;
    final oneLine = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final batch = _db.batch();
    batch.set(ref, {
      'fromUid': fromUid,
      'toUid': toUid,
      'title': title.trim(),
      // Never put the text in a sealed letter's public metadata.
      'preview': scheduled
          ? null
          : (oneLine.length > 110 ? '${oneLine.substring(0, 110)}…' : oneLine),
      'sealNote': scheduled && (sealNote?.trim().isNotEmpty ?? false)
          ? sealNote!.trim()
          : null,
      'photoCount': urls.length,
      'createdAt': FieldValue.serverTimestamp(),
      // Same server timestamp as createdAt => delivered immediately.
      'openAt': scheduled ? Timestamp.fromDate(openAt) : FieldValue.serverTimestamp(),
      'readAt': null,
      'notified': false,
    });
    batch.set(ref.collection('content').doc('body'), {
      'body': body.trim(),
      'photoUrls': urls,
    });
    await batch.commit();
  }

  /// Recipient opened the letter: store read time and a public preview.
  Future<void> markRead(String coupleId, String letterId, String body) {
    final oneLine = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _col(coupleId).doc(letterId).update({
      'readAt': FieldValue.serverTimestamp(),
      'preview': oneLine.length > 110 ? '${oneLine.substring(0, 110)}…' : oneLine,
    });
  }

  /// Takes back a letter that has not been delivered yet.
  Future<void> cancelScheduled(String coupleId, String letterId) async {
    final ref = _col(coupleId).doc(letterId);
    final batch = _db.batch();
    batch.delete(ref.collection('content').doc('body'));
    batch.delete(ref);
    await batch.commit();
    await _storage.deleteFolder('couples/$coupleId/letters/$letterId');
  }
}
