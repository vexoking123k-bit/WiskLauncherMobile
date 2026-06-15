import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/profile.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_header.dart';

class ProfilesPage extends ConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final active = ref.watch(activeProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New profile', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _create(context, ref),
      ),
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return _empty(context, ref);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              const SectionHeader('Your profiles'),
              for (final p in list) _profileCard(context, ref, p, active?.id == p.id),
            ],
          );
        },
      ),
    );
  }

  Widget _profileCard(BuildContext context, WidgetRef ref, Profile p, bool active) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ref.read(activeProfileProvider.notifier).state = p;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Using ${p.name}')));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: AppTheme.accent2.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.folder_special_rounded, color: AppTheme.accent2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(p.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis)),
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
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _chip(p.versionId, AppTheme.accent2),
                _chip('${p.maxRamMb} MB', AppTheme.warn),
                if (p.javaRuntimeId != null) _chip(p.javaRuntimeId!, AppTheme.accent),
              ]),
            ])),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
              onPressed: () async {
                await ref.read(profileRepoProvider).delete(p.id);
                if (active) ref.read(activeProfileProvider.notifier).state = null;
                ref.invalidate(profilesProvider);
              },
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.16),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );

  Widget _empty(BuildContext context, WidgetRef ref) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.folder_open_rounded, size: 64, color: AppTheme.textLo),
            const SizedBox(height: 14),
            const Text('No profiles yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Create one to pair an account with a Minecraft version.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMid)),
            const SizedBox(height: 22),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('New profile'),
              onPressed: () => _create(context, ref),
            ),
          ]),
        ),
      );

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController(text: 'My profile');
    final versionCtrl = TextEditingController(text: '1.21.4');
    double ram = 2048;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
        title: const Text('New profile'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: versionCtrl, decoration: const InputDecoration(
                labelText: 'Minecraft version', hintText: 'e.g. 1.21.4')),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Text('RAM: ${ram.round()} MB',
                style: const TextStyle(color: AppTheme.textMid))),
            Slider(value: ram, min: 512, max: 8192, divisions: 30,
                onChanged: (v) => setLocal(() => ram = v)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      )),
    );
    if (ok != true) return;
    final profile = Profile(
      id: 'p${DateTime.now().millisecondsSinceEpoch}',
      name: nameCtrl.text.trim().isEmpty ? 'Profile' : nameCtrl.text.trim(),
      versionId: versionCtrl.text.trim(),
      maxRamMb: ram.round(),
      created: DateTime.now(),
    );
    await ref.read(profileRepoProvider).save(profile);
    ref.read(activeProfileProvider.notifier).state = profile;
    ref.invalidate(profilesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created ${profile.name}')));
    }
  }
}
