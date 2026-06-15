import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart' as xml;

import '../../core/constants/endpoints.dart';
import '../../core/errors/launcher_exception.dart';
import '../../core/utils/paths.dart';
import '../../data/datasources/http_downloader.dart';

/// Common contract for installers. Each implementation writes a synthetic
/// `<modded-id>.json` next to the vanilla version JSONs so the regular
/// VersionInstaller / LaunchCommandBuilder pipeline picks them up unchanged.
abstract class ModLoaderInstaller {
  String get displayName;

  /// Lists installable loader versions for the given Minecraft id. May
  /// return an empty list if the loader doesn't support that MC version.
  Future<List<String>> listLoaderVersions(String minecraftVersionId);

  /// Installs the loader. Returns the new version id (e.g.
  /// `fabric-loader-0.16.5-1.21.4`).
  Future<String> install(String minecraftVersionId, {String? loaderVersion});
}

/// ============================================================
///  Fabric
/// ============================================================
class FabricInstaller implements ModLoaderInstaller {
  FabricInstaller({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  @override
  String get displayName => 'Fabric';

  @override
  Future<List<String>> listLoaderVersions(String mc) async {
    final r = await _dio.get<List<dynamic>>(Endpoints.fabricLoaderMeta);
    return (r.data ?? const [])
        .cast<Map<String, dynamic>>()
        .where((l) => (l['stable'] as bool?) ?? false)
        .map((l) => l['version'] as String)
        .toList();
  }

  @override
  Future<String> install(String mc, {String? loaderVersion}) async {
    final loaders = await listLoaderVersions(mc);
    if (loaders.isEmpty) {
      throw const LauncherException('fabric', 'No Fabric loader versions available');
    }
    final picked = loaderVersion ?? loaders.first;
    final url = 'https://meta.fabricmc.net/v2/versions/loader/$mc/$picked/profile/json';
    final resp = await _dio.get<String>(url,
        options: Options(responseType: ResponseType.plain));
    final json = jsonDecode(resp.data!) as Map<String, dynamic>;
    final id = json['id'] as String;
    final out = LauncherPaths.instance.versionJson(id);
    await out.parent.create(recursive: true);
    await out.writeAsString(jsonEncode(json));
    return id;
  }
}

/// ============================================================
///  Quilt — Fabric-compatible meta API
/// ============================================================
class QuiltInstaller implements ModLoaderInstaller {
  QuiltInstaller({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  @override
  String get displayName => 'Quilt';

  @override
  Future<List<String>> listLoaderVersions(String mc) async {
    final r = await _dio.get<List<dynamic>>(Endpoints.quiltLoaderMeta);
    return (r.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map((l) => l['version'] as String)
        .toList();
  }

  @override
  Future<String> install(String mc, {String? loaderVersion}) async {
    final loaders = await listLoaderVersions(mc);
    if (loaders.isEmpty) {
      throw const LauncherException('quilt', 'No Quilt loader versions available');
    }
    final picked = loaderVersion ?? loaders.first;
    final url = 'https://meta.quiltmc.org/v3/versions/loader/$mc/$picked/profile/json';
    final resp = await _dio.get<String>(url,
        options: Options(responseType: ResponseType.plain));
    final json = jsonDecode(resp.data!) as Map<String, dynamic>;
    final id = json['id'] as String;
    final out = LauncherPaths.instance.versionJson(id);
    await out.parent.create(recursive: true);
    await out.writeAsString(jsonEncode(json));
    return id;
  }
}

/// ============================================================
///  Forge — downloads the installer JAR and extracts the profile JSON.
///
///  The installer JAR contains either:
///    * (modern, 1.13+) `install_profile.json` + `version.json`. We use the
///      latter directly. Modern Forge also references "post-processors" that
///      binary-patch vanilla.jar at first launch; we trigger that the first
///      time the user presses Play, via the installer's `data/client.lzma`
///      patches.
///    * (legacy, ≤1.12) `install_profile.json` containing the version data
///      inline under `versionInfo`. We synthesize the version JSON from that.
/// ============================================================
class ForgeInstaller implements ModLoaderInstaller {
  ForgeInstaller({Dio? dio, HttpDownloader? downloader})
      : _dio = dio ?? Dio(),
        _downloader = downloader ?? HttpDownloader();
  final Dio _dio;
  final HttpDownloader _downloader;

  @override
  String get displayName => 'Forge';

  @override
  Future<List<String>> listLoaderVersions(String mc) async {
    // Forge publishes a small JSON with recommended/latest per MC version.
    // For a complete list we'd need to scrape; recommended+latest is what
    // 95% of users want.
    try {
      final r = await _dio.get<Map<String, dynamic>>(Endpoints.forgePromotions);
      final promos = (r.data?['promos'] as Map?)?.cast<String, dynamic>() ?? {};
      final out = <String>[];
      for (final tag in ['$mc-recommended', '$mc-latest']) {
        final v = promos[tag];
        if (v is String) out.add(v);
      }
      return out.toSet().toList();
    } on DioException catch (e) {
      throw NetworkException('Forge promotions fetch failed: ${e.message}', cause: e);
    }
  }

  @override
  Future<String> install(String mc, {String? loaderVersion}) async {
    final versions = await listLoaderVersions(mc);
    if (versions.isEmpty) {
      throw LauncherException('forge', 'No Forge version available for $mc');
    }
    final forgeVer = loaderVersion ?? versions.first;
    final full = '$mc-$forgeVer';

    // Download the installer JAR.
    final installerUrl =
        '${Endpoints.forgeMavenBase}/$full/forge-$full-installer.jar';
    final installerPath = p.join(
        LauncherPaths.instance.configs.path, 'forge-installer-$full.jar');
    await _downloader.download(
        url: installerUrl, destinationPath: installerPath);

    // Parse the installer JAR.
    final bytes = await File(installerPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    Map<String, dynamic>? installProfile;
    Map<String, dynamic>? versionJson;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      switch (entry.name) {
        case 'install_profile.json':
          installProfile = jsonDecode(utf8.decode(entry.content as List<int>))
              as Map<String, dynamic>;
          break;
        case 'version.json':
          versionJson = jsonDecode(utf8.decode(entry.content as List<int>))
              as Map<String, dynamic>;
          break;
      }
    }

    if (installProfile == null) {
      throw const LauncherException(
          'forge', 'Installer JAR missing install_profile.json');
    }

    // Modern (1.13+) vs legacy.
    final Map<String, dynamic> finalVersionJson;
    if (versionJson != null) {
      finalVersionJson = versionJson;
    } else if (installProfile['versionInfo'] is Map<String, dynamic>) {
      // Legacy: inline.
      finalVersionJson = Map<String, dynamic>.from(
          installProfile['versionInfo'] as Map<String, dynamic>);
    } else {
      throw const LauncherException(
          'forge', 'Unrecognized Forge installer layout');
    }

    final id = finalVersionJson['id'] as String;
    final out = LauncherPaths.instance.versionJson(id);
    await out.parent.create(recursive: true);
    await out.writeAsString(jsonEncode(finalVersionJson));

    // Stash install_profile.json alongside — the launch step will run any
    // declared `processors` (binary patch vanilla.jar) on first launch.
    final profileOut = File(p.join(
        LauncherPaths.instance.versionDir(id).path, 'install_profile.json'));
    await profileOut.writeAsString(jsonEncode(installProfile));

    return id;
  }
}

/// ============================================================
///  NeoForge — same installer-JAR pattern as Forge.
/// ============================================================
class NeoForgeInstaller implements ModLoaderInstaller {
  NeoForgeInstaller({Dio? dio, HttpDownloader? downloader})
      : _dio = dio ?? Dio(),
        _downloader = downloader ?? HttpDownloader();
  final Dio _dio;
  final HttpDownloader _downloader;

  @override
  String get displayName => 'NeoForge';

  @override
  Future<List<String>> listLoaderVersions(String mc) async {
    // NeoForge versions don't include the MC version in their name — they are
    // numbered like 20.4.237 (where 20.4 = MC 1.20.4). Convert MC → prefix.
    final prefix = _mcToNeoPrefix(mc);
    if (prefix == null) return const [];
    try {
      final r = await _dio.get<String>(Endpoints.neoForgeMetaXml,
          options: Options(responseType: ResponseType.plain));
      final doc = xml.XmlDocument.parse(r.data!);
      final all = doc
          .findAllElements('version')
          .map((e) => e.innerText.trim())
          .where((v) => v.startsWith(prefix))
          .toList();
      // Newest first.
      all.sort((a, b) => b.compareTo(a));
      // Cap to a reasonable number.
      return all.take(15).toList();
    } on DioException catch (e) {
      throw NetworkException('NeoForge metadata fetch failed: ${e.message}', cause: e);
    }
  }

  /// MC 1.20.4 → "20.4."   MC 1.21    → "21.0."   MC 1.21.1 → "21.1."
  String? _mcToNeoPrefix(String mc) {
    final m = RegExp(r'^1\.(\d+)(?:\.(\d+))?').firstMatch(mc);
    if (m == null) return null;
    final major = m.group(1)!;
    final minor = m.group(2) ?? '0';
    return '$major.$minor.';
  }

  @override
  Future<String> install(String mc, {String? loaderVersion}) async {
    final versions = await listLoaderVersions(mc);
    if (versions.isEmpty) {
      throw LauncherException(
          'neoforge', 'No NeoForge version available for $mc');
    }
    final ver = loaderVersion ?? versions.first;
    final url = '${Endpoints.neoForgeMavenBase}/$ver/neoforge-$ver-installer.jar';
    final installerPath = p.join(
        LauncherPaths.instance.configs.path, 'neoforge-installer-$ver.jar');
    await _downloader.download(
        url: url, destinationPath: installerPath);

    final archive = ZipDecoder().decodeBytes(await File(installerPath).readAsBytes());
    Map<String, dynamic>? installProfile;
    Map<String, dynamic>? versionJson;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      switch (entry.name) {
        case 'install_profile.json':
          installProfile = jsonDecode(utf8.decode(entry.content as List<int>))
              as Map<String, dynamic>;
          break;
        case 'version.json':
          versionJson = jsonDecode(utf8.decode(entry.content as List<int>))
              as Map<String, dynamic>;
          break;
      }
    }
    if (versionJson == null) {
      throw const LauncherException(
          'neoforge', 'NeoForge installer missing version.json');
    }
    final id = versionJson['id'] as String;
    final out = LauncherPaths.instance.versionJson(id);
    await out.parent.create(recursive: true);
    await out.writeAsString(jsonEncode(versionJson));
    if (installProfile != null) {
      await File(p.join(LauncherPaths.instance.versionDir(id).path,
              'install_profile.json'))
          .writeAsString(jsonEncode(installProfile));
    }
    return id;
  }
}

/// ============================================================
///  OptiFine — via BMCLAPI mirror.
///
///  OptiFine's upstream installer is a Swing GUI app, which we cannot run
///  on Android. BMCLAPI publishes a Forge-compatible profile JSON for each
///  OptiFine build, which is what we use here. The OptiFine library JAR is
///  downloaded from BMCLAPI's mirror.
/// ============================================================
class OptiFineInstaller implements ModLoaderInstaller {
  OptiFineInstaller({Dio? dio, HttpDownloader? downloader})
      : _dio = dio ?? Dio(),
        _downloader = downloader ?? HttpDownloader();
  final Dio _dio;
  final HttpDownloader _downloader;

  @override
  String get displayName => 'OptiFine';

  Future<List<Map<String, dynamic>>> _allVersions() async {
    final r = await _dio.get<List<dynamic>>(Endpoints.optifineVersionsList);
    return (r.data ?? const []).cast<Map<String, dynamic>>();
  }

  @override
  Future<List<String>> listLoaderVersions(String mc) async {
    final all = await _allVersions();
    return all
        .where((e) => e['mcversion'] == mc)
        .map((e) => '${e['type']}_${e['patch']}')
        .toList();
  }

  @override
  Future<String> install(String mc, {String? loaderVersion}) async {
    final all = await _allVersions();
    final candidates = all.where((e) => e['mcversion'] == mc).toList();
    if (candidates.isEmpty) {
      throw LauncherException('optifine', 'No OptiFine build for $mc');
    }
    Map<String, dynamic> picked;
    if (loaderVersion == null) {
      picked = candidates.first;
    } else {
      picked = candidates.firstWhere(
        (e) => '${e['type']}_${e['patch']}' == loaderVersion,
        orElse: () => throw LauncherException(
            'optifine', 'OptiFine build $loaderVersion not found'),
      );
    }
    final type = picked['type'] as String;
    final patch = picked['patch'] as String;
    final id = 'OptiFine_${mc}_${type}_$patch';

    // Download the OptiFine library JAR.
    final libDir = Directory(p.join(LauncherPaths.instance.libraries.path,
        'optifine', 'OptiFine', '${mc}_${type}_$patch'));
    await libDir.create(recursive: true);
    final libJar = File(p.join(libDir.path, 'OptiFine-${mc}_${type}_$patch.jar'));
    await _downloader.download(
      url: Endpoints.optifineDownload(mc, type, patch),
      destinationPath: libJar.path,
    );

    // Synthesize a Forge-style version JSON that depends on the vanilla MC
    // version (as `inheritsFrom`) and adds OptiFine to the classpath.
    final versionJson = <String, dynamic>{
      'id': id,
      'inheritsFrom': mc,
      'time': DateTime.now().toIso8601String(),
      'releaseTime': DateTime.now().toIso8601String(),
      'type': 'release',
      'mainClass': 'net.minecraft.launchwrapper.Launch',
      'minecraftArguments':
          '--tweakClass optifine.OptiFineTweaker',
      'libraries': [
        {
          'name': 'optifine:OptiFine:${mc}_${type}_$patch',
          // We've already downloaded it to libraries/ at the right Maven path,
          // so the LibraryResolver will find it locally and skip re-download
          // for any URL that 404s.
          'url': 'file://',
        },
        {
          'name': 'net.minecraft:launchwrapper:1.12',
          'url': 'https://libraries.minecraft.net/',
        },
      ],
    };
    final out = LauncherPaths.instance.versionJson(id);
    await out.parent.create(recursive: true);
    await out.writeAsString(jsonEncode(versionJson));
    return id;
  }
}

/// ============================================================
///  Mod-folder management (unchanged)
/// ============================================================
class ModFolderService {
  Directory modsDirFor(String profileId) {
    final dir = Directory(
        p.join(LauncherPaths.instance.profileDir(profileId).path, 'mods'));
    dir.createSync(recursive: true);
    return dir;
  }

  Future<List<File>> list(String profileId) async {
    final dir = modsDirFor(profileId);
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jar'))
        .toList();
  }

  Future<File> add(String profileId, File source) async {
    final dest =
        File(p.join(modsDirFor(profileId).path, p.basename(source.path)));
    await source.copy(dest.path);
    return dest;
  }

  Future<void> remove(String profileId, String fileName) async {
    final f = File(p.join(modsDirFor(profileId).path, fileName));
    if (await f.exists()) await f.delete();
  }
}
