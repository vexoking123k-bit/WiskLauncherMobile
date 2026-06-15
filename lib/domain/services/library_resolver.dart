import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../../core/utils/app_logger.dart';
import '../../core/utils/paths.dart';
import '../../data/datasources/http_downloader.dart';
import '../../data/models/library_model.dart';
import '../../data/models/version_detail.dart';

class ResolvedLibraries {
  final List<File> classpath;
  final List<File> nativesJars;

  const ResolvedLibraries({required this.classpath, required this.nativesJars});
}

/// Bounded-concurrency library downloader. Each worker pulls the next
/// (lib, artifact) tuple off a shared counter and downloads it; classpath
/// jars and native-classifier jars are interleaved so we don't bottleneck on
/// either kind alone.
class LibraryResolver {
  LibraryResolver({HttpDownloader? downloader, int concurrency = 16})
      : _downloader = downloader ?? HttpDownloader(),
        _concurrency = concurrency;

  final HttpDownloader _downloader;
  final int _concurrency;

  Future<ResolvedLibraries> downloadAndResolve(
    VersionDetail detail, {
    void Function(String name, int index, int total)? onProgress,
  }) async {
    final libsDir = LauncherPaths.instance.libraries;
    final applicable = detail.libraries.where((l) => l.isApplicable()).toList();

    final tasks = <_LibTask>[];
    for (final lib in applicable) {
      if (lib.artifact != null) {
        tasks.add(_LibTask(lib.name, lib.artifact!, isNative: false));
      }
      final classifier = lib.nativeClassifierForCurrentOs();
      if (classifier != null) {
        final natArtifact = lib.classifiers[classifier];
        if (natArtifact != null) {
          tasks.add(_LibTask('${lib.name}:$classifier', natArtifact, isNative: true));
        }
      }
    }

    AppLogger.instance.info('libs',
        'resolving ${tasks.length} library files (concurrency=$_concurrency)');
    final sw = Stopwatch()..start();
    final classpath = <File>[];
    final natives = <File>[];
    var nextIndex = 0;
    var done = 0;

    final reportEvery = (tasks.length / 10).ceil().clamp(5, 50);
    Future<void> worker() async {
      while (true) {
        final i = nextIndex++;
        if (i >= tasks.length) return;
        final t = tasks[i];
        final dest = File(p.join(libsDir.path, t.artifact.path));
        await _downloader.download(
          url: t.artifact.url,
          destinationPath: dest.path,
          expectedSha1: t.artifact.sha1,
          expectedSize: t.artifact.size,
        );
        if (t.isNative) {
          natives.add(dest);
        } else {
          classpath.add(dest);
        }
        final d = ++done;
        onProgress?.call(t.name, d, tasks.length);
        if (d % reportEvery == 0) {
          AppLogger.instance.info('libs', '$d / ${tasks.length} files');
        }
      }
    }

    await Future.wait(List.generate(_concurrency, (_) => worker()));
    sw.stop();
    AppLogger.instance.info('libs',
        'resolved ${tasks.length} files in ${sw.elapsedMilliseconds} ms '
        '(${classpath.length} cp, ${natives.length} natives)');
    return ResolvedLibraries(classpath: classpath, nativesJars: natives);
  }
}

class _LibTask {
  final String name;
  final LibraryArtifact artifact;
  final bool isNative;
  _LibTask(this.name, this.artifact, {required this.isNative});
}
