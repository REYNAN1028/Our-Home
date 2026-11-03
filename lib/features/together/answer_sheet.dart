import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

Future<void> showAnswerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => const _AnswerSheet(),
  );
}

class _AnswerSheet extends ConsumerStatefulWidget {
  const _AnswerSheet();

  @override
  ConsumerState<_AnswerSheet> createState() => _AnswerSheetState();
}

class _AnswerSheetState extends ConsumerState<_AnswerSheet> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final uid = ref.read(uidProvider);
    final coupleId = ref.read(coupleIdProvider);
    if (uid == null || coupleId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(togetherRepoProvider).submitAnswer(
            coupleId: coupleId,
            uid: uid,
            partnerId: ref.read(partnerIdProvider),
            dateKey: ref.read(todayKeyProvider),
            yesterdayKey: ref.read(yesterdayKeyProvider),
            text: text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      showError(context, e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = ref.watch(dailyQuestionProvider);
    final partner = ref.watch(partnerProvider).valueOrNull;
    final partnerAnswered = ref.watch(partnerAnsweredProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel("Today's question"),
          const SizedBox(height: 8),
          Text(question,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.25)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 280,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Write your answer...'),
          ),
          const SizedBox(height: 4),
          Text(
            partnerAnswered
                ? 'Once you share, you will see ${partner?.name ?? 'their'} answer too.'
                : 'Answers unlock for both of you once you have both answered.',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Share my answer'),
            ),
          ),
        ],
      ),
    );
  }
}
