import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class LetterScreen extends ConsumerStatefulWidget {
  const LetterScreen({super.key, required this.letterId});
  final String letterId;

  @override
  ConsumerState<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends ConsumerState<LetterScreen> {
  bool _markedRead = false;

  @override
  void initState() {
    super.initState();
    // Once the (unlocked) content has loaded, record that the recipient read it.
    ref.listenManual<AsyncValue<LetterContent>>(
      letterContentProvider(widget.letterId),
      (_, next) => next.whenData(_markRead),
      fireImmediately: true,
    );
  }

  void _markRead(LetterContent content) {
    if (_markedRead) return;
    final uid = ref.read(uidProvider);
    final coupleId = ref.read(coupleIdProvider);
    final letters = ref.read(lettersProvider).valueOrNull ?? const <Letter>[];
    final letter = letters.where((l) => l.id == widget.letterId).firstOrNull;
    if (uid == null || coupleId == null || letter == null) return;
    if (letter.toUid != uid || letter.readAt != null) return;
    _markedRead = true;
    ref
        .read(letterRepoProvider)
        .markRead(coupleId, letter.id, content.body)
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(uidProvider);
    final partner = ref.watch(partnerProvider).valueOrNull;
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final letters = ref.watch(lettersProvider).valueOrNull ?? const <Letter>[];
    final letter = letters.where((l) => l.id == widget.letterId).firstOrNull;

    if (letter == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const LoadingView(),
      );
    }

    final mine = letter.fromUid == uid;
    final partnerName = partner?.name ?? 'your partner';
    final sealed = !letter.isOpen(now) && !mine;

    return Scaffold(
      appBar: AppBar(),
      body: sealed
          ? EmptyState(
              icon: Icons.lock_outline,
              title: 'Still sealed',
              message: 'Opens ${shortDate(letter.openAt, now)}.',
            )
          : ref.watch(letterContentProvider(widget.letterId)).when(
                loading: () => const LoadingView(),
                error: (e, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not open this letter',
                  message: friendlyError(e),
                ),
                data: (content) {
                  // The letter list may load after the content; retry the receipt.
                  WidgetsBinding.instance.addPostFrameCallback((_) => _markRead(content));
                  return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
                  children: [
                    Text(letter.title,
                        style: const TextStyle(
                            fontSize: 30, height: 1.15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      '${mine ? 'To' : 'From'} $partnerName · ${shortDate(letter.createdAt, now)}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    SelectableText(
                      content.body,
                      style: const TextStyle(fontSize: 18, height: 1.6),
                    ),
                    if (content.photoUrls.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final url in content.photoUrls)
                            GestureDetector(
                              onTap: () => showFullImage(context, url),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: NetImage(url),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                  );
                },
              ),
    );
  }
}
