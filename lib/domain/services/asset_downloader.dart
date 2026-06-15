import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../../core/constants/endpoints.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/paths.dart';
import '../../data/datasources/http_downloader.dart';
import '../../data/models/asset_index.dart';
import '../../data/models/version_detail.dart';

class AssetDownloader {
  AssetDownloader({HttpDownloader? downloader, int concurrency = 24})
      : _downloader = downloader ?? HttpDownloader(),
        _concurrency = concurrency;

  final HttpDownloader _downloader;
  final int _concurrency;

  /// Downloads the asset index, then all referenced asset objects, in
  /// bounded-parallel batches.
  Future<void> download(
    VersionDetail detail, {
    void Function(int downloaded, int total)? onProgress,
  }) async {
    final ref = detail.assetIndex;
    if (ref == null) return;

    final indexFile =
        File(p.join(LauncherPaths.instance.assetsIndexes.path, '${ref.id}.json'));
    AppLogger.instance.info('assets', 'fetching index ${ref.id}');
    await _downloader.download(
      url: ref.url,
      destinationPath: indexFile.path,
      expectedSha1: ref.sha1,
      expectedSize: ref.size,
    );
    final index = AssetIndex.fromJson(
        jsonDecode(await indexFile.readAsString()) as Map<String, dynamic>);

    final entries = index.objects.entries.toList();
    AppLogger.instance.info('assets',
        'downloading ${entries.length} asset objects (concurrency=$_concurrency)');
    final sw = Stopwatch()..start();
    var nextIndex = 0;
    var done = 0;

    final reportEvery = (entries.length / 20).ceil().clamp(50, 500);
    Future<void> worker() async {
      while (true) {
        final i = nextIndex++;
        if (i >= entries.length) return;
        final entry = entries[i];
        final obj = entry.value;
        final hash = obj.hash;
        final subDir = hash.substring(0, 2);
        final dest = File(p.join(
            LauncherPaths.instance.assetsObjects.path, subDir, hash));
        await _downloader.download(
          url: '${Endpoints.resourcesBase}/$subDir/$hash',
          destinationPath: dest.path,
          expectedSha1: hash,
          expectedSize: obj.size,
        );
        final d = ++done;
        onProgress?.call(d, entries.length);
        // Periodic info-level heartbeat so the user sees progress without
        // drowning the logs in per-file noise.
        if (d % reportEvery == 0) {
          AppLogger.instance.info('assets', '$d / ${entries.length} objects');
        }
      }
    }

    await Future.wait(List.generate(_concurrency, (_) => worker()));
    sw.stop();
    AppLogger.instance.info('assets',
        '${entries.length} objects ready in ${sw.elapsedMilliseconds} ms');
  }
}
