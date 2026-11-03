import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class WriteLetterScreen extends ConsumerStatefulWidget {
  const WriteLetterScreen({super.key});

  @override
  ConsumerState<WriteLetterScreen> createState() => _WriteLetterScreenState();
}

class _WriteLetterScreenState extends ConsumerState<WriteLetterScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _sealNote = TextEditingController();
  final _photos = <XFile>[];
  DateTime? _openAt; // null = deliver now
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _sealNote.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final picked = await ImagePicker().pickMultiImage(maxWidth: 1800, imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() {
      _photos.addAll(picked);
      if (_photos.length > 6) _photos.removeRange(6, _photos.length);
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _openAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: 'When should it open?',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (time == null) return;
    setState(() => _openAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _useMilestone() {
    final couple = ref.read(coupleProvider).valueOrNull;
    if (couple == null) return;
    final stats = RelationshipStats.compute(couple.startDate, DateTime.now());
    final m = stats.nextMonth;
    setState(() {
      _openAt = DateTime(m.date.year, m.date.month, m.date.day, 8);
      _sealNote.text = 'Saved for your ${m.label.replaceAll(' ', '-').replaceAll('months', 'month').replaceAll('years', 'year')} day.';
    });
  }

  Future<void> _send() async {
    final partnerId = ref.read(partnerIdProvider);
    final uid = ref.read(uidProvider);
    final coupleId = ref.read(coupleIdProvider);
    if (partnerId == null || uid == null || coupleId == null) return;

    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      showInfo(context, 'Give your letter a title and write something inside.');
      return;
    }
    if (_openAt != null && !_openAt!.isAfter(DateTime.now())) {
      showInfo(context, 'Pick a time in the future, or deliver it now.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(letterRepoProvider).send(
            coupleId: coupleId,
            fromUid: uid,
            toUid: partnerId,
            title: _title.text,
            body: _body.text,
            photos: _photos,
            openAt: _openAt,
            sealNote: _sealNote.text,
          );
      if (!mounted) return;
      showInfo(context, _openAt == null ? 'Letter sent.' : 'Letter sealed and scheduled.');
      context.pop();
    } catch (e) {
      showError(context, e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final partner = ref.watch(partnerProvider).valueOrNull;
    final scheduled = _openAt != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Letter to ${partner?.name ?? ''}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _busy ? null : _send,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(scheduled ? 'Seal' : 'Send'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(hintText: 'Title, e.g. "For when you miss me"'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 10,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 17, height: 1.5),
            decoration: const InputDecoration(hintText: 'Write whatever you would say if they were here...'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (_photos.length < 6)
                  InkWell(
                    onTap: _addPhotos,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 84,
                      decoration: BoxDecoration(
                        color: AppColors.lavender,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.muted),
                    ),
                  ),
                for (var i = 0; i < _photos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(width: 84, height: 84, child: PickedImage(_photos[i])),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _photos.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Delivery'),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Deliver now')),
              ButtonSegment(value: true, label: Text('Seal for later')),
            ],
            selected: {scheduled},
            onSelectionChanged: (s) {
              if (s.first) {
                _pickDateTime();
              } else {
                setState(() => _openAt = null);
              }
            },
          ),
          if (scheduled) ...[
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.all(16),
              onTap: _pickDateTime,
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_outlined, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Opens ${DateFormat('EEE d MMM yyyy, h:mm a').format(_openAt!)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Use our next monthly anniversary'),
                onPressed: _useMilestone,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sealNote,
              maxLength: 80,
              decoration: const InputDecoration(
                hintText: 'A hint on the envelope, e.g. "Saved for your 14-month day"',
              ),
            ),
            const Text(
              'The letter text stays locked, even on the server, until it opens.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
