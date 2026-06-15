import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/launcher_exception.dart';
import '../../../domain/entities/java_runtime.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_header.dart';

/// All Java major versions Minecraft has ever required.
/// MC ≤ 1.16 → 8, 1.17 → 16, 1.18–1.20.4 → 17, 1.20.5+ → 21. (11 listed because
/// some modded packs / older snapshots target it.)
const _supportedMajors = [8, 11, 16, 17, 21];

class JavaPage extends ConsumerStatefulWidget {
  const JavaPage({super.key});

  @override
  ConsumerState<JavaPage> createState() => _JavaPageState();
}

class _JavaPageState extends ConsumerState<JavaPage> {
  Future<List<JavaRuntime>>? _future;
  final Map<int, bool> _installing = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = ref.read(javaRuntimeManagerProvider).list();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mgr = ref.read(javaRuntimeManagerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Java runtimes')),
      body: FutureBuilder<List<JavaRuntime>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final runtimes = snap.data!;
          final installedMajors = runtimes.map((r) => r.majorVersion).toSet();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (Platform.isAndroid) _holyJavaNotice(),
              const SectionHeader('Available'),
              for (final major in _supportedMajors)
                _runtimeRow(context, mgr,
                    major: major,
                    installed:
                        runtimes.where((r) => r.majorVersion == major).toList(),
                    isInstalled: installedMajors.contains(major)),
              if (runtimes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    Platform.isIOS
                        ? 'iOS cannot run Java — see docs/IOS_LIMITATIONS.md'
                        : 'Tap Install on any version to download it.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textLo),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _holyJavaNotice() => Container(
        margin: const EdgeInsets.only(top: 4, bottom: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgPanelHi,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accent2.withOpacity(0.4)),
        ),
        child: const Row(children: [
          Icon(Icons.bolt_rounded, color: AppTheme.accent2),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'On Android we install PojavLauncherTeam’s Holy Java — a real '
              'Android/bionic build of OpenJDK. The launcher otherwise can’t '
              'exec a desktop Linux JRE.',
              style: TextStyle(
                  color: AppTheme.textMid, height: 1.35, fontSize: 12.5),
            ),
          ),
        ]),
      );

  Widget _runtimeRow(
    BuildContext context,
    dynamic mgr, {
    required int major,
    required List<JavaRuntime> installed,
    required bool isInstalled,
  }) {
    final color = _colorForMajor(major);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.stroke),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text('$major',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w900, fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Java $major',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(_recommendationFor(major),
                    style:
                        const TextStyle(color: AppTheme.textMid, fontSize: 12)),
                if (installed.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(installed.first.executablePath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.textLo,
                          fontSize: 11,
                          fontFamily: 'monospace')),
                ],
              ])),
          if (_installing[major] == true)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else if (isInstalled)
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.bug_report_outlined),
                tooltip: 'Verify',
                onPressed: () async {
                  final ok = await mgr.verify(installed.first);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(ok ? 'OK' : 'Verification failed')),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                tooltip: 'Unregister',
                onPressed: () async {
                  await mgr.unregister(installed.first.id);
                  _refresh();
                },
              ),
            ])
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: color.withOpacity(0.18),
                foregroundColor: color,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Install'),
              onPressed: () => _install(major, mgr),
            ),
        ]),
      ),
    );
  }

  Future<void> _install(int major, dynamic mgr) async {
    setState(() => _installing[major] = true);
    try {
      await mgr.installRuntime(major);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Java $major installed')));
      }
    } on LauncherException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _installing[major] = false);
        _refresh();
      }
    }
  }

  Color _colorForMajor(int major) {
    switch (major) {
      case 8:
        return AppTheme.warn;
      case 11:
        return AppTheme.accent2;
      case 16:
        return AppTheme.accent2;
      case 17:
        return AppTheme.accent;
      case 21:
        return AppTheme.accent;
    }
    return AppTheme.textLo;
  }

  String _recommendationFor(int major) => switch (major) {
        8 => 'Minecraft ≤ 1.16, most older modpacks',
        11 => 'Some 1.16 modded packs, Forge tooling',
        16 => 'Minecraft 1.17 only',
        17 => 'Minecraft 1.18 – 1.20.4',
        21 => 'Minecraft 1.20.5 and newer',
        _ => 'Unknown',
      };
}
