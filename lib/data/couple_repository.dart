import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

class CoupleRepository {
  CoupleRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  // ---------------------------------------------------------------- streams
  Stream<AppUser?> userStream(String uid) => _user(uid)
      .snapshots()
      .map((s) => s.exists ? AppUser.fromDoc(s) : null);

  Stream<Couple?> coupleStream(String coupleId) => _db
      .collection('couples')
      .doc(coupleId)
      .snapshots()
      .map((s) => s.exists ? Couple.fromDoc(s) : null);

  // ----------------------------------------------------------- create / join
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  String _newCode() {
    final r = Random.secure();
    return List.generate(6, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
  }

  /// Creates the shared space and returns its invite code.
  Future<String> createCouple({
    required String uid,
    required DateTime startDate,
  }) async {
    final ref = _db.collection('couples').doc();
    final code = _newCode();
    await ref.set({
      'members': [uid],
      'createdBy': uid,
      'startDate': Timestamp.fromDate(
        DateTime(startDate.year, startDate.month, startDate.day),
      ),
      'inviteCode': code,
      'streak': 0,
      'lastStreakDate': null,
      'tzOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('invites').doc(code).set({
      'coupleId': ref.id,
      'createdBy': uid,
    });
    await _user(uid).update({'coupleId': ref.id});
    return code;
  }

  /// Joins the space that owns [code]. Throws a readable String on failure.
  Future<void> joinCouple({required String uid, required String code}) async {
    final normalized = code.trim().toUpperCase();
    final invite = await _db.collection('invites').doc(normalized).get();
    if (!invite.exists) {
      throw 'That code does not match any space. Check it and try again.';
    }
    final coupleId = invite.data()!['coupleId'] as String;
    final coupleRef = _db.collection('couples').doc(coupleId);

    // Recover from a half-finished join: if I am already a member, only the
    // profile link is missing. (Reading is denied for non-members.)
    var alreadyMember = false;
    try {
      final snap = await coupleRef.get();
      alreadyMember = (snap.data()?['members'] as List?)?.contains(uid) ?? false;
    } on FirebaseException {
      alreadyMember = false;
    }

    if (!alreadyMember) {
      try {
        await coupleRef.update({
          'members': FieldValue.arrayUnion([uid]),
        });
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          throw 'This space already has two people in it.';
        }
        rethrow;
      }
    }
    await _user(uid).update({'coupleId': coupleId});
  }

  // ---------------------------------------------------------------- profile
  Future<void> updateName(String uid, String name) =>
      _user(uid).update({'name': name.trim()});

  Future<void> setMood(String uid, String mood) => _user(uid).update({
        'mood': mood,
        'moodUpdatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> setStatus(String uid, String status) =>
      _user(uid).update({'status': status.trim()});

  Future<void> heartbeat(String uid) =>
      _user(uid).update({'lastSeen': FieldValue.serverTimestamp()});

  Future<void> updateStartDate(String coupleId, DateTime date) =>
      _db.collection('couples').doc(coupleId).update({
        'startDate': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      });
}
