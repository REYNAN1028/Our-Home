import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import 'answer_sheet.dart';

class TogetherScreen extends ConsumerWidget {
  const TogetherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          ScreenHeader(
            title: 'Together',
            subtitle: 'Small things, every day',
            trailing: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Pill(streak > 0 ? '$streak-day streak' : 'Start a streak'),
            ),
          ),
          const SizedBox(height: 16),
          const _QuestionSection(),
          const SizedBox(height: 14),
          const _TodoSection(),
          const SizedBox(height: 14),
          const _GoalBanner(),
        ],
      ),
    );
  }
}

// ------------------------------------------------------- daily question card
class _QuestionSection extends ConsumerWidget {
  const _QuestionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = ref.watch(dailyQuestionProvider);
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partner = ref.watch(partnerProvider).valueOrNull;
    final iAnswered = ref.watch(iAnsweredProvider);
    final partnerAnswered = ref.watch(partnerAnsweredProvider);
    final myText = ref.watch(myAnswerProvider).valueOrNull;
    final partnerText = ref.watch(partnerAnswerProvider).valueOrNull;
    final partnerName = partner?.name ?? 'Your partner';

    final status = iAnswered && partnerAnswered
        ? 'both answered'
        : iAnswered
            ? 'waiting for $partnerName'
            : 'your turn';

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel("Today's question · $status", color: const Color(0xFF9B2C4F)),
          const SizedBox(height: 10),
          Text(question,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25)),
          const SizedBox(height: 16),
          if (iAnswered)
            _AnswerRow(
              avatar: MeAvatar(me?.initial ?? 'M'),
              text: myText ?? '...',
              background: AppColors.accentSoft,
            )
          else
            FilledButton(
              onPressed: () => showAnswerSheet(context),
              child: const Text('Write your answer'),
            ),
          const SizedBox(height: 10),
          if (iAnswered && partnerAnswered)
            _AnswerRow(
              avatar: PartnerAvatar(partner?.initial ?? 'J'),
              text: partnerText ?? '...',
              background: AppColors.periwinkle,
            )
          else
            _LockedRow(
              avatar: PartnerAvatar(partner?.initial ?? '?'),
              text: partnerAnswered
                  ? '$partnerName has answered. Share yours to unlock it.'
                  : iAnswered
                      ? 'Waiting for $partnerName to answer.'
                      : '$partnerName has not answered yet.',
              locked: partnerAnswered,
            ),
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.avatar, required this.text, required this.background});
  final Widget avatar;
  final String text;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        avatar,
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(text, style: const TextStyle(fontSize: 16, height: 1.3)),
          ),
        ),
      ],
    );
  }
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({required this.avatar, required this.text, required this.locked});
  final Widget avatar;
  final String text;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        avatar,
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.lavenderSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(locked ? Icons.lock_outline : Icons.hourglass_empty,
                    size: 16, color: AppColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text, style: const TextStyle(color: AppColors.muted, height: 1.3)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- to-do list
class _TodoSection extends ConsumerStatefulWidget {
  const _TodoSection();

  @override
  ConsumerState<_TodoSection> createState() => _TodoSectionState();
}

class _TodoSectionState extends ConsumerState<_TodoSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    final uid = ref.read(uidProvider);
    final coupleId = ref.read(coupleIdProvider);
    if (text.isEmpty || uid == null || coupleId == null) return;
    _controller.clear();
    try {
      await ref.read(togetherRepoProvider).addTodo(coupleId, uid, text);
    } catch (e) {
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todosProvider).valueOrNull ?? const <TodoItem>[];
    final coupleId = ref.watch(coupleIdProvider);
    final done = todos.where((t) => t.done).length;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Things to do together',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Text('$done of ${todos.length} done',
                  style: const TextStyle(color: AppColors.muted, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          for (final t in todos)
            Dismissible(
              key: ValueKey(t.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 8),
                child: const Icon(Icons.delete_outline, color: AppColors.accent),
              ),
              onDismissed: (_) {
                if (coupleId != null) {
                  ref.read(togetherRepoProvider).deleteTodo(coupleId, t.id);
                }
              },
              child: InkWell(
                onTap: coupleId == null
                    ? null
                    : () => ref
                        .read(togetherRepoProvider)
                        .setTodoDone(coupleId, t.id, !t.done)
                        .catchError((Object e) => showError(context, e)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      _CheckBox(checked: t.done),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          t.text,
                          style: TextStyle(
                            fontSize: 17,
                            color: t.done ? AppColors.muted : AppColors.ink,
                            decoration: t.done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              hintText: 'Add something to do together',
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.accent),
                onPressed: _add,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: checked ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: checked ? AppColors.accent : AppColors.muted, width: 1.5),
      ),
      child: checked ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
    );
  }
}

// ---------------------------------------------------------------------- goals
class _GoalBanner extends ConsumerWidget {
  const _GoalBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider).valueOrNull ?? const <Goal>[];
    final reached = goals.where((g) => g.reached).toList()
      ..sort((a, b) => b.reachedAt!.compareTo(a.reachedAt!));
    final latest = reached.isEmpty ? null : reached.first;

    if (latest == null) {
      return DashedBox(
        onTap: () => _showGoals(context),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.flag_outlined, color: AppColors.muted),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  goals.isEmpty
                      ? 'Set a goal for the two of you'
                      : '${goals.length} goal${goals.length == 1 ? '' : 's'} to reach together',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      );
    }

    return Material(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showGoals(context),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: AppColors.accentLight, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: AppColors.ink, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GOAL REACHED',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentLight,
                        )),
                    const SizedBox(height: 3),
                    Text(latest.title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGoals(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const _GoalsSheet(),
    );
  }
}

class _GoalsSheet extends ConsumerStatefulWidget {
  const _GoalsSheet();

  @override
  ConsumerState<_GoalsSheet> createState() => _GoalsSheetState();
}

class _GoalsSheetState extends ConsumerState<_GoalsSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    final uid = ref.read(uidProvider);
    final coupleId = ref.read(coupleIdProvider);
    if (text.isEmpty || uid == null || coupleId == null) return;
    _controller.clear();
    try {
      await ref.read(togetherRepoProvider).addGoal(coupleId, uid, text);
    } catch (e) {
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider).valueOrNull ?? const <Goal>[];
    final coupleId = ref.watch(coupleIdProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Our goals',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Tap a goal when you have reached it together.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final g in goals)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _CheckBox(checked: g.reached),
                      title: Text(
                        g.title,
                        style: TextStyle(
                          fontSize: 17,
                          color: g.reached ? AppColors.muted : AppColors.ink,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                        onPressed: coupleId == null
                            ? null
                            : () => ref.read(togetherRepoProvider).deleteGoal(coupleId, g.id),
                      ),
                      onTap: coupleId == null
                          ? null
                          : () => ref
                              .read(togetherRepoProvider)
                              .setGoalReached(coupleId, g.id, !g.reached),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _add(),
              decoration: InputDecoration(
                hintText: 'e.g. Rooftop dinner in the same city',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.accent),
                  onPressed: _add,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
