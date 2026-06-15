import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/errors/launcher_exception.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/paths.dart';
import '../../data/models/library_model.dart';
import '../../data/models/version_detail.dart';
import '../../platform/common/runtime_bridge.dart';
import '../entities/account.dart';
import '../entities/minecraft_version.dart';
import '../entities/profile.dart';
import 'java_runtime_manager.dart';
import 'launch_command_builder.dart';
import 'library_resolver.dart';
import 'version_installer.dart';

class LaunchContext {
  final Profile profile;
  final Account account;
  /// The official manifest entry for the version. May be null when the
  /// profile points at a modded id (Fabric / Forge / Quilt / NeoForge /
  /// OptiFine), in which case the installer looks the JSON up from disk.
  final MinecraftVersion? version;

  const LaunchContext({
    required this.profile,
    required this.account,
    this.version,
  });
}

/// Top-level orchestrator. Given (profile + account + version):
///   1. Refreshes the account if needed.
///   2. Installs the version if not already installed.
///   3. Picks/installs an appropriate Java runtime.
///   4. Builds the launch plan.
///   5. Spawns the process via the platform bridge.
///   6. Tees stdout/stderr into the profile's `logs/launcher_run_<ts>.log`.
class GameLauncher {
  GameLauncher({
    required JavaRuntimeManager javaRuntimes,
    VersionInstaller? installer,
    LibraryResolver? libraries,
    LaunchCommandBuilder? builder,
    RuntimeBridge? bridge,
  })  : _javaRuntimes = javaRuntimes,
        _installer = installer ?? VersionInstaller(),
        _libraries = libraries ?? LibraryResolver(),
        _builder = builder ?? LaunchCommandBuilder(),
        _bridge = bridge ?? RuntimeBridge.platform();

  final JavaRuntimeManager _javaRuntimes;
  final VersionInstaller _installer;
  final LibraryResolver _libraries;
  final LaunchCommandBuilder _builder;
  final RuntimeBridge _bridge;

  Stream<ProcessEvent> launch(LaunchContext ctx) async* {
    final totalSw = Stopwatch()..start();
    AppLogger.instance.info('launch',
        '═══ launch ${ctx.profile.name} (${ctx.profile.versionId}) as ${ctx.account.username} ═══');
    // 1) Make sure the version is on disk. Modded profiles (Fabric/Forge/...)
    //    aren't in the official manifest, so we use the local-JSON path.
    AppLogger.instance.info('launch', 'step 1/5 — install version');
    final VersionDetail detail = ctx.version == null
        ? await _installer.installByVersionId(
            ctx.profile.versionId, profileId: ctx.profile.id)
        : await _installer.install(
            ctx.version!, profileId: ctx.profile.id);

    // 2) Resolve classpath (libraries are already downloaded by installer;
    //    this call short-circuits via SHA1 cache hits).
    AppLogger.instance.info('launch', 'step 2/5 — resolve classpath');
    final resolved = await _libraries.downloadAndResolve(detail);

    // 3) Pick a Java runtime.
    AppLogger.instance.info('launch', 'step 3/5 — pick java');
    final recommended = JavaRuntimeManager.recommendedMajorFor(
      versionDeclared: detail.javaMajorVersion,
      versionId: detail.id,
    );
    final overrideId = ctx.profile.javaRuntimeId;
    final selectedJava = overrideId != null
        ? (await _javaRuntimes.list()).firstWhere(
            (r) => r.id == overrideId,
            orElse: () =>
                throw const LauncherException('java_missing', 'Profile Java runtime not installed'),
          )
        : await _javaRuntimes.pickFor(recommendedMajor: recommended);

    final java = await _javaRuntimes.ensureLaunchSupport(selectedJava ??
        await _javaRuntimes.installRuntime(recommended));
    if (selectedJava == null) {
      AppLogger.instance.info('launch',
          'installed Java $recommended automatically');
    }
    AppLogger.instance.info('launch',
        'java ${java.majorVersion} (${java.vendor ?? '?'}) at ${java.executablePath}');

    // 4) Build plan.
    AppLogger.instance.info('launch', 'step 4/5 — build command');
    final nativesDir = Directory(
        '${LauncherPaths.instance.profileDir(ctx.profile.id).path}/natives');
    final plan = _builder.build(
      profile: ctx.profile,
      account: ctx.account,
      version: detail,
      java: java,
      classpath: resolved.classpath,
      nativesDir: nativesDir,
      gameDirOverride: ctx.profile.gameDirOverride,
    );

    // 5) Open log file.
    final logFile = File(
        '${LauncherPaths.instance.logs.path}/run-${ctx.profile.id}-${DateTime.now().millisecondsSinceEpoch}.log');
    final log = logFile.openWrite();
    log.writeln('# WiskLauncher launch');
    log.writeln('# version=${detail.id}  profile=${ctx.profile.name}  java=${java.executablePath}');
    // Do NOT write the access token to the log.
    final sanitizedArgs = plan.arguments
        .map((a) => a == ctx.account.accessToken ? '<ACCESS_TOKEN>' : a)
        .toList();
    log.writeln('# argv=${jsonEncode(sanitizedArgs)}');

    // 6) Stream events.
    AppLogger.instance.info('launch',
        'step 5/5 — spawn ${java.executablePath} '
        '(prep took ${totalSw.elapsedMilliseconds} ms)');
    try {
      await for (final ev in _bridge.launch(plan)) {
        switch (ev) {
          case ProcessStdout(:final line):
            log.writeln(line);
            AppLogger.instance.info('game', line);
          case ProcessStderr(:final line):
            log.writeln('[stderr] $line');
            AppLogger.instance.warn('game', line);
          case ProcessExited(:final exitCode):
            log.writeln('# exit=$exitCode');
            AppLogger.instance.info('launch', '═══ game exited (code $exitCode) ═══');
        }
        yield ev;
      }
    } finally {
      await log.flush();
      await log.close();
    }
  }
}
