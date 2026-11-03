import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

class TogetherRepository {
  TogetherRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String coupleId, String name) =>
      _db.collection('couples').doc(coupleId).collection(name);

  // ----------------------------------------------------------------- to-dos
  Stream<List<TodoItem>> todos(String coupleId) => _col(coupleId, 'todos')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(TodoItem.fromDoc).toList());

  Future<void> addTodo(String coupleId, String uid, String text) =>
      _col(coupleId, 'todos').add({
        'text': text.trim(),
        'done': false,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> setTodoDone(String coupleId, String id, bool done) =>
      _col(coupleId, 'todos').doc(id).update({'done': done});

  Future<void> deleteTodo(String coupleId, String id) =>
      _col(coupleId, 'todos').doc(id).delete();

  // ------------------------------------------------------------------ goals
  Stream<List<Goal>> goals(String coupleId) => _col(coupleId, 'goals')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(Goal.fromDoc).toList());

  Future<void> addGoal(String coupleId, String uid, String title) =>
      _col(coupleId, 'goals').add({
        'title': title.trim(),
        'reachedAt': null,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> setGoalReached(String coupleId, String id, bool reached) =>
      _col(coupleId, 'goals').doc(id).update({
        'reachedAt': reached ? FieldValue.serverTimestamp() : null,
      });

  Future<void> deleteGoal(String coupleId, String id) =>
      _col(coupleId, 'goals').doc(id).delete();

  // --------------------------------------------------------- daily question
  /// Who has answered on [dateKey] (public marker, not the text).
  Stream<Set<String>> answeredUids(String coupleId, String dateKey) =>
      _col(coupleId, 'answered')
          .where('dateKey', isEqualTo: dateKey)
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()['uid'] as String).toSet());

  Stream<String?> answerText(String coupleId, String dateKey, String uid) =>
      _col(coupleId, 'answers')
          .doc('${dateKey}_$uid')
          .snapshots()
          .map((s) => s.data()?['text'] as String?);

  /// Saves my answer. If my partner already answered today, the streak is
  /// updated in the same transaction.
  Future<void> submitAnswer({
    required String coupleId,
    required String uid,
    required String? partnerId,
    required String dateKey,
    required String yesterdayKey,
    required String text,
  }) async {
    final answers = _col(coupleId, 'answers');
    final answered = _col(coupleId, 'answered');
    final coupleRef = _db.collection('couples').doc(coupleId);

    await _db.runTransaction((tx) async {
      // All reads first.
      final partnerMarker = partnerId == null
          ? null
          : await tx.get(answered.doc('${dateKey}_$partnerId'));
      final coupleSnap = await tx.get(coupleRef);

      tx.set(answers.doc('${dateKey}_$uid'), {
        'uid': uid,
        'dateKey': dateKey,
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(answered.doc('${dateKey}_$uid'), {
        'uid': uid,
        'dateKey': dateKey,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (partnerMarker != null && partnerMarker.exists) {
        final data = coupleSnap.data() ?? {};
        final last = data['lastStreakDate'] as String?;
        final streak = (data['streak'] as num?)?.toInt() ?? 0;
        if (last != dateKey) {
          tx.update(coupleRef, {
            'streak': last == yesterdayKey ? streak + 1 : 1,
            'lastStreakDate': dateKey,
          });
        }
      }
    });
  }
}
