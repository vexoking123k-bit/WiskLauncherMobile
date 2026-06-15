import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

class HashUtils {
  HashUtils._();

  /// Streaming SHA1 of a file. Returns lowercase hex.
  static Future<String> sha1OfFile(File file) async {
    Digest? digest;
    final sink = ChunkedConversionSink<Digest>.withCallback((events) {
      digest = events.single;
    });
    final converter = sha1.startChunkedConversion(sink);
    await for (final chunk in file.openRead()) {
      converter.add(chunk);
    }
    converter.close();
    return digest!.toString();
  }

  static Future<bool> verifySha1(File file, String expected) async {
    if (!await file.exists()) return false;
    final actual = await sha1OfFile(file);
    return actual.toLowerCase() == expected.toLowerCase();
  }
}
