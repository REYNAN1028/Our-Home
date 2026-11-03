import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils.dart';

typedef Doc = DocumentSnapshot<Map<String, dynamic>>;

DateTime? tsToDate(dynamic v) => v is Timestamp ? v.toDate() : null;

// ------------------------------------------------------------------ user
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.coupleId,
    this.mood,
    this.status,
    this.moodUpdatedAt,
    this.lastSeen,
  });

  final String uid;
  final String name;
  final String email;
  final String? coupleId;
  final String? mood;
  final String? status;
  final DateTime? moodUpdatedAt;
  final DateTime? lastSeen;

  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  bool isOnline(DateTime now) =>
      lastSeen != null && now.difference(lastSeen!).inSeconds < 150;

  factory AppUser.fromDoc(Doc doc) {
    final d = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      name: (d['name'] as String?) ?? '',
      email: (d['email'] as String?) ?? '',
      coupleId: d['coupleId'] as String?,
      mood: d['mood'] as String?,
      status: d['status'] as String?,
      moodUpdatedAt: tsToDate(d['moodUpdatedAt']),
      lastSeen: tsToDate(d['lastSeen']),
    );
  }
}

// ---------------------------------------------------------------- couple
class Couple {
  const Couple({
    required this.id,
    required this.members,
    required this.startDate,
    required this.inviteCode,
    required this.streak,
    required this.lastStreakDate,
    required this.tzOffsetMinutes,
  });

  final String id;
  final List<String> members;
  final DateTime startDate;
  final String inviteCode;
  final int streak;
  final String? lastStreakDate;
  final int tzOffsetMinutes;

  /// The streak only counts if the last completed day was today or yesterday.
  int streakFor(DateTime coupleDay) {
    if (lastStreakDate == null) return 0;
    final today = dateKey(coupleDay);
    final yesterday = dateKey(coupleDay.subtract(const Duration(days: 1)));
    return (lastStreakDate == today || lastStreakDate == yesterday) ? streak : 0;
  }

  factory Couple.fromDoc(Doc doc) {
    final d = doc.data() ?? {};
    return Couple(
      id: doc.id,
      members: List<String>.from(d['members'] ?? const []),
      startDate: tsToDate(d['startDate']) ?? DateTime.now(),
      inviteCode: (d['inviteCode'] as String?) ?? '',
      streak: (d['streak'] as num?)?.toInt() ?? 0,
      lastStreakDate: d['lastStreakDate'] as String?,
      tzOffsetMinutes: (d['tzOffsetMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}

// ---------------------------------------------------------------- letter
class Letter {
  const Letter({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.title,
    required this.preview,
    required this.sealNote,
    required this.photoCount,
    required this.createdAt,
    required this.openAt,
    required this.readAt,
  });

  final String id;
  final String fromUid;
  final String toUid;
  final String title;
  final String? preview;
  final String? sealNote;
  final int photoCount;
  final DateTime createdAt;
  final DateTime openAt;
  final DateTime? readAt;

  /// Letters sent "now" get openAt == createdAt (same server timestamp);
  /// only a letter with a real future date counts as scheduled.
  bool get isScheduled => openAt.difference(createdAt).inMinutes >= 2;

  bool isOpen(DateTime now) => !isScheduled || !openAt.isAfter(now);

  factory Letter.fromDoc(Doc doc) {
    final d = doc.data() ?? {};
    final created = tsToDate(d['createdAt']) ?? DateTime.now();
    return Letter(
      id: doc.id,
      fromUid: (d['fromUid'] as String?) ?? '',
      toUid: (d['toUid'] as String?) ?? '',
      title: (d['title'] as String?) ?? '',
      preview: d['preview'] as String?,
      sealNote: d['sealNote'] as String?,
      photoCount: (d['photoCount'] as num?)?.toInt() ?? 0,
      createdAt: created,
      openAt: tsToDate(d['openAt']) ?? created,
      readAt: tsToDate(d['readAt']),
    );
  }
}

class LetterContent {
  const LetterContent({required this.body, required this.photoUrls});
  final String body;
  final List<String> photoUrls;

  factory LetterContent.fromDoc(Doc doc) {
    final d = doc.data() ?? {};
    return LetterContent(
      body: (d['body'] as String?) ?? '',
      photoUrls: List<String>.from(d['photoUrls'] ?? const []),
    );
  }
}

// ---------------------------------------------------------------- memory
class Memory {
  const Memory({
    required this.id,
    required this.title,
    required this.photoUrl,
    required this.date,
    required this.addedBy,
    required this.saved,
  });

  final String id;
  final String title;
  final String? photoUrl;
  final DateTime date;
  final String addedBy;
  final bool saved;

  factory Memory.fromDoc(Doc doc) {
    final d = doc.data() ?? {};
    return Memory(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      photoUrl: d['photoUrl'] as String?,
      date: tsToDate(d['date']) ?? DateTime.now(),
      addedBy: (d['addedBy'] as String?) ?? '',
      saved: (d['saved'] as bool?) ?? false,
    );
  }
}

// ----------------------------------------------------------- to-dos, goals
class TodoItem {
  const TodoItem({required this.id, required this.text, required this.done});
  final String id;
  final String text;
  final bool done;

  factory TodoItem.fromDoc(Doc doc) {
    final d = doc.data() ?? {};
    return TodoItem(
      id: doc.id,
      text: (d['text'] as String?) ?? '',
      done: (d['done'] as bool?) ?? false,
    );
  }
}

class Goal {
  const Goal({required this.id, required this.title, required this.reachedAt});
  final String id;
  final String title;
  final DateTime? reachedAt;

  bool get reached => reachedAt != null;

  factory Goal.fromDoc(Doc doc) {
    final d = doc.data() ?? {};
    return Goal(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      reachedAt: tsToDate(d['reachedAt']),
    );
  }
}

// ------------------------------------------------------------------ chat
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.fromUid,
    required this.text,
    required this.imageUrl,
    required this.createdAt,
    required this.deliveredAt,
    required this.readAt,
  });

  final String id;
  final String fromUid;
  final String? text;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  factory ChatMessage.fromDoc(Doc doc) {
    final d = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      fromUid: (d['fromUid'] as String?) ?? '',
      text: d['text'] as String?,
      imageUrl: d['imageUrl'] as String?,
      // Null while the server timestamp is still pending on this device.
      createdAt: tsToDate(d['createdAt']) ?? DateTime.now(),
      deliveredAt: tsToDate(d['deliveredAt']),
      readAt: tsToDate(d['readAt']),
    );
  }
}
