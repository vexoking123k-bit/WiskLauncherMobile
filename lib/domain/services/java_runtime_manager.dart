import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/app_logger.dart';
import '../../core/utils/paths.dart';
import '../entities/java_runtime.dart';
import '../../platform/common/runtime_bridge.dart';

/// Manages the list of locally-installed Java runtimes.
///
/// The actual *installation* of a runtime (downloading & unpacking an
/// OpenJDK build) is platform-specific and is implemented in the platform
/// bridges (`JavaRuntimeBridge.installRuntime` on Android; an unsupported
/// stub on iOS). This service owns the registry on the Dart side and
/// implements the version-policy recommendation logic.
class JavaRuntimeManager {
  JavaRuntimeManager({RuntimeBridge? bridge})
      : _bridge = bridge ?? RuntimeBridge.platform();

  final RuntimeBridge _bridge;

  File get _registryFile =>
      File(p.join(LauncherPaths.instance.configs.path, 'runtimes.json'));

  Future<List<JavaRuntime>> list() async {
    if (!await _registryFile.exists()) return [];
    final raw = await _registryFile.readAsString();
    if (raw.isEmpty) return [];
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(JavaRuntime.fromJson)
        .toList();
  }

  Future<void> _writeAll(List<JavaRuntime> runtimes) async {
    await _registryFile.parent.create(recursive: true);
    await _registryFile.writeAsString(
        jsonEncode(runtimes.map((r) => r.toJson()).toList()));
  }

  Future<void> register(JavaRuntime runtime) async {
    final all = await list();
    final i = all.indexWhere((r) => r.id == runtime.id);
    if (i >= 0) {
      all[i] = runtime;
    } else {
      all.add(runtime);
    }
    await _writeAll(all);
  }

  Future<void> unregister(String id) async {
    final all = await list();
    all.removeWhere((r) => r.id == id);
    await _writeAll(all);
  }

  /// Verifies the runtime's `java -version` actually executes.
  Future<bool> verify(JavaRuntime runtime) =>
      _bridge.verifyJava(runtime.executablePath);

  /// Downloads & installs an OpenJDK runtime for the given major version
  /// (Android only). Returns the registered runtime.
  ///
  /// On iOS this throws `PlatformUnsupportedException` — see
  /// [docs/IOS_LIMITATIONS.md].
  Future<JavaRuntime> installRuntime(int majorVersion) async {
    final installed = await _bridge.installJava(
      majorVersion: majorVersion,
      targetDir: LauncherPaths.instance.runtimeDir('java-$majorVersion').path,
    );
    await register(installed);
    return installed;
  }

  Future<JavaRuntime> ensureLaunchSupport(JavaRuntime runtime) async {
    if (!Platform.isAndroid) return runtime;
    final javaHome = Directory(p.dirname(p.dirname(runtime.executablePath)));
    final glfwPatch =
        File(p.join(javaHome.path, 'pojav', 'lwjgl-glfw-classes.jar'));
    final pojavLibs = Directory(p.join(javaHome.path, 'pojav-libs'));
    if (await glfwPatch.exists() && await pojavLibs.exists()) {
      return runtime;
    }
    AppLogger.instance.info('java',
        'repairing Java ${runtime.majorVersion} launch support files');
    return installRuntime(runtime.majorVersion);
  }

  /// Picks the best registered runtime for a Minecraft version. Falls back to
  /// the closest installed major version if the exact one isn't present.
  Future<JavaRuntime?> pickFor({required int? recommendedMajor}) async {
    final all = await list();
    if (all.isEmpty) return null;
    if (recommendedMajor != null) {
      final exact =
          all.where((r) => r.majorVersion == recommendedMajor).toList();
      if (exact.isNotEmpty) return exact.first;
    }
    all.sort((a, b) => a.majorVersion.compareTo(b.majorVersion));
    if (recommendedMajor == null) return all.last;
    // Prefer the next-higher major; falls back to highest available.
    return all.firstWhere(
      (r) => r.majorVersion >= recommendedMajor,
      orElse: () => all.last,
    );
  }

  /// Maps a Minecraft version JSON's `javaVersion.majorVersion` to a
  /// recommended major. If absent (older versions) we apply the well-known
  /// schedule: ≤1.16 → Java 8, 1.17 → Java 16, 1.18–1.20.4 → Java 17,
  /// 1.20.5+ → Java 21.
  static int recommendedMajorFor({
    int? versionDeclared,
    required String versionId,
  }) {
    if (versionDeclared != null) return versionDeclared;
    final v = _parseSemver(versionId);
    if (v == null) return 8;
    if (v.$1 == 1 && v.$2 <= 16) return 8;
    if (v.$1 == 1 && v.$2 == 17) return 16;
    if (v.$1 == 1 && v.$2 <= 20 && (v.$2 < 20 || v.$3 <= 4)) return 17;
    return 21;
  }

  static (int, int, int)? _parseSemver(String id) {
    final m = RegExp(r'^(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(id);
    if (m == null) return null;
    return (
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.tryParse(m.group(3) ?? '0') ?? 0,
    );
  }
}
