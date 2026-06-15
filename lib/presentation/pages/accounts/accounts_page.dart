import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/datasources/auth_datasource.dart';
import '../../../domain/entities/account.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_header.dart';

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final active = ref.watch(activeAccountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const SectionHeader('Add account'),
            Row(children: [
              Expanded(child: _signInTile(
                context, ref,
                icon: Icons.shield_rounded,
                color: AppTheme.accent,
                title: 'Microsoft',
                subtitle: 'Official account — required for online servers',
                onTap: () => _signInMs(context, ref),
              )),
              const SizedBox(width: 10),
              Expanded(child: _signInTile(
                context, ref,
                icon: Icons.person_off_rounded,
                color: AppTheme.warn,
                title: 'Offline',
                subtitle: 'Single-player & private servers only',
                onTap: () => _signInOffline(context, ref),
              )),
            ]),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgPanelHi,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.stroke),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppTheme.accent2, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Offline accounts do NOT bypass online Microsoft auth. '
                    'Public servers (Hypixel, Realms…) will reject the connection. '
                    'Use Offline only for single-player worlds and servers running with online-mode=false.',
                    style: TextStyle(color: AppTheme.textMid, height: 1.4, fontSize: 12.5),
                  ),
                ),
              ]),
            ),
            const SectionHeader('Your accounts'),
            if (list.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.inbox_outlined),
                  title: Text('No accounts yet'),
                  subtitle: Text('Add one above to start playing.'),
                ),
              ),
            for (final a in list) _accountCard(context, ref, a, active?.uuid == a.uuid),
          ],
        ),
      ),
    );
  }

  Widget _signInTile(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.bgPanel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.stroke),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: AppTheme.textMid, fontSize: 12, height: 1.3)),
          ]),
        ),
      ),
    );
  }

  Widget _accountCard(BuildContext context, WidgetRef ref, Account a, bool active) {
    final isOffline = a.refreshToken.isEmpty;
    return Card(
      child: ListTile(
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: (isOffline ? AppTheme.warn : AppTheme.accent).withOpacity(0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(isOffline ? Icons.person_off_rounded : Icons.shield_rounded,
              color: isOffline ? AppTheme.warn : AppTheme.accent),
        ),
        title: Row(children: [
          Flexible(child: Text(a.username, overflow: TextOverflow.ellipsis)),
          if (active) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Active',
                  style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ]),
        subtitle: Text(isOffline ? 'Offline • ${a.uuid.substring(0, 8)}…' : 'Microsoft • ${a.uuid.substring(0, 8)}…',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMid)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!active)
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded),
              tooltip: 'Use this account',
              onPressed: () {
                ref.read(activeAccountProvider.notifier).state = a;
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Using ${a.username}')));
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.danger),
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(accountRepoProvider).signOut(a.uuid);
              if (active) ref.read(activeAccountProvider.notifier).state = null;
              ref.invalidate(accountsProvider);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _signInOffline(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Offline account'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
              'Pick a username (3–16 chars, letters/digits/underscore). '
              'Your offline UUID is derived from the name — same algorithm as a vanilla offline server.',
              style: TextStyle(color: AppTheme.textMid, fontSize: 13, height: 1.35)),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Username', hintText: 'Steve'),
            inputFormatters: [
              LengthLimitingTextInputFormatter(16),
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
            ],
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final acc = await ref.read(accountRepoProvider).addOffline(ctrl.text);
      ref.read(activeAccountProvider.notifier).state = acc;
      ref.invalidate(accountsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Offline account ${acc.username} ready')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _signInMs(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(accountRepoProvider);
    DeviceCodeChallenge challenge;
    try {
      challenge = await repo.beginMicrosoftLogin();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }
    if (!context.mounted) return;
    final cancelled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeviceCodeDialog(challenge: challenge),
    );
    if (cancelled == true) return;
    try {
      final account = await repo.completeMicrosoftLogin(challenge);
      ref.read(activeAccountProvider.notifier).state = account;
      ref.invalidate(accountsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Signed in as ${account.username}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _DeviceCodeDialog extends StatelessWidget {
  final DeviceCodeChallenge challenge;
  const _DeviceCodeDialog({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sign in with Microsoft'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('1. Open the verification page',
            style: TextStyle(color: AppTheme.textMid)),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(challenge.verificationUri),
          onPressed: () => launchUrl(Uri.parse(challenge.verificationUri),
              mode: LaunchMode.externalApplication),
        ),
        const SizedBox(height: 18),
        const Text('2. Enter this code', style: TextStyle(color: AppTheme.textMid)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.bgPanelHi,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
          ),
          child: SelectableText(
            challenge.userCode, textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800,
                letterSpacing: 6, color: AppTheme.accent),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy code'),
          onPressed: () => Clipboard.setData(ClipboardData(text: challenge.userCode)),
        ),
        const SizedBox(height: 8),
        Row(children: const [
          SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Waiting for confirmation…',
              style: TextStyle(color: AppTheme.textMid)),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cancel')),
      ],
    );
  }
}
