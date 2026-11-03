import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

/// Shown after sign-up: one partner starts the space, the other joins with a code.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _code = TextEditingController();
  DateTime _since = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _since,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      helpText: 'The day you got together',
    );
    if (picked != null) setState(() => _since = picked);
  }

  Future<void> _create() async {
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(coupleRepoProvider).createCouple(uid: uid, startDate: _since);
    } catch (e) {
      showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    if (_code.text.trim().length < 6) {
      showInfo(context, 'Enter the 6-character code your partner shared.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(coupleRepoProvider).joinCouple(uid: uid, code: _code.text);
    } catch (e) {
      showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepoProvider).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Set up your space',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('One of you starts it. The other joins with a code.',
                      style: TextStyle(fontSize: 16, color: AppColors.muted)),
                  const SizedBox(height: 24),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('Start a space'),
                        const SizedBox(height: 8),
                        const Text('When did you get together?',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_outlined, size: 18),
                          label: Text(DateFormat('d MMMM yyyy').format(_since)),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _busy ? null : _create,
                          child: const Text('Create our space'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You will get a code to send to your partner.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionLabel('Join your partner'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            hintText: 'Invite code',
                            counterText: '',
                          ),
                          style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _busy ? null : _join,
                          child: const Text('Join'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
