import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/services/mod_loader_installer.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_header.dart';

class ModsPage extends ConsumerStatefulWidget {
  const ModsPage({super.key});

  @override
  ConsumerState<ModsPage> createState() => _ModsPageState();
}

class _ModsPageState extends ConsumerState<ModsPage> {
  bool _installing = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mods & loaders')),
        body: _empty('Pick a profile first.'),
      );
    }
    final svc = ref.watch(modFolderServiceProvider);
    final loaders = ref.watch(allLoadersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(profile.name)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        const SectionHeader('Mod loader'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgPanel,
            border: Border.all(color: AppTheme.stroke),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Current version', style: TextStyle(color: AppTheme.textLo, fontSize: 12)),
            const SizedBox(height: 2),
            Text(profile.versionId,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (_statusMessage != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                if (_installing)
                  const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                if (_installing) const SizedBox(width: 10),
                Expanded(child: Text(_statusMessage!,
                    style: const TextStyle(color: AppTheme.textMid, fontSize: 13))),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        for (final loader in loaders)
          _loaderTile(context, loader, profile.versionId),

        const SectionHeader('Installed .jar mods'),
        FutureBuilder(
          future: svc.list(profile.id),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Padding(padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()));
            }
            final files = snap.data!;
            if (files.isEmpty) {
              return Card(child: ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('No mods yet'),
                subtitle: Text(
                    'Drop .jar files into:\n${svc.modsDirFor(profile.id).path}',
                    style: const TextStyle(color: AppTheme.textMid, fontSize: 12)),
              ));
            }
            return Column(children: [
              for (final f in files) Card(child: ListTile(
                leading: const Icon(Icons.extension_rounded),
                title: Text(f.uri.pathSegments.last),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                  onPressed: () async {
                    await svc.remove(profile.id, f.uri.pathSegments.last);
                    if (mounted) setState(() {});
                  },
                ),
              )),
            ]);
          },
        ),
      ]),
    );
  }

  Widget _loaderTile(BuildContext context, ModLoaderInstaller loader, String mc) {
    final color = _colorFor(loader.displayName);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: AppTheme.bgPanel,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _installing ? null : () => _pickAndInstall(context, loader, mc),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconFor(loader.displayName), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(loader.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(_descFor(loader.displayName),
                    style: const TextStyle(color: AppTheme.textMid, fontSize: 12, height: 1.3)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textLo),
            ]),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String name) => switch (name) {
        'Fabric'   => Icons.bolt_rounded,
        'Quilt'    => Icons.layers_rounded,
        'Forge'    => Icons.construction_rounded,
        'NeoForge' => Icons.auto_awesome_rounded,
        'OptiFine' => Icons.tune_rounded,
        _ => Icons.extension_rounded,
      };

  Color _colorFor(String name) => switch (name) {
        'Fabric'   => AppTheme.accent,
        'Quilt'    => AppTheme.accent2,
        'Forge'    => AppTheme.warn,
        'NeoForge' => AppTheme.danger,
        'OptiFine' => AppTheme.accent2,
        _ => AppTheme.textLo,
      };

  String _descFor(String name) => switch (name) {
        'Fabric'   => 'Lightweight, fast updates, large mod ecosystem',
        'Quilt'    => 'Fabric-compatible fork with extra hooks',
        'Forge'    => 'Classic loader, broadest mod compatibility',
        'NeoForge' => 'Modern Forge fork (1.20.2+)',
        'OptiFine' => 'Optimisation + shaders. Mirrored via BMCLAPI.',
        _ => '',
      };

  Future<void> _pickAndInstall(
      BuildContext context, ModLoaderInstaller loader, String mc) async {
    setState(() {
      _installing = true;
      _statusMessage = 'Fetching ${loader.displayName} versions for $mc…';
    });
    List<String> versions = const [];
    try {
      versions = await loader.listLoaderVersions(mc);
    } catch (e) {
      setState(() {
        _installing = false;
        _statusMessage = '${loader.displayName}: $e';
      });
      return;
    }
    if (versions.isEmpty) {
      setState(() {
        _installing = false;
        _statusMessage =
            '${loader.displayName} has no builds for $mc. Try a different MC version.';
      });
      return;
    }
    if (!mounted) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('${loader.displayName} version'),
        children: [
          for (final v in versions.take(20))
            SimpleDialogOption(
              child: Text(v, style: const TextStyle(fontFamily: 'monospace')),
              onPressed: () => Navigator.pop(ctx, v),
            ),
          if (versions.length > 20)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('…and more (showing newest 20)',
                  style: TextStyle(color: AppTheme.textLo)),
            ),
        ],
      ),
    );
    if (picked == null) {
      setState(() {
        _installing = false;
        _statusMessage = null;
      });
      return;
    }

    setState(() => _statusMessage = 'Installing ${loader.displayName} $picked…');
    try {
      final newId = await loader.install(mc, loaderVersion: picked);
      final profile = ref.read(activeProfileProvider)!;
      final updated = profile.copyWith(versionId: newId);
      await ref.read(profileRepoProvider).save(updated);
      ref.read(activeProfileProvider.notifier).state = updated;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile switched to $newId')));
        setState(() {
          _installing = false;
          _statusMessage = 'Active version: $newId';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _installing = false;
          _statusMessage = 'Install failed: $e';
        });
      }
    }
  }

  Widget _empty(String msg) => Center(
        child: Padding(padding: const EdgeInsets.all(24),
            child: Text(msg, textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textLo))),
      );
}
