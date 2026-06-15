import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/minecraft_version.dart';
import '../../../domain/entities/profile.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_header.dart';

class VersionsPage extends ConsumerStatefulWidget {
  const VersionsPage({super.key});

  @override
  ConsumerState<VersionsPage> createState() => _VersionsPageState();
}

class _VersionsPageState extends ConsumerState<VersionsPage> {
  // All four release types on by default — the manifest contains every version
  // Mojang has ever published; we show them all unless the user narrows.
  final Set<MinecraftReleaseType> _filter = {
    MinecraftReleaseType.release,
    MinecraftReleaseType.snapshot,
    MinecraftReleaseType.oldBeta,
    MinecraftReleaseType.oldAlpha,
  };
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final versions = ref.watch(versionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Versions')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search versions…',
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            _chip(MinecraftReleaseType.release, 'Release', AppTheme.accent),
            const SizedBox(width: 8),
            _chip(MinecraftReleaseType.snapshot, 'Snapshot', AppTheme.accent2),
            const SizedBox(width: 8),
            _chip(MinecraftReleaseType.oldBeta, 'Beta', AppTheme.warn),
            const SizedBox(width: 8),
            _chip(MinecraftReleaseType.oldAlpha, 'Alpha', AppTheme.danger),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: versions.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('$e', textAlign: TextAlign.center))),
            data: (list) {
              final filtered = list
                  .where((v) => _filter.contains(v.type))
                  .where((v) => _query.isEmpty || v.id.toLowerCase().contains(_query))
                  .toList();
              if (filtered.isEmpty) {
                return const Center(child: Text('No versions match.',
                    style: TextStyle(color: AppTheme.textLo)));
              }
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  child: Row(children: [
                    Text('${filtered.length} of ${list.length} versions',
                        style: const TextStyle(color: AppTheme.textLo, fontSize: 12)),
                    const Spacer(),
                    Text('newest first',
                        style: const TextStyle(color: AppTheme.textLo, fontSize: 12)),
                  ]),
                ),
                Expanded(child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _versionTile(filtered[i]),
                )),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  Widget _chip(MinecraftReleaseType t, String label, Color color) {
    final on = _filter.contains(t);
    return FilterChip(
      label: Text(label),
      selected: on,
      selectedColor: color.withOpacity(0.22),
      checkmarkColor: color,
      onSelected: (s) => setState(() {
        s ? _filter.add(t) : _filter.remove(t);
      }),
    );
  }

  Color _colorFor(MinecraftReleaseType t) => switch (t) {
        MinecraftReleaseType.release => AppTheme.accent,
        MinecraftReleaseType.snapshot => AppTheme.accent2,
        MinecraftReleaseType.oldBeta => AppTheme.warn,
        MinecraftReleaseType.oldAlpha => AppTheme.danger,
      };

  Widget _versionTile(MinecraftVersion v) {
    final color = _colorFor(v.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: AppTheme.bgPanel,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _createProfileFor(v),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.stroke),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Container(
                width: 6, height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.id, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text('${v.type.name} • ${v.releaseTime.toIso8601String().substring(0, 10)}',
                    style: const TextStyle(color: AppTheme.textMid, fontSize: 12)),
              ])),
              const Icon(Icons.add_rounded, color: AppTheme.accent),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _createProfileFor(MinecraftVersion v) async {
    final profile = Profile(
      id: 'p${DateTime.now().millisecondsSinceEpoch}',
      name: 'Minecraft ${v.id}',
      versionId: v.id,
      maxRamMb: 2048,
      created: DateTime.now(),
    );
    await ref.read(profileRepoProvider).save(profile);
    ref.read(activeProfileProvider.notifier).state = profile;
    ref.invalidate(profilesProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created profile for ${v.id}')),
      );
    }
  }
}
