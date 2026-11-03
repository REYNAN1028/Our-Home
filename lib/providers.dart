import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/content.dart';
import 'core/utils.dart';
import 'data/auth_repository.dart';
import 'data/chat_repository.dart';
import 'data/couple_repository.dart';
import 'data/letter_repository.dart';
import 'data/memory_repository.dart';
import 'data/storage_service.dart';
import 'data/together_repository.dart';
import 'models/models.dart';

// ------------------------------------------------------------ firebase + repos
final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);
final firebaseAuthProvider = Provider((ref) => FirebaseAuth.instance);
final firebaseStorageProvider = Provider((ref) => FirebaseStorage.instance);

final storageServiceProvider =
    Provider((ref) => StorageService(ref.watch(firebaseStorageProvider)));

final authRepoProvider = Provider(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider)),
);
final coupleRepoProvider =
    Provider((ref) => CoupleRepository(ref.watch(firestoreProvider)));
final letterRepoProvider = Provider(
  (ref) => LetterRepository(ref.watch(firestoreProvider), ref.watch(storageServiceProvider)),
);
final memoryRepoProvider = Provider(
  (ref) => MemoryRepository(ref.watch(firestoreProvider), ref.watch(storageServiceProvider)),
);
final togetherRepoProvider =
    Provider((ref) => TogetherRepository(ref.watch(firestoreProvider)));
final chatRepoProvider = Provider(
  (ref) => ChatRepository(ref.watch(firestoreProvider), ref.watch(storageServiceProvider)),
);

// ------------------------------------------------------------------- identity
final authStateProvider =
    StreamProvider<User?>((ref) => ref.watch(authRepoProvider).authChanges());

final uidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider.select((v) => v.valueOrNull?.uid)),
);

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(coupleRepoProvider).userStream(uid);
});

final coupleIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider.select((v) => v.valueOrNull?.coupleId)),
);

final coupleProvider = StreamProvider<Couple?>((ref) {
  final id = ref.watch(coupleIdProvider);
  if (id == null) return Stream.value(null);
  return ref.watch(coupleRepoProvider).coupleStream(id);
});

final partnerIdProvider = Provider<String?>((ref) {
  final uid = ref.watch(uidProvider);
  final members = ref.watch(coupleProvider.select((v) => v.valueOrNull?.members));
  if (uid == null || members == null) return null;
  for (final m in members) {
    if (m != uid) return m;
  }
  return null;
});

final partnerProvider = StreamProvider<AppUser?>((ref) {
  final id = ref.watch(partnerIdProvider);
  if (id == null) return Stream.value(null);
  return ref.watch(coupleRepoProvider).userStream(id);
});

// ---------------------------------------------------------------------- time
/// Ticks every 30s so "online now", sealed letters and countdowns stay fresh.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

DateTime _now(Ref ref) => ref.watch(clockProvider).valueOrNull ?? DateTime.now();

/// Calendar day shared by both partners (see [coupleToday]).
final coupleDayProvider = Provider<DateTime>((ref) {
  final now = _now(ref);
  final offset = ref.watch(coupleProvider.select((v) => v.valueOrNull?.tzOffsetMinutes)) ??
      DateTime.now().timeZoneOffset.inMinutes;
  return coupleToday(now, offset);
});

final todayKeyProvider = Provider<String>((ref) => dateKey(ref.watch(coupleDayProvider)));

final yesterdayKeyProvider = Provider<String>(
  (ref) => dateKey(ref.watch(coupleDayProvider).subtract(const Duration(days: 1))),
);

final dailyQuestionProvider = Provider<String>((ref) {
  final day = epochDay(ref.watch(coupleDayProvider));
  return dailyQuestions[day % dailyQuestions.length];
});

final dailyNoteProvider = Provider<String>((ref) {
  final day = epochDay(ref.watch(coupleDayProvider));
  final name = ref.watch(partnerProvider.select((v) => v.valueOrNull?.name)) ?? 'your partner';
  return dailyNotes[day % dailyNotes.length].replaceAll('{name}', name);
});

final streakProvider = Provider<int>((ref) {
  final couple = ref.watch(coupleProvider).valueOrNull;
  return couple?.streakFor(ref.watch(coupleDayProvider)) ?? 0;
});

// ------------------------------------------------------------------ app data
final lettersProvider = StreamProvider<List<Letter>>((ref) {
  final c = ref.watch(coupleIdProvider);
  if (c == null) return Stream.value(const <Letter>[]);
  return ref.watch(letterRepoProvider).stream(c);
});

final letterContentProvider =
    FutureProvider.autoDispose.family<LetterContent, String>((ref, letterId) {
  final c = ref.watch(coupleIdProvider);
  if (c == null) throw StateError('No couple');
  return ref.watch(letterRepoProvider).content(c, letterId);
});

final memoriesProvider = StreamProvider<List<Memory>>((ref) {
  final c = ref.watch(coupleIdProvider);
  if (c == null) return Stream.value(const <Memory>[]);
  return ref.watch(memoryRepoProvider).stream(c);
});

final todosProvider = StreamProvider<List<TodoItem>>((ref) {
  final c = ref.watch(coupleIdProvider);
  if (c == null) return Stream.value(const <TodoItem>[]);
  return ref.watch(togetherRepoProvider).todos(c);
});

final goalsProvider = StreamProvider<List<Goal>>((ref) {
  final c = ref.watch(coupleIdProvider);
  if (c == null) return Stream.value(const <Goal>[]);
  return ref.watch(togetherRepoProvider).goals(c);
});

final messagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  final c = ref.watch(coupleIdProvider);
  if (c == null) return Stream.value(const <ChatMessage>[]);
  return ref.watch(chatRepoProvider).stream(c);
});

// -------------------------------------------------------------- daily answers
final answeredTodayProvider = StreamProvider<Set<String>>((ref) {
  final c = ref.watch(coupleIdProvider);
  final key = ref.watch(todayKeyProvider);
  if (c == null) return Stream.value(const <String>{});
  return ref.watch(togetherRepoProvider).answeredUids(c, key);
});

final iAnsweredProvider = Provider<bool>((ref) {
  final uid = ref.watch(uidProvider);
  final answered = ref.watch(answeredTodayProvider).valueOrNull ?? const <String>{};
  return uid != null && answered.contains(uid);
});

final partnerAnsweredProvider = Provider<bool>((ref) {
  final pid = ref.watch(partnerIdProvider);
  final answered = ref.watch(answeredTodayProvider).valueOrNull ?? const <String>{};
  return pid != null && answered.contains(pid);
});

// The answer text documents only exist once someone answered, and the partner's
// stays locked by security rules until I have answered too - so only listen then.
final myAnswerProvider = StreamProvider<String?>((ref) {
  final uid = ref.watch(uidProvider);
  final c = ref.watch(coupleIdProvider);
  final key = ref.watch(todayKeyProvider);
  if (uid == null || c == null || !ref.watch(iAnsweredProvider)) {
    return Stream.value(null);
  }
  return ref.watch(togetherRepoProvider).answerText(c, key, uid);
});

final partnerAnswerProvider = StreamProvider<String?>((ref) {
  final pid = ref.watch(partnerIdProvider);
  final c = ref.watch(coupleIdProvider);
  final key = ref.watch(todayKeyProvider);
  if (pid == null ||
      c == null ||
      !ref.watch(iAnsweredProvider) ||
      !ref.watch(partnerAnsweredProvider)) {
    return Stream.value(null);
  }
  return ref.watch(togetherRepoProvider).answerText(c, key, pid);
});

// ------------------------------------------------------------------- badges
final unreadMessagesProvider = Provider<int>((ref) {
  final uid = ref.watch(uidProvider);
  final msgs = ref.watch(messagesProvider).valueOrNull ?? const <ChatMessage>[];
  return msgs.where((m) => m.fromUid != uid && m.readAt == null).length;
});

final unreadLettersProvider = Provider<int>((ref) {
  final uid = ref.watch(uidProvider);
  final now = _now(ref);
  final letters = ref.watch(lettersProvider).valueOrNull ?? const <Letter>[];
  return letters.where((l) => l.toUid == uid && l.isOpen(now) && l.readAt == null).length;
});

/// Index of the visible bottom-nav tab (set by the shell).
final tabIndexProvider = StateProvider<int>((ref) => 0);
