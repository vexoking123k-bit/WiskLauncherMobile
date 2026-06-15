import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/paths.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  double _ramMb = 1024;
  int? _width;
  int? _height;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader('Game'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Max RAM: ${_ramMb.round()} MB'),
                Slider(
                  value: _ramMb, min: 512, max: 8192, divisions: 30,
                  onChanged: (v) => setState(() => _ramMb = v),
                  onChangeEnd: (v) async {
                    if (profile != null) {
                      final updated = profile.copyWith(maxRamMb: v.round());
                      await ref.read(profileRepoProvider).save(updated);
                      ref.read(activeProfileProvider.notifier).state = updated;
                      ref.invalidate(profilesProvider);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(
                    decoration: const InputDecoration(labelText: 'Width'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _width = int.tryParse(v),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(
                    decoration: const InputDecoration(labelText: 'Height'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _height = int.tryParse(v),
                  )),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader('Renderer (placeholder)'),
          Card(
            child: ListTile(
              title: const Text('Renderer backend'),
              subtitle: const Text('GL4ES (planned) — see ROADMAP.md',
                  style: TextStyle(color: AppTheme.textLo)),
              trailing: const Text('Default'),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader('Storage'),
          Card(
            child: Column(children: [
              ListTile(
                title: const Text('Game directory'),
                subtitle: Text(LauncherPaths.instance.root.path),
              ),
              ListTile(
                title: const Text('Clear cache'),
                subtitle: const Text('Removes cached manifests and partial downloads. Profiles and game saves are kept.'),
                trailing: const Icon(Icons.delete_sweep_outlined),
                onTap: _clearCache,
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    // Cached manifests
    final manifestCache = LauncherPaths.instance.configs.listSync();
    for (final f in manifestCache) {
      if (f.path.endsWith('version_manifest_v2.json')) await f.delete();
    }
    // Partial downloads
    await for (final ent
        in LauncherPaths.instance.root.list(recursive: true)) {
      if (ent.path.endsWith('.part')) {
        try { await (ent as dynamic).delete(); } catch (_) {}
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared')));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(color: AppTheme.textLo, letterSpacing: 1.5, fontSize: 12)),
      );
}
