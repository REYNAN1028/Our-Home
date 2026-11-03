import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/setup_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/home/home_screen.dart';
import '../features/letters/letter_screen.dart';
import '../features/letters/letters_screen.dart';
import '../features/letters/write_letter_screen.dart';
import '../features/memories/add_memory_screen.dart';
import '../features/memories/memories_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/together/together_screen.dart';
import '../providers.dart';
import '../widgets/common.dart';

const _authPaths = {'/login', '/register'};

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const Scaffold(body: LoadingView())),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const SetupScreen()),

      // Screens that cover the bottom navigation.
      GoRoute(path: '/write-letter', builder: (_, __) => const WriteLetterScreen()),
      GoRoute(
        path: '/letter/:id',
        builder: (_, state) => LetterScreen(letterId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/add-memory', builder: (_, __) => const AddMemoryScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),

      // The five tabs from the design.
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/letters', builder: (_, __) => const LettersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/memories', builder: (_, __) => const MemoriesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/together', builder: (_, __) => const TogetherScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
          ]),
        ],
      ),
    ],
  );
});

/// Re-runs the redirect whenever the sign-in state or the couple changes.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(
      currentUserProvider.select((v) => (v.isLoading, v.valueOrNull?.coupleId, v.valueOrNull == null)),
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;
    final auth = _ref.read(authStateProvider);

    if (auth.isLoading) return loc == '/splash' ? null : '/splash';

    final signedIn = auth.valueOrNull != null;
    if (!signedIn) {
      return _authPaths.contains(loc) ? null : '/login';
    }

    // Signed in: wait for the profile document.
    final user = _ref.read(currentUserProvider);
    if (user.isLoading || user.valueOrNull == null) {
      return loc == '/splash' ? null : '/splash';
    }

    final hasCouple = user.valueOrNull!.coupleId != null;
    if (!hasCouple) return loc == '/setup' ? null : '/setup';

    if (loc == '/splash' || loc == '/setup' || _authPaths.contains(loc)) return '/home';
    return null;
  }
}
