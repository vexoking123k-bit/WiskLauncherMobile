import 'dart:io';
import 'package:path/path.dart' as p;

import '../../core/utils/paths.dart';
import '../../data/models/library_model.dart';
import '../../data/models/version_detail.dart';
import '../entities/account.dart';
import '../entities/java_runtime.dart';
import '../entities/profile.dart';

class LaunchPlan {
  /// Absolute path to the `java` executable.
  final String javaExecutable;
  /// Full argv (java itself + JVM args + main class + game args).
  final List<String> arguments;
  /// Working directory for the game process.
  final String workingDirectory;
  /// Environment variables to set (LD_LIBRARY_PATH, etc).
  final Map<String, String> environment;

  const LaunchPlan({
    required this.javaExecutable,
    required this.arguments,
    required this.workingDirectory,
    required this.environment,
  });
}

/// Builds the final `java ...` command for a given (profile + account +
/// resolved libraries) tuple. This is pure: no I/O, no process spawning — it
/// just returns the plan, which the platform bridge then executes.
class LaunchCommandBuilder {
  static const String _launcherName = 'WiskLauncher';
  static const String _launcherVersion = '0.1.0';

  LaunchPlan build({
    required Profile profile,
    required Account account,
    required VersionDetail version,
    required JavaRuntime java,
    required List<File> classpath,
    required Directory nativesDir,
    String? gameDirOverride,
  }) {
    final cpSeparator = Platform.isWindows ? ';' : ':';
    final clientJar =
        LauncherPaths.instance.versionJar(version.id);
    final javaHome = Directory(p.dirname(p.dirname(java.executablePath)));
    final pojavGlfw = File(p.join(javaHome.path, 'pojav', 'lwjgl-glfw-classes.jar'));
    final pojavLibs = Directory(p.join(javaHome.path, 'pojav-libs'));
    final nativeSearchPaths = [
      nativesDir.path,
      if (pojavLibs.existsSync()) pojavLibs.path,
    ];
    final fullCp = [
      if (pojavGlfw.existsSync()) pojavGlfw,
      clientJar,
      ...classpath,
    ].map((f) => f.path).toList(growable: false);

    final gameDir = Directory(
        gameDirOverride ?? LauncherPaths.instance.profileDir(profile.id).path);

    final tokens = <String, String>{
      'auth_player_name': account.username,
      'version_name': version.id,
      'game_directory': gameDir.path,
      'assets_root': LauncherPaths.instance.assets.path,
      'assets_index_name': version.assets ?? version.assetIndex?.id ?? 'legacy',
      'auth_uuid': account.uuid,
      'auth_access_token': account.accessToken,
      'clientid': '',
      'auth_xuid': '',
      'user_type': 'msa',
      'version_type': version.type,
      'user_properties': '{}',

      // JVM-side
      'natives_directory': nativeSearchPaths.join(cpSeparator),
      'launcher_name': _launcherName,
      'launcher_version': _launcherVersion,
      'classpath': fullCp.join(cpSeparator),
    };

    final argv = <String>[];

    // 1) JVM arguments
    if (version.arguments.legacy) {
      // Pre-1.13: launcher provides the JVM args itself.
      argv.addAll([
        '-Djava.library.path=${nativeSearchPaths.join(cpSeparator)}',
        '-cp',
        fullCp.join(cpSeparator),
      ]);
    } else {
      for (final entry in version.arguments.jvm) {
        if (!entry.isApplicable()) continue;
        for (final v in entry.values) {
          argv.add(_substitute(v, tokens));
        }
      }
    }

    // 2) User-supplied JVM args (memory, etc.).
    argv.add('-Xmx${profile.maxRamMb}M');
    argv.add('-Xms${(profile.maxRamMb / 2).round()}M');
    argv.addAll(profile.jvmArgs);

    // 3) Main class
    argv.add(version.mainClass);

    // 4) Game args
    for (final entry in version.arguments.game) {
      if (!entry.isApplicable()) continue;
      for (final v in entry.values) {
        argv.add(_substitute(v, tokens));
      }
    }

    // 5) Resolution (modern only — pre-1.13 had no rule for this)
    if (!version.arguments.legacy) {
      if (profile.width != null && profile.height != null) {
        argv.addAll(['--width', '${profile.width}', '--height', '${profile.height}']);
      }
    }

    final runtimeLibs = [
      p.join(javaHome.path, 'lib'),
      p.join(javaHome.path, 'lib', 'server'),
      p.join(javaHome.path, 'lib', 'jli'),
    ];

    return LaunchPlan(
      javaExecutable: java.executablePath,
      arguments: argv,
      workingDirectory: gameDir.path,
      environment: {
        // Android JVM bridge also pushes these into the spawned process so
        // native libs (LWJGL, GLFW, etc.) can dlopen siblings.
        'JAVA_HOME': javaHome.path,
        'HOME': gameDir.path,
        'TMPDIR': p.join(gameDir.path, 'tmp'),
        'LD_LIBRARY_PATH': [...nativeSearchPaths, ...runtimeLibs].join(':'),
      },
    );
  }

  String _substitute(String template, Map<String, String> tokens) {
    var out = template;
    tokens.forEach((k, v) {
      out = out.replaceAll('\${$k}', v);
    });
    return out;
  }
}
