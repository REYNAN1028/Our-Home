import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

const _chatTab = 4;

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _marking = <String>{};
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Marks partner messages as read, but only while this tab is on screen.
  void _markRead(List<ChatMessage> msgs) {
    final uid = ref.read(uidProvider);
    final coupleId = ref.read(coupleIdProvider);
    if (uid == null || coupleId == null) return;
    final ids = msgs
        .where((m) => m.fromUid != uid && m.readAt == null && !_marking.contains(m.id))
        .map((m) => m.id)
        .toList();
    if (ids.isEmpty) return;
    _marking.addAll(ids);
    ref.read(chatRepoProvider).markRead(coupleId, ids).catchError((_) {
      _marking.removeAll(ids);
    });
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    final uid = ref.read(uidProvider);
    final coupleId = ref.read(coupleIdProvider);
    if (text.isEmpty || uid == null || coupleId == null) return;
    _controller.clear();
    try {
      await ref.read(chatRepoProvider).sendText(coupleId, uid, text);
    } catch (e) {
      _controller.text = text;
      showError(context, e);
    }
  }

  Future<void> _sendImage() async {
    final uid = ref.read(uidProvider);
    final coupleId = ref.read(coupleIdProvider);
    if (uid == null || coupleId == null) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (file == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(chatRepoProvider).sendImage(coupleId, uid, file);
    } catch (e) {
      showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(uidProvider);
    final partner = ref.watch(partnerProvider).valueOrNull;
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final async = ref.watch(messagesProvider);
    final msgs = async.valueOrNull ?? const <ChatMessage>[];
    final onChatTab = ref.watch(tabIndexProvider) == _chatTab;

    if (onChatTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markRead(msgs);
      });
    }

    final partnerName = partner?.name ?? 'your partner';
    final online = partner?.isOnline(now) ?? false;

    return Column(
      children: [
        // ---- header
        Material(
          color: Colors.white,
          elevation: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  Avatar(partner?.initial ?? '?', size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(partner?.name ?? 'Your partner',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: online ? AppColors.online : AppColors.muted,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              online
                                  ? 'Online now'
                                  : lastSeenLabel(partner?.lastSeen, now).replaceFirstMapped(
                                      RegExp(r'^.'), (m) => m[0]!.toUpperCase()),
                              style: const TextStyle(color: AppColors.muted, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ---- messages
        Expanded(
          child: Container(
            color: AppColors.bg,
            child: async.isLoading && msgs.isEmpty
                ? const LoadingView()
                : msgs.isEmpty
                    ? EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'Say hi to $partnerName',
                        message: 'Your messages and photos are private to the two of you.',
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: msgs.length,
                        itemBuilder: (_, i) {
                          final m = msgs[i];
                          // Oldest message of a day (next item in a reversed list
                          // is older) gets the date label above it.
                          final showDay = i == msgs.length - 1 ||
                              !sameDay(msgs[i + 1].createdAt, m.createdAt);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showDay)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: Center(
                                    child: Text(
                                      chatDayLabel(m.createdAt, now),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.1,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                                ),
                              _Bubble(message: m, mine: m.fromUid == uid),
                            ],
                          );
                        },
                      ),
          ),
        ),

        // ---- composer
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              _sending
                  ? const SizedBox(
                      width: 48,
                      height: 48,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
                      ),
                    )
                  : RoundIconButton(icon: Icons.image_outlined, onPressed: _sendImage),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendText(),
                  decoration: InputDecoration(
                    hintText: 'Message $partnerName',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: AppColors.accent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sendText,
                  child: const SizedBox(
                    width: 50,
                    height: 50,
                    child: Icon(Icons.arrow_upward_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final hasImage = message.imageUrl != null;

    final Widget content = hasImage
        ? GestureDetector(
            onTap: () => showFullImage(context, message.imageUrl!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: maxWidth * 0.85,
                height: maxWidth * 0.85,
                child: NetImage(message.imageUrl!),
              ),
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: mine ? AppColors.accent : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: mine ? null : Border.all(color: AppColors.line),
            ),
            child: Text(
              message.text ?? '',
              style: TextStyle(
                fontSize: 16.5,
                height: 1.3,
                color: mine ? Colors.white : AppColors.ink,
              ),
            ),
          );

    final time = clockTime(message.createdAt);
    final Widget meta;
    if (mine) {
      final read = message.readAt != null;
      final delivered = message.deliveredAt != null;
      meta = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$time · ${read ? 'Read' : delivered ? 'Delivered' : 'Sent'} ',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          Icon(
            read || delivered ? Icons.done_all : Icons.done,
            size: 15,
            color: read ? AppColors.periwinkleInk : AppColors.muted,
          ),
        ],
      );
    } else {
      meta = Text(time, style: const TextStyle(fontSize: 12.5, color: AppColors.muted));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [content, const SizedBox(height: 5), meta],
          ),
        ),
      ),
    );
  }
}
