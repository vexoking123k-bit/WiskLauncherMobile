import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves the on-device file system layout. All paths live under
/// `<appDocs>/wisklauncher/`.
///
///   runtimes/{java-8,java-17,java-21}/
///   versions/<id>/<id>.{jar,json}
///   libraries/<group>/<artifact>/<version>/<file>
///   assets/{indexes,objects}/
///   profiles/<profile>/
///   logs/
///   mods/
///   configs/
class LauncherPaths {
  LauncherPaths._(this.root);

  final Directory root;

  static LauncherPaths? _instance;
  static LauncherPaths get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('LauncherPaths.initialize() must be awaited first');
    }
    return i;
  }

  static Future<LauncherPaths> initialize() async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, 'wisklauncher'));
    await root.create(recursive: true);
    final i = LauncherPaths._(root);
    await i._ensureLayout();
    _instance = i;
    return i;
  }

  Future<void> _ensureLayout() async {
    for (final dir in [
      runtimes,
      versions,
      libraries,
      assets,
      assetsIndexes,
      assetsObjects,
      profiles,
      logs,
      mods,
      configs,
    ]) {
      await dir.create(recursive: true);
    }
  }

  Directory get runtimes => Directory(p.join(root.path, 'runtimes'));
  Directory get versions => Directory(p.join(root.path, 'versions'));
  Directory get libraries => Directory(p.join(root.path, 'libraries'));
  Directory get assets => Directory(p.join(root.path, 'assets'));
  Directory get assetsIndexes => Directory(p.join(assets.path, 'indexes'));
  Directory get assetsObjects => Directory(p.join(assets.path, 'objects'));
  Directory get profiles => Directory(p.join(root.path, 'profiles'));
  Directory get logs => Directory(p.join(root.path, 'logs'));
  Directory get mods => Directory(p.join(root.path, 'mods'));
  Directory get configs => Directory(p.join(root.path, 'configs'));

  Directory versionDir(String versionId) =>
      Directory(p.join(versions.path, versionId));

  File versionJson(String versionId) =>
      File(p.join(versionDir(versionId).path, '$versionId.json'));

  File versionJar(String versionId) =>
      File(p.join(versionDir(versionId).path, '$versionId.jar'));

  Directory profileDir(String profileId) =>
      Directory(p.join(profiles.path, profileId));

  Directory runtimeDir(String runtimeId) =>
      Directory(p.join(runtimes.path, runtimeId));
}
