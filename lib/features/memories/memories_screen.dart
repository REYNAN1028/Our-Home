import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class MemoriesScreen extends ConsumerStatefulWidget {
  const MemoriesScreen({super.key});

  @override
  ConsumerState<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends ConsumerState<MemoriesScreen> {
  bool _savedOnly = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(memoriesProvider);
    final all = async.valueOrNull ?? const <Memory>[];
    final memories = _savedOnly ? all.where((m) => m.saved).toList() : all;
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();

    // Group by month, newest first (the stream is already sorted by date desc).
    final groups = <String, List<Memory>>{};
    for (final m in memories) {
      groups.putIfAbsent(DateFormat('MMMM yyyy').format(m.date).toUpperCase(), () => []).add(m);
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          ScreenHeader(
            title: 'Our Memories',
            subtitle: 'Newest first',
            trailing: FilledButton.icon(
              onPressed: () => context.push('/add-memory'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add'),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _FilterChip(
                label: 'All',
                selected: !_savedOnly,
                onTap: () => setState(() => _savedOnly = false),
              ),
              const SizedBox(width: 10),
              _FilterChip(
                label: 'Saved moments',
                selected: _savedOnly,
                onTap: () => setState(() => _savedOnly = true),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (async.isLoading && all.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 80), child: LoadingView())
          else if (memories.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: EmptyState(
                icon: Icons.photo_library_outlined,
                title: _savedOnly ? 'No saved moments yet' : 'No memories yet',
                message: _savedOnly
                    ? 'Tap the star on a memory to keep it here.'
                    : 'Add the first photo from a call, a trip or a quiet day.',
              ),
            )
          else
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 4),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.muted,
                  ),
                ),
              ),
              _MonthGrid(memories: entry.value, now: now),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.ink : AppColors.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// A month with one memory shows it large; otherwise two per row.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.memories, required this.now});
  final List<Memory> memories;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (memories.length == 1) {
      return _MemoryCard(memory: memories.first, now: now, large: true, tintIndex: 0);
    }
    final rows = <Widget>[];
    for (var i = 0; i < memories.length; i += 2) {
      final a = memories[i];
      final b = i + 1 < memories.length ? memories[i + 1] : null;
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: i + 2 < memories.length ? 12 : 0),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _MemoryCard(memory: a, now: now, large: false, tintIndex: i)),
              const SizedBox(width: 12),
              Expanded(
                child: b == null
                    ? const SizedBox.shrink()
                    : _MemoryCard(memory: b, now: now, large: false, tintIndex: i + 1),
              ),
            ],
          ),
        ),
      ));
    }
    return Column(children: rows);
  }
}

class _MemoryCard extends ConsumerWidget {
  const _MemoryCard({
    required this.memory,
    required this.now,
    required this.large,
    required this.tintIndex,
  });
  final Memory memory;
  final DateTime now;
  final bool large;
  final int tintIndex;

  static const _tints = [AppColors.lavender, AppColors.periwinkle, AppColors.accentSoft];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(uidProvider);
    final partner = ref.watch(partnerProvider).valueOrNull;
    final tint = _tints[tintIndex % _tints.length];

    final addedByName = memory.addedBy == uid ? 'you' : (partner?.name ?? 'your partner');
    final dateText = shortDate(memory.date, now);
    final caption = large ? '$dateText · added by $addedByName' : dateText;

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: () => _openDetail(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: large ? 172 : 112,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (memory.photoUrl != null)
                    NetImage(memory.photoUrl!)
                  else
                    ColoredBox(
                      color: tint,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image_outlined, color: AppColors.muted, size: 30),
                          if (large) ...[
                            const SizedBox(height: 8),
                            Text(memory.title,
                                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => _toggleSaved(context, ref),
                      child: Container(
                        width: large ? 44 : 34,
                        height: large ? 44 : 34,
                        decoration: BoxDecoration(
                          color: memory.saved || large ? Colors.white : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          memory.saved ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: large ? 24 : 22,
                          color: memory.saved ? AppColors.accent : AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(large ? 18 : 14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: large ? 19 : 16,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(caption, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSaved(BuildContext context, WidgetRef ref) async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId == null) return;
    try {
      await ref.read(memoryRepoProvider).setSaved(coupleId, memory.id, !memory.saved);
    } catch (e) {
      showError(context, e);
    }
  }

  void _openDetail(BuildContext context, WidgetRef ref) {
    final uid = ref.read(uidProvider);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (memory.photoUrl != null)
                GestureDetector(
                  onTap: () => showFullImage(context, memory.photoUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(aspectRatio: 4 / 3, child: NetImage(memory.photoUrl!)),
                  ),
                ),
              const SizedBox(height: 14),
              Text(memory.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(DateFormat('EEEE d MMMM yyyy').format(memory.date),
                  style: const TextStyle(color: AppColors.muted)),
              if (memory.addedBy == uid) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final coupleId = ref.read(coupleIdProvider);
                    Navigator.of(sheetContext).pop();
                    if (coupleId == null) return;
                    try {
                      await ref.read(memoryRepoProvider).delete(coupleId, memory);
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete memory'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
