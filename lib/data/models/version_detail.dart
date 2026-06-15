import 'library_model.dart';
import 'arguments_model.dart';

/// Parsed `<id>.json` for a single Minecraft version. We only keep fields the
/// launcher actually uses; the original JSON is preserved on disk so anything
/// we missed can still be read back.
class VersionDetail {
  final String id;
  final String type;
  final String mainClass;
  final String? assets;       // assets index name, e.g. "16"
  final AssetIndexRef? assetIndex;
  final ClientJarRef? clientJar;
  final List<Library> libraries;
  final Arguments arguments;  // unified arg representation
  final int? javaMajorVersion; // recommended Java major version
  final int? minimumLauncherVersion;

  const VersionDetail({
    required this.id,
    required this.type,
    required this.mainClass,
    required this.libraries,
    required this.arguments,
    this.assets,
    this.assetIndex,
    this.clientJar,
    this.javaMajorVersion,
    this.minimumLauncherVersion,
  });

  factory VersionDetail.fromJson(Map<String, dynamic> json) {
    final downloads = json['downloads'] as Map<String, dynamic>?;
    final client = downloads?['client'] as Map<String, dynamic>?;
    final aiJson = json['assetIndex'] as Map<String, dynamic>?;
    final javaVersion = json['javaVersion'] as Map<String, dynamic>?;

    return VersionDetail(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'release',
      mainClass: json['mainClass'] as String,
      assets: json['assets'] as String?,
      assetIndex: aiJson == null ? null : AssetIndexRef.fromJson(aiJson),
      clientJar: client == null ? null : ClientJarRef.fromJson(client),
      libraries: ((json['libraries'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Library.fromJson)
          .toList(),
      arguments: Arguments.fromJson(json),
      javaMajorVersion: (javaVersion?['majorVersion'] as num?)?.toInt(),
      minimumLauncherVersion:
          (json['minimumLauncherVersion'] as num?)?.toInt(),
    );
  }
}

class AssetIndexRef {
  final String id;
  final String sha1;
  final int size;
  final int? totalSize;
  final String url;

  const AssetIndexRef({
    required this.id,
    required this.sha1,
    required this.size,
    required this.url,
    this.totalSize,
  });

  factory AssetIndexRef.fromJson(Map<String, dynamic> json) => AssetIndexRef(
        id: json['id'] as String,
        sha1: json['sha1'] as String,
        size: (json['size'] as num).toInt(),
        totalSize: (json['totalSize'] as num?)?.toInt(),
        url: json['url'] as String,
      );
}

class ClientJarRef {
  final String sha1;
  final int size;
  final String url;

  const ClientJarRef({
    required this.sha1,
    required this.size,
    required this.url,
  });

  factory ClientJarRef.fromJson(Map<String, dynamic> json) => ClientJarRef(
        sha1: json['sha1'] as String,
        size: (json['size'] as num).toInt(),
        url: json['url'] as String,
      );
}
