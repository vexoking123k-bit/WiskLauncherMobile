import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/paths.dart';
import '../../data/datasources/http_downloader.dart';
import '../entities/download_task.dart';

/// Application-level queue of file downloads. Persists to
/// `<configs>/downloads.json` so resumes survive app restarts. Concurrency
/// is bounded so we don't drown the device on slow mobile links.
class DownloadManager {
  DownloadManager({HttpDownloader? downloader, int concurrency = 3})
      : _downloader = downloader ?? HttpDownloader(),
        _concurrency = concurrency;

  final HttpDownloader _downloader;
  final int _concurrency;

  final List<DownloadTask> _tasks = [];
  final Map<String, CancelToken> _cancelTokens = {};
  final StreamController<List<DownloadTask>> _events =
      StreamController.broadcast();

  bool _loaded = false;

  Stream<List<DownloadTask>> get stream => _events.stream;
  List<DownloadTask> get snapshot => List.unmodifiable(_tasks);

  File get _file =>
      File(p.join(LauncherPaths.instance.configs.path, 'downloads.json'));

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final f = _file;
    if (await f.exists()) {
      final raw = await f.readAsString();
      if (raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _tasks
          ..clear()
          ..addAll(list.map(DownloadTask.fromJson));
      }
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
        jsonEncode(_tasks.map((t) => t.toJson()).toList()));
    _events.add(snapshot);
  }

  Future<DownloadTask> enqueue({
    required String url,
    required String destinationPath,
    required String label,
    int? expectedSize,
    String? expectedSha1,
  }) async {
    await _ensureLoaded();
    final task = DownloadTask(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      url: url,
      destinationPath: destinationPath,
      expectedSize: expectedSize,
      expectedSha1: expectedSha1,
      label: label,
      created: DateTime.now(),
    );
    _tasks.add(task);
    await _persist();
    unawaited(_drain());
    return task;
  }

  Future<void> cancel(String id) async {
    _cancelTokens[id]?.cancel('user');
    final t = _tasks.firstWhere((t) => t.id == id, orElse: () => _missing(id));
    t.state = DownloadState.cancelled;
    await _persist();
  }

  Future<void> retry(String id) async {
    final t = _tasks.firstWhere((t) => t.id == id, orElse: () => _missing(id));
    t.state = DownloadState.queued;
    t.errorMessage = null;
    await _persist();
    unawaited(_drain());
  }

  DownloadTask _missing(String id) =>
      throw StateError('No download task with id=$id');

  Future<void> _drain() async {
    final running =
        _tasks.where((t) => t.state == DownloadState.running).length;
    final slots = _concurrency - running;
    if (slots <= 0) return;
    final queued =
        _tasks.where((t) => t.state == DownloadState.queued).take(slots);
    for (final task in queued.toList()) {
      unawaited(_run(task));
    }
  }

  Future<void> _run(DownloadTask task) async {
    task.state = DownloadState.running;
    await _persist();
    final cancel = CancelToken();
    _cancelTokens[task.id] = cancel;
    try {
      await _downloader.download(
        url: task.url,
        destinationPath: task.destinationPath,
        expectedSha1: task.expectedSha1,
        expectedSize: task.expectedSize,
        cancelToken: cancel,
        onProgress: (received, total) {
          task.bytesDownloaded = received;
          // Coalesced UI tick — don't persist on every byte.
          _events.add(snapshot);
        },
      );
      task.state = DownloadState.completed;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        task.state = DownloadState.cancelled;
      } else {
        task.state = DownloadState.failed;
        task.errorMessage = e.message;
      }
    } catch (e) {
      task.state = DownloadState.failed;
      task.errorMessage = e.toString();
    } finally {
      _cancelTokens.remove(task.id);
      await _persist();
      unawaited(_drain());
    }
  }

  Future<void> dispose() async {
    await _events.close();
  }
}
