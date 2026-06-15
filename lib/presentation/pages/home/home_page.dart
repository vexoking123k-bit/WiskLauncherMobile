import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/launcher_exception.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/services/game_launcher.dart';
import '../../../platform/common/runtime_bridge.dart';
import '../../app_shell.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_tile.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    final profile = ref.watch(activeProfileProvider);
    final running = ref.watch(gameRunningProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            _hero(context, ref, account: account, profile: profile, running: running),
            const SectionHeader('Setup'),
            StatusTile(
              icon: Icons.person_rounded,
              title: account?.username ?? 'No account',
              subtitle: account == null
                  ? 'Tap to sign in with Microsoft or use Offline mode'
                  : (account.refreshToken.isEmpty
                      ? 'Offline account — single-player & offline-mode servers only'
                      : 'Microsoft account • ${_shortUuid(account.uuid)}'),
              ok: account != null,
              iconColor: account?.refreshToken.isEmpty ?? false
                  ? AppTheme.warn
                  : AppTheme.accent,
              onTap: () => AppShellScope.of(context).goTo(NavTab.accounts),
            ),
            const SizedBox(height: 10),
            StatusTile(
              icon: Icons.folder_special_rounded,
              title: profile?.name ?? 'No profile',
              subtitle: profile == null
                  ? 'Create a profile with a Minecraft version'
                  : '${profile.versionId} • ${profile.maxRamMb} MB RAM',
              ok: profile != null,
              iconColor: AppTheme.accent2,
              onTap: () => AppShellScope.of(context).goTo(NavTab.profiles),
            ),
            const SizedBox(height: 10),
            StatusTile(
              icon: Icons.coffee_rounded,
              title: 'Java runtime',
              subtitle: Platform.isAndroid
                  ? 'Manage in the Java tab — auto-install if missing'
                  : 'iOS cannot run Java — manager mode only',
              ok: true,
              iconColor: AppTheme.warn,
              onTap: () => AppShellScope.of(context).goTo(NavTab.java),
            ),

            const SectionHeader('Play'),
            _playButton(context, ref, account: account, profile: profile, running: running),

            if (Platform.isIOS) ...[
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: const [
                    Icon(Icons.info_outline, color: AppTheme.accent2),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'iOS: launching Minecraft is not possible on stock iOS. '
                        'WiskLauncher runs as a downloader / manager.',
                        style: TextStyle(color: AppTheme.textMid, height: 1.35),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, WidgetRef ref,
      {required dynamic account, required dynamic profile, required bool running}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: heroGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt_rounded, color: AppTheme.accent),
          ),
          const SizedBox(width: 10),
          const Text('WiskLauncher',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4)),
          const Spacer(),
          if (running)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                SizedBox(
                    width: 10, height: 10,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.accent)),
                SizedBox(width: 8),
                Text('Running', style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),
        const SizedBox(height: 18),
        Text(
          account == null
              ? 'Welcome — sign in to get started.'
              : 'Welcome back, ${account.username}.',
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, height: 1.2),
        ),
        const SizedBox(height: 6),
        Text(
          profile == null
              ? 'Create a profile, then press Play.'
              : 'Ready to play ${profile.versionId}.',
          style: const TextStyle(color: AppTheme.textMid, fontSize: 14, height: 1.35),
        ),
      ]),
    );
  }

  Widget _playButton(BuildContext context, WidgetRef ref,
      {required dynamic account, required dynamic profile, required bool running}) {
    final enabled = account != null && profile != null && !running;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: Icon(running ? Icons.sync : Icons.play_arrow_rounded, size: 26),
        label: Text(
          running ? 'Game is running…' : (enabled ? 'Play' : 'Set up account & profile first'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: enabled ? AppTheme.accent : AppTheme.bgPanelHi,
          foregroundColor: enabled ? Colors.black : AppTheme.textLo,
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        onPressed: enabled ? () => _launch(context, ref) : null,
      ),
    );
  }

  String _shortUuid(String uuid) =>
      uuid.length > 12 ? '${uuid.substring(0, 8)}…${uuid.substring(uuid.length - 4)}' : uuid;

  Future<void> _launch(BuildContext context, WidgetRef ref) async {
    final account = ref.read(activeAccountProvider);
    final profile = ref.read(activeProfileProvider);
    if (account == null || profile == null) return;

    ref.read(gameRunningProvider.notifier).state = true;
    // Jump the user to the Logs tab so they see everything.
    AppShellScope.of(context).goTo(NavTab.logs);

    try {
      final versions = await ref.read(versionsProvider.future);
      final matches = versions.where((v) => v.id == profile.versionId).toList();
      final version = matches.isEmpty ? null : matches.first;
      final stream = ref.read(gameLauncherProvider).launch(LaunchContext(
            profile: profile,
            account: account,
            version: version,
          ));
      // Consume the stream — every event is already logged by GameLauncher.
      await for (final _ in stream) {}
    } on PlatformUnsupportedException catch (e) {
      AppLogger.instance.error('launch', e.message);
    } on LauncherException catch (e) {
      AppLogger.instance.error('launch', e.message);
    } catch (e) {
      AppLogger.instance.error('launch', '$e');
    } finally {
      ref.read(gameRunningProvider.notifier).state = false;
    }
  }
}
