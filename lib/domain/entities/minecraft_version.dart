enum MinecraftReleaseType { release, snapshot, oldBeta, oldAlpha }

MinecraftReleaseType _parseType(String s) {
  switch (s) {
    case 'release':
      return MinecraftReleaseType.release;
    case 'snapshot':
      return MinecraftReleaseType.snapshot;
    case 'old_beta':
      return MinecraftReleaseType.oldBeta;
    case 'old_alpha':
      return MinecraftReleaseType.oldAlpha;
    default:
      return MinecraftReleaseType.release;
  }
}

/// Lightweight summary as it appears in `version_manifest_v2.json`. Use
/// `MinecraftVersionDetail` (data layer) for the fully expanded version.
class MinecraftVersion {
  final String id;
  final MinecraftReleaseType type;
  final String url;     // version JSON url
  final String sha1;    // sha1 of the version JSON
  final DateTime releaseTime;

  const MinecraftVersion({
    required this.id,
    required this.type,
    required this.url,
    required this.sha1,
    required this.releaseTime,
  });

  factory MinecraftVersion.fromManifestJson(Map<String, dynamic> json) {
    return MinecraftVersion(
      id: json['id'] as String,
      type: _parseType(json['type'] as String),
      url: json['url'] as String,
      sha1: json['sha1'] as String,
      releaseTime: DateTime.parse(json['releaseTime'] as String),
    );
  }
}
