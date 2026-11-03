import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class LettersScreen extends ConsumerStatefulWidget {
  const LettersScreen({super.key});

  @override
  ConsumerState<LettersScreen> createState() => _LettersScreenState();
}

class _LettersScreenState extends ConsumerState<LettersScreen> {
  int _tab = 0; // 0 received, 1 sent, 2 scheduled

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(uidProvider);
    final partner = ref.watch(partnerProvider).valueOrNull;
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final lettersAsync = ref.watch(lettersProvider);
    final letters = lettersAsync.valueOrNull ?? const <Letter>[];
    final partnerName = partner?.name ?? 'your partner';

    final received = letters.where((l) => l.toUid == uid).toList();
    final sent = letters.where((l) => l.fromUid == uid && l.isOpen(now)).toList();
    final scheduled = letters.where((l) => l.fromUid == uid && !l.isOpen(now)).toList()
      ..sort((a, b) => a.openAt.compareTo(b.openAt));
    final unread = received.where((l) => l.isOpen(now) && l.readAt == null).length;

    final subtitle = unread == 0
        ? 'No new letters'
        : unread == 1
            ? 'One new letter from $partnerName'
            : '$unread new letters from $partnerName';

    final shown = [received, sent, scheduled][_tab];

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenHeader(title: 'Love Letters', subtitle: subtitle),
                const SizedBox(height: 16),
                _Tabs(
                  index: _tab,
                  labels: ['Received', 'Sent', 'Scheduled · ${scheduled.length}'],
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ],
            ),
          ),
          Expanded(
            child: lettersAsync.isLoading && letters.isEmpty
                ? const LoadingView()
                : shown.isEmpty
                    ? EmptyState(
                        icon: Icons.mail_outline,
                        title: ['No letters yet', 'Nothing sent yet', 'Nothing scheduled'][_tab],
                        message: [
                          'When $partnerName writes to you, it will land here.',
                          'Write something they can keep.',
                          'Seal a letter to open on a special day.',
                        ][_tab],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _LetterCard(
                          letter: shown[i],
                          mine: shown[i].fromUid == uid,
                          partnerName: partnerName,
                          now: now,
                        ),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: partner == null
                    ? () => showInfo(context, 'Your partner needs to join first.')
                    : () => context.push('/write-letter'),
                icon: const Icon(Icons.add),
                label: const Text('Write a letter'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.index, required this.labels, required this.onChanged});
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                      color: i == index ? AppColors.ink : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LetterCard extends ConsumerWidget {
  const _LetterCard({
    required this.letter,
    required this.mine,
    required this.partnerName,
    required this.now,
  });
  final Letter letter;
  final bool mine;
  final String partnerName;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = letter.isOpen(now);

    // ---- sealed (not yet openable) ----
    if (!open) {
      final days = calendarDaysBetween(now, letter.openAt);
      final title = mine ? 'Sealed for $partnerName' : 'Sealed by $partnerName';
      final opens = 'Opens ${shortDate(letter.openAt, now)} · ${inDaysLabel(days)}';
      return DashedBox(
        onTap: () => mine
            ? _confirmCancel(context, ref)
            : showInfo(context, 'This letter opens on ${DateFormat('d MMMM').format(letter.openAt)}.'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CircleIcon(
                icon: Icons.lock_outline,
                background: AppColors.lavender,
                color: AppColors.muted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(opens, style: const TextStyle(color: AppColors.muted)),
                    if (letter.sealNote != null) ...[
                      const SizedBox(height: 4),
                      Text(letter.sealNote!, style: const TextStyle(height: 1.3)),
                    ],
                    if (mine) ...[
                      const SizedBox(height: 6),
                      const Text('Tap to take it back',
                          style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ---- delivered ----
    final isNew = !mine && letter.readAt == null;
    final meta = <String>[
      mine ? 'To $partnerName' : 'From $partnerName',
      relativeDay(letter.createdAt, now),
      if (letter.photoCount > 0) plural(letter.photoCount, 'photo'),
    ].join(' · ');

    return AppCard(
      borderColor: isNew ? AppColors.accent : AppColors.line,
      padding: const EdgeInsets.all(16),
      onTap: () => context.push('/letter/${letter.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleIcon(
            icon: isNew ? Icons.mail_outline : Icons.drafts_outlined,
            background: isNew ? AppColors.accentSoft : AppColors.periwinkle,
            color: isNew ? AppColors.accent : AppColors.periwinkleInk,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(letter.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                    if (isNew)
                      const Pill('New', background: AppColors.accent, foreground: Colors.white),
                  ],
                ),
                const SizedBox(height: 2),
                Text(meta, style: const TextStyle(color: AppColors.muted)),
                if (letter.preview != null && letter.preview!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(letter.preview!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, height: 1.35)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Take back this letter?'),
        content: const Text('It has not been delivered yet. It will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    try {
      await ref.read(letterRepoProvider).cancelScheduled(coupleId, letter.id);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.background, required this.color});
  final IconData icon;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: color),
      );
}
