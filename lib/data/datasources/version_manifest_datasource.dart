import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/endpoints.dart';
import '../../core/errors/launcher_exception.dart';
import '../../core/utils/paths.dart';
import '../../domain/entities/minecraft_version.dart';
import '../models/version_detail.dart';
import 'http_downloader.dart';

/// Fetches & caches the official Minecraft version manifest and per-version
/// JSON files. All requests go to Mojang endpoints (see [Endpoints]).
class VersionManifestDatasource {
  VersionManifestDatasource({Dio? dio, HttpDownloader? downloader})
      : _dio = dio ?? Dio(),
        _downloader = downloader ?? HttpDownloader(dio: dio);

  final Dio _dio;
  final HttpDownloader _downloader;

  /// Returns the parsed manifest. Tries network first, then falls back to the
  /// last cached copy at `<configs>/version_manifest_v2.json`.
  Future<List<MinecraftVersion>> fetchManifest({bool useCacheOnly = false}) async {
    final cache = File(p.join(
        LauncherPaths.instance.configs.path, 'version_manifest_v2.json'));

    Map<String, dynamic>? json;
    if (!useCacheOnly) {
      try {
        final resp = await _dio.get<String>(Endpoints.versionManifestV2,
            options: Options(responseType: ResponseType.plain));
        if (resp.data != null) {
          await cache.parent.create(recursive: true);
          await cache.writeAsString(resp.data!);
          json = jsonDecode(resp.data!) as Map<String, dynamic>;
        }
      } on DioException {
        // fall through to cache
      }
    }

    if (json == null) {
      if (!await cache.exists()) {
        throw const NetworkException('No version manifest available (offline)');
      }
      json = jsonDecode(await cache.readAsString()) as Map<String, dynamic>;
    }

    final versions = (json['versions'] as List).cast<Map<String, dynamic>>();
    return versions.map(MinecraftVersion.fromManifestJson).toList();
  }

  /// Downloads and parses the per-version JSON, verifying SHA1.
  Future<VersionDetail> fetchVersionDetail(MinecraftVersion version) async {
    final dest = LauncherPaths.instance.versionJson(version.id);
    await _downloader.download(
      url: version.url,
      destinationPath: dest.path,
      expectedSha1: version.sha1,
    );
    final json = jsonDecode(await dest.readAsString()) as Map<String, dynamic>;
    return VersionDetail.fromJson(json);
  }
}
