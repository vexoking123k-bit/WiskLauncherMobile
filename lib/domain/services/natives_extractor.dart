import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/app_logger.dart';
import '../../data/models/library_model.dart';

/// Extracts platform-specific shared libraries (.so / .dll / .dylib) from
/// natives jars into a per-profile directory. Respects each library's
/// `extract.exclude` rules.
///
/// On Android, the JVM bridge (`JavaRuntimeBridge.spawn`) prepends this
/// directory to `java.library.path` and `LD_LIBRARY_PATH` before exec.
class NativesExtractor {
  /// Extracts every jar in [nativesJars] into [outDir]. Returns the count of
  /// files written.
  Future<int> extract({
    required List<File> nativesJars,
    required Directory outDir,
    required List<Library> sourceLibraries,
  }) async {
    await outDir.create(recursive: true);
    AppLogger.instance.info('natives',
        'extracting from ${nativesJars.length} jars into ${outDir.path}');
    var count = 0;

    for (var i = 0; i < nativesJars.length; i++) {
      final jar = nativesJars[i];
      final lib = i < sourceLibraries.length ? sourceLibraries[i] : null;
      final excludes = lib?.extractExcludes ?? const <String>[];

      final bytes = await jar.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final name = entry.name;
        if (_isExcluded(name, excludes)) continue;
        if (!_looksLikeNative(name)) continue;
        // Flatten — Mojang convention: natives live at the jar root.
        final outFile = File(p.join(outDir.path, p.basename(name)));
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(entry.content as List<int>, flush: true);
        count++;
      }
    }
    AppLogger.instance.info('natives', 'extracted $count native files');
    return count;
  }

  bool _isExcluded(String name, List<String> excludes) {
    for (final ex in excludes) {
      if (name.startsWith(ex)) return true;
    }
    // The Mojang manifests don't list META-INF in excludes for some old
    // versions; skip it ourselves to keep the natives dir clean.
    if (name.startsWith('META-INF/')) return true;
    return false;
  }

  bool _looksLikeNative(String name) {
    final l = name.toLowerCase();
    return l.endsWith('.so') ||
        l.endsWith('.dll') ||
        l.endsWith('.dylib') ||
        l.endsWith('.jnilib');
  }
}
