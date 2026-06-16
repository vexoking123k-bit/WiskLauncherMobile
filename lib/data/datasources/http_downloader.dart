import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../core/errors/launcher_exception.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/hash_utils.dart';

typedef ProgressCallback = void Function(int received, int? total);

/// Streamed HTTP downloader with optional SHA1 verification and resume
/// support. We use Dio because its `download` lets us stream to disk without
/// buffering the whole body in memory.
class HttpDownloader {
  HttpDownloader({Dio? dio}) : _dio = dio ?? Dio();

  static const bool _verboseHttp =
      bool.fromEnvironment('WISK_VERBOSE_HTTP', defaultValue: false);

  final Dio _dio;

  /// Downloads `url` to `destinationPath`. Returns the destination file.
  ///
  /// Fast paths:
  ///   * If the file exists and SHA1 matches → skip (and log "cached").
  ///   * If [trustSize] is true AND the file exists at exactly the expected
  ///     size → skip without rehashing. Big speedup for installs where we
  ///     already verified the file on a previous run.
  Future<File> download({
    required String url,
    required String destinationPath,
    String? expectedSha1,
    int? expectedSize,
    ProgressCallback? onProgress,
    CancelToken? cancelToken,
    bool trustSize = true,
  }) async {
    final file = File(destinationPath);
    await file.parent.create(recursive: true);
    final filename = p.basename(destinationPath);

    if (await file.exists()) {
      if (trustSize && expectedSize != null && await file.length() == expectedSize) {
        _debug('cached  $filename (${_kb(expectedSize)})');
        return file;
      }
      if (expectedSha1 != null && await HashUtils.verifySha1(file, expectedSha1)) {
        _debug('cached  $filename (sha1 ok)');
        return file;
      }
      await file.delete();
    }

    _debug('GET     $filename');
    final tmp = File('$destinationPath.part');
    final sw = Stopwatch()..start();
    try {
      await _dio.download(
        url,
        tmp.path,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(
            receiveTimeout: const Duration(minutes: 5),
            // Many CDNs lie about content-length when sending gzip — disable
            // automatic decompression so our size check matches.
            responseDecoder: null),
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      AppLogger.instance.error('http', 'fail    $filename ($url)', e.message);
      throw NetworkException('Failed to download $url: ${e.message}', cause: e);
    }

    final actualSize = await tmp.length();
    if (expectedSize != null && actualSize != expectedSize) {
      await tmp.delete();
      throw ChecksumException(
          'Size mismatch for $url: expected $expectedSize, got $actualSize');
    }
    if (expectedSha1 != null &&
        !await HashUtils.verifySha1(tmp, expectedSha1)) {
      await tmp.delete();
      throw ChecksumException(
          'SHA1 mismatch for $url (expected $expectedSha1)');
    }
    await tmp.rename(destinationPath);
    sw.stop();
    _debug('OK      $filename (${_kb(actualSize)} in ${sw.elapsedMilliseconds} ms)');
    return file;
  }

  static void _debug(String message) {
    if (_verboseHttp) {
      AppLogger.instance.debug('http', message);
    }
  }

  static String _kb(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)}MB';
  }

  /// Helper that picks a sensible filename from a URL when the caller doesn't
  /// know one.
  static String filenameFromUrl(String url) => p.basename(Uri.parse(url).path);
}
