import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/content.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../together/answer_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final couple = ref.watch(coupleProvider).valueOrNull;
    final partner = ref.watch(partnerProvider).valueOrNull;
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greetingFor(now),
                        style: const TextStyle(fontSize: 16, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text('Hi, ${me?.name ?? ''}',
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              RoundIconButton(
                icon: Icons.settings_outlined,
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (couple != null) _DaysCard(couple: couple, now: now) else const _DaysCardSkeleton(),
          const SizedBox(height: 14),
          _PartnerCard(partner: partner, couple: couple, now: now),
          const SizedBox(height: 14),
          _MoodCard(me: me),
          const SizedBox(height: 14),
          _QuestionCard(partner: partner),
          const SizedBox(height: 14),
          const _NoteCard(),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- days together
class _DaysCard extends StatelessWidget {
  const _DaysCard({required this.couple, required this.now});
  final Couple couple;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final stats = RelationshipStats.compute(couple.startDate, now);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${stats.days}',
                  style: const TextStyle(
                    fontSize: 64,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  )),
              const SizedBox(width: 10),
              const Text('days together',
                  style: TextStyle(fontSize: 20, color: AppColors.mutedOnInk)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stats.progress,
              minHeight: 7,
              backgroundColor: AppColors.inkTrack,
              color: AppColors.accentLight,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Since ${DateFormat('d MMM yyyy').format(couple.startDate)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.mutedOnInk)),
              Text('${stats.nextDayMark} days ${inDaysLabel(stats.daysToMark)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.mutedOnInk)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MiniTile(stats.nextMonth)),
              const SizedBox(width: 10),
              Expanded(child: _MiniTile(stats.nextYear)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile(this.milestone);
  final Milestone milestone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inkSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(milestone.label,
              style: const TextStyle(fontSize: 13, color: AppColors.mutedOnInk)),
          const SizedBox(height: 2),
          Text(inDaysLabel(milestone.daysAway),
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}

class _DaysCardSkeleton extends StatelessWidget {
  const _DaysCardSkeleton();
  @override
  Widget build(BuildContext context) => Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
}

// --------------------------------------------------------------- partner card
class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.partner, required this.couple, required this.now});
  final AppUser? partner;
  final Couple? couple;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    // Partner has not joined yet: show the invite code.
    if (partner == null) {
      final code = couple?.inviteCode ?? '';
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Avatar('?', size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Waiting for your partner',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Share this code: $code',
                      style: const TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              onPressed: code.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: code));
                      showInfo(context, 'Invite code copied.');
                    },
            ),
          ],
        ),
      );
    }

    final p = partner!;
    final online = p.isOnline(now);
    final parts = <String>[
      if (p.status != null && p.status!.isNotEmpty) p.status!,
      online ? 'online now' : lastSeenLabel(p.lastSeen, now),
    ];
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Avatar(p.initial, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(parts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          if (p.mood != null) Pill(moodLabel(p.mood)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ mood card
class _MoodCard extends ConsumerWidget {
  const _MoodCard({required this.me});
  final AppUser? me;

  static const _icons = <String, IconData>{
    'happy': Icons.sentiment_satisfied_alt_outlined,
    'calm': Icons.sentiment_neutral_outlined,
    'tired': Icons.bedtime_outlined,
    'low': Icons.sentiment_dissatisfied_outlined,
    'anxious': Icons.sentiment_very_dissatisfied_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Text('How are you feeling?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final m in moods)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _MoodTile(
                      icon: _icons[m.key]!,
                      label: m.label,
                      selected: me?.mood == m.key,
                      onTap: me == null
                          ? null
                          : () async {
                              try {
                                await ref.read(coupleRepoProvider).setMood(me!.uid, m.key);
                              } catch (e) {
                                showError(context, e);
                              }
                            },
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentSoft : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.accent : AppColors.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, size: 26, color: selected ? AppColors.accent : AppColors.ink),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.accent : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ question + note
class _QuestionCard extends ConsumerWidget {
  const _QuestionCard({required this.partner});
  final AppUser? partner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(dailyQuestionProvider);
    final iAnswered = ref.watch(iAnsweredProvider);
    final partnerAnswered = ref.watch(partnerAnsweredProvider);
    final name = partner?.name ?? 'Your partner';

    final hint = iAnswered && partnerAnswered
        ? 'You both answered.'
        : iAnswered
            ? 'Waiting for $name.'
            : partnerAnswered
                ? '$name has answered.\nYours unlocks theirs.'
                : '$name has not answered yet.';

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel("Today's question", color: Color(0xFF9B2C4F)),
          const SizedBox(height: 10),
          Text(question,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25)),
          const SizedBox(height: 18),
          Row(
            children: [
              FilledButton(
                onPressed: () =>
                    iAnswered ? context.go('/together') : showAnswerSheet(context),
                child: Text(iAnswered ? 'See answers' : 'Write your answer'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  hint,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends ConsumerWidget {
  const _NoteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(dailyNoteProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('A note for today', color: Color(0xFF9B2C4F)),
          const SizedBox(height: 8),
          Text(note, style: const TextStyle(fontSize: 18, height: 1.35)),
        ],
      ),
    );
  }
}
