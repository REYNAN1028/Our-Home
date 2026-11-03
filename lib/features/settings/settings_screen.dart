import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  final _status = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    _status.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final uid = ref.read(uidProvider);
    if (uid == null || _name.text.trim().isEmpty) return;
    try {
      await ref.read(coupleRepoProvider).updateName(uid, _name.text);
      showInfo(context, 'Name updated.');
    } catch (e) {
      showError(context, e);
    }
  }

  Future<void> _saveStatus() async {
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    try {
      await ref.read(coupleRepoProvider).setStatus(uid, _status.text);
      showInfo(context, 'Status updated. ${ref.read(partnerProvider).valueOrNull?.name ?? 'Your partner'} can see it on their home screen.');
    } catch (e) {
      showError(context, e);
    }
  }

  Future<void> _pickStart() async {
    final couple = ref.read(coupleProvider).valueOrNull;
    if (couple == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: couple.startDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      helpText: 'The day you got together',
    );
    if (picked == null) return;
    try {
      await ref.read(coupleRepoProvider).updateStartDate(couple.id, picked);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authRepoProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final couple = ref.watch(coupleProvider).valueOrNull;

    if (me != null && !_loaded) {
      _loaded = true;
      _name.text = me.name;
      _status.text = me.status ?? '';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SectionLabel('You'),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveName(),
                  decoration: InputDecoration(
                    labelText: 'Your name',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_rounded),
                      onPressed: _saveName,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _status,
                  maxLength: 40,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveStatus(),
                  decoration: InputDecoration(
                    labelText: 'What are you up to?',
                    hintText: 'e.g. Cooking dinner',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_rounded),
                      onPressed: _saveStatus,
                    ),
                  ),
                ),
                if (me != null)
                  Text(me.email, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Us'),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.favorite_border, color: AppColors.accent),
                  title: const Text('Together since'),
                  subtitle: Text(couple == null
                      ? ''
                      : DateFormat('d MMMM yyyy').format(couple.startDate)),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: _pickStart,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.key_outlined, color: AppColors.accent),
                  title: const Text('Invite code'),
                  subtitle: Text(couple?.inviteCode ?? ''),
                  trailing: const Icon(Icons.copy_rounded, size: 18),
                  onTap: couple == null
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: couple.inviteCode));
                          showInfo(context, 'Invite code copied.');
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
