import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/messaging_service.dart';
import '../../models/models.dart';
import '../../providers.dart';

/// Bottom navigation + background duties that must run while the app is open:
/// presence heartbeat, push registration and chat delivery receipts.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _heartbeat();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _heartbeat());
    final uid = ref.read(uidProvider);
    if (uid != null) MessagingService.init(uid);
    _syncTab();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTab();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _heartbeat();
  }

  void _syncTab() {
    Future.microtask(() {
      if (mounted) ref.read(tabIndexProvider.notifier).state = widget.shell.currentIndex;
    });
  }

  void _heartbeat() {
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    unawaited(ref.read(coupleRepoProvider).heartbeat(uid).catchError((_) {}));
  }

  /// Anything my partner sent that reached this device counts as delivered.
  void _markDelivered(List<ChatMessage> msgs) {
    final uid = ref.read(uidProvider);
    final coupleId = ref.read(coupleIdProvider);
    if (uid == null || coupleId == null) return;
    final ids = msgs
        .where((m) => m.fromUid != uid && m.deliveredAt == null && m.readAt == null)
        .map((m) => m.id)
        .toList();
    if (ids.isNotEmpty) {
      unawaited(ref.read(chatRepoProvider).markDelivered(coupleId, ids).catchError((_) {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<ChatMessage>>>(
      messagesProvider,
      (_, next) => next.whenData(_markDelivered),
    );

    final unreadChat = ref.watch(unreadMessagesProvider);
    final unreadLetters = ref.watch(unreadLettersProvider);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: keyboardOpen
          ? null
          : NavigationBar(
              selectedIndex: widget.shell.currentIndex,
              onDestinationSelected: (i) => widget.shell.goBranch(
                i,
                initialLocation: i == widget.shell.currentIndex,
              ),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_outlined),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: unreadLetters > 0,
                    label: Text('$unreadLetters'),
                    child: const Icon(Icons.mail_outline),
                  ),
                  label: 'Letters',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.image_outlined),
                  label: 'Memories',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.favorite_border),
                  label: 'Together',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: unreadChat > 0,
                    label: Text('$unreadChat'),
                    child: const Icon(Icons.chat_bubble_outline),
                  ),
                  label: 'Chat',
                ),
              ],
            ),
    );
  }
}
