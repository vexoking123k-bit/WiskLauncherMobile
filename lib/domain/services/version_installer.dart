import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/app_logger.dart';
import '../../core/utils/paths.dart';
import '../../data/datasources/http_downloader.dart';
import '../../data/datasources/version_manifest_datasource.dart';
import '../../data/models/library_model.dart';
import '../../data/models/version_detail.dart';
import '../entities/minecraft_version.dart';
import 'asset_downloader.dart';
import 'library_resolver.dart';
import 'natives_extractor.dart';

class InstallProgress {
  final String stage;     // "json" | "client" | "libraries" | "assets" | "natives" | "done"
  final double fraction;  // 0..1 of this stage
  final String message;

  const InstallProgress(this.stage, this.fraction, this.message);
}

/// Orchestrates the full per-version install. Two entry points:
///
///   * [install] for vanilla MC versions (we know their manifest entry).
///   * [installByVersionId] for modded ones (Fabric/Forge/etc.) — we read
///     the local `<id>.json` written by the loader installer and recursively
///     install the parent vanilla version via `inheritsFrom`.
class VersionInstaller {
  VersionInstaller({
    VersionManifestDatasource? manifest,
    HttpDownloader? downloader,
    LibraryResolver? libraryResolver,
    AssetDownloader? assetDownloader,
    NativesExtractor? nativesExtractor,
  })  : _manifest = manifest ?? VersionManifestDatasource(),
        _downloader = downloader ?? HttpDownloader(),
        _libs = libraryResolver ?? LibraryResolver(),
        _assets = assetDownloader ?? AssetDownloader(),
        _natives = nativesExtractor ?? NativesExtractor();

  final VersionManifestDatasource _manifest;
  final HttpDownloader _downloader;
  final LibraryResolver _libs;
  final AssetDownloader _assets;
  final NativesExtractor _natives;

  Future<VersionDetail> install(
    MinecraftVersion version, {
    required String profileId,
    void Function(InstallProgress p)? onProgress,
  }) async {
    onProgress?.call(const InstallProgress('json', 0, 'Fetching version JSON'));
    final detail = await _manifest.fetchVersionDetail(version);
    return _installShared(detail, profileId: profileId, onProgress: onProgress);
  }

  /// Modded entry point. Reads the local `<versionId>.json` and, if it has
  /// `inheritsFrom`, transparently installs the parent vanilla version first
  /// and merges the two.
  Future<VersionDetail> installByVersionId(
    String versionId, {
    required String profileId,
    void Function(InstallProgress p)? onProgress,
  }) async {
    final localJson = LauncherPaths.instance.versionJson(versionId);
    if (!await localJson.exists()) {
      throw StateError('No local version JSON for $versionId — install the loader first');
    }
    final json = jsonDecode(await localJson.readAsString()) as Map<String, dynamic>;
    final inheritsFrom = json['inheritsFrom'] as String?;
    if (inheritsFrom != null) {
      onProgress?.call(InstallProgress('parent', 0, 'Installing parent $inheritsFrom'));
      final manifest = await _manifest.fetchManifest();
      final parent = manifest.firstWhere(
        (v) => v.id == inheritsFrom,
        orElse: () => throw StateError('Parent version $inheritsFrom missing from manifest'),
      );
      final parentDetail = await _manifest.fetchVersionDetail(parent);
      // Install parent jar/libraries/assets first.
      await _installShared(parentDetail, profileId: profileId, onProgress: onProgress);
      // Merge child overrides on top.
      final merged = _mergeJson(parentDetail, json);
      return _installShared(merged, profileId: profileId, onProgress: onProgress);
    }
    final detail = VersionDetail.fromJson(json);
    return _installShared(detail, profileId: profileId, onProgress: onProgress);
  }

  /// Merge an `inheritsFrom` child JSON on top of an already-parsed parent
  /// VersionDetail. Modded loaders only override a subset of fields.
  VersionDetail _mergeJson(VersionDetail parent, Map<String, dynamic> childJson) {
    final mergedJson = <String, dynamic>{
      'id': childJson['id'] ?? parent.id,
      'type': childJson['type'] ?? parent.type,
      'mainClass': childJson['mainClass'] ?? parent.mainClass,
      'assets': childJson['assets'] ?? parent.assets,
      'assetIndex': _assetIndexToJson(parent.assetIndex),
      'downloads': {
        if (parent.clientJar != null)
          'client': {
            'sha1': parent.clientJar!.sha1,
            'size': parent.clientJar!.size,
            'url': parent.clientJar!.url,
          },
      },
      // libraries: child first (higher precedence), then parent.
      'libraries': [
        ...((childJson['libraries'] as List?) ?? const []),
        ...parent.libraries.map(_libraryToJson),
      ],
      // args: concatenate
      if (childJson['arguments'] is Map) 'arguments': childJson['arguments'],
      if (childJson['minecraftArguments'] is String)
        'minecraftArguments': childJson['minecraftArguments'],
      'javaVersion': {
        'majorVersion': parent.javaMajorVersion ?? 8,
      },
    };
    return VersionDetail.fromJson(mergedJson);
  }

  Map<String, dynamic>? _assetIndexToJson(AssetIndexRef? r) => r == null
      ? null
      : {
          'id': r.id,
          'sha1': r.sha1,
          'size': r.size,
          if (r.totalSize != null) 'totalSize': r.totalSize,
          'url': r.url,
        };

  Map<String, dynamic> _libraryToJson(Library library) {
    final m = <String, dynamic>{'name': library.name};
    if (library.artifact != null) {
      m['downloads'] = {
        'artifact': {
          'path': library.artifact!.path,
          if (library.artifact!.sha1 != null) 'sha1': library.artifact!.sha1,
          if (library.artifact!.size != null) 'size': library.artifact!.size,
          'url': library.artifact!.url,
        },
      };
    }
    return m;
  }

  Future<VersionDetail> _installShared(
    VersionDetail detail, {
    required String profileId,
    void Function(InstallProgress p)? onProgress,
  }) async {
    AppLogger.instance.info('install', '── ${detail.id} ──');
    AppLogger.instance.info('install', 'mainClass=${detail.mainClass}');
    AppLogger.instance.info('install',
        'assetsIndex=${detail.assets ?? detail.assetIndex?.id} libs=${detail.libraries.length}');
    final marker = _installMarker(detail.id, profileId);
    final nativesDir = Directory(
        '${LauncherPaths.instance.profileDir(profileId).path}/natives');
    if (await marker.exists() &&
        await LauncherPaths.instance.versionJar(detail.id).exists() &&
        await nativesDir.exists()) {
      onProgress?.call(InstallProgress('done', 1, '${detail.id} already ready'));
      AppLogger.instance.info('install', '✔ ${detail.id} ready (cached)');
      return detail;
    }

    onProgress?.call(const InstallProgress('client', 0, 'Downloading client jar'));
    final clientRef = detail.clientJar;
    if (clientRef != null) {
      AppLogger.instance.info('install', 'client jar ${_kb(clientRef.size)}');
      await _downloader.download(
        url: clientRef.url,
        destinationPath: LauncherPaths.instance.versionJar(detail.id).path,
        expectedSha1: clientRef.sha1,
        expectedSize: clientRef.size,
      );
    }

    onProgress?.call(const InstallProgress('libraries', 0, 'Downloading libraries'));
    final resolved = await _libs.downloadAndResolve(
      detail,
      onProgress: (name, i, total) =>
          onProgress?.call(InstallProgress('libraries', i / total, name)),
    );

    onProgress?.call(const InstallProgress('assets', 0, 'Downloading assets'));
    await _assets.download(
      detail,
      onProgress: (done, total) => onProgress
          ?.call(InstallProgress('assets', done / total, '$done / $total')),
    );

    onProgress?.call(const InstallProgress('natives', 0, 'Extracting natives'));
    await _natives.extract(
      nativesJars: resolved.nativesJars,
      outDir: nativesDir,
      sourceLibraries: detail.libraries.where((l) => l.isApplicable()).toList(),
    );

    onProgress?.call(InstallProgress('done', 1, 'Installed ${detail.id}'));
    await marker.parent.create(recursive: true);
    await marker.writeAsString(DateTime.now().toIso8601String());
    AppLogger.instance.info('install', '✔ ${detail.id} ready');
    return detail;
  }

  File _installMarker(String versionId, String profileId) => File(p.join(
      LauncherPaths.instance.profileDir(profileId).path,
      'installed-$versionId.ok'));

  static String _kb(int? bytes) {
    if (bytes == null) return '?';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)}MB';
  }
}
