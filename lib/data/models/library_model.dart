import '../../core/utils/platform_arch.dart';

/// A Minecraft library entry. May represent either a classpath jar, a
/// natives bundle (legacy `natives` field), or both.
class Library {
  final String name;       // "group:artifact:version"
  final List<Rule> rules;
  final LibraryArtifact? artifact;
  final Map<String, LibraryArtifact> classifiers;
  final Map<String, String> nativesMapping; // os -> classifier
  final List<String> extractExcludes;

  const Library({
    required this.name,
    this.rules = const [],
    this.artifact,
    this.classifiers = const {},
    this.nativesMapping = const {},
    this.extractExcludes = const [],
  });

  factory Library.fromJson(Map<String, dynamic> json) {
    final downloads = json['downloads'] as Map<String, dynamic>?;
    final classifiersJson =
        downloads?['classifiers'] as Map<String, dynamic>?;

    return Library(
      name: json['name'] as String,
      rules: ((json['rules'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Rule.fromJson)
          .toList(),
      artifact: (downloads?['artifact'] as Map<String, dynamic>?) == null
          ? null
          : LibraryArtifact.fromJson(
              downloads!['artifact'] as Map<String, dynamic>),
      classifiers: classifiersJson == null
          ? const {}
          : classifiersJson.map((k, v) =>
              MapEntry(k, LibraryArtifact.fromJson(v as Map<String, dynamic>))),
      nativesMapping: (json['natives'] as Map?)?.cast<String, String>() ??
          const {},
      extractExcludes:
          ((json['extract']?['exclude'] as List?) ?? const []).cast<String>(),
    );
  }

  /// Whether this library should be applied for the current platform, per
  /// Mojang rule evaluation semantics.
  bool isApplicable() {
    if (rules.isEmpty) return true;
    var allowed = false;
    for (final r in rules) {
      if (r.matches()) {
        allowed = r.action == 'allow';
      }
    }
    return allowed;
  }

  /// Returns the native classifier for the current OS, e.g. "natives-linux".
  /// Honors token substitution `${arch}` (Mojang uses `32` / `64`).
  String? nativeClassifierForCurrentOs() {
    final mapped = nativesMapping[PlatformArch.ruleOsName()];
    if (mapped == null) return null;
    final arch = PlatformArch.fallbackArch();
    final archStr = (arch == LauncherArch.x86 || arch == LauncherArch.arm32)
        ? '32'
        : '64';
    return mapped.replaceAll(r'${arch}', archStr);
  }
}

class LibraryArtifact {
  final String path;
  final String? sha1;
  final int? size;
  final String url;

  const LibraryArtifact({
    required this.path,
    required this.url,
    this.sha1,
    this.size,
  });

  factory LibraryArtifact.fromJson(Map<String, dynamic> json) =>
      LibraryArtifact(
        path: json['path'] as String,
        sha1: json['sha1'] as String?,
        size: (json['size'] as num?)?.toInt(),
        url: json['url'] as String,
      );
}

class Rule {
  final String action; // "allow" | "disallow"
  final String? os;
  final String? osVersion;
  final String? arch;
  final Map<String, bool> features;

  const Rule({
    required this.action,
    this.os,
    this.osVersion,
    this.arch,
    this.features = const {},
  });

  factory Rule.fromJson(Map<String, dynamic> json) {
    final osJson = json['os'] as Map<String, dynamic>?;
    return Rule(
      action: json['action'] as String,
      os: osJson?['name'] as String?,
      osVersion: osJson?['version'] as String?,
      arch: osJson?['arch'] as String?,
      features: (json['features'] as Map?)?.cast<String, bool>() ?? const {},
    );
  }

  bool matches() {
    if (features.isNotEmpty) {
      // Launcher feature flags (is_demo_user, has_custom_resolution, ...)
      // default to false — we don't currently surface them as configurable.
      return false;
    }
    final myOs = PlatformArch.ruleOsName();
    if (os != null && os != myOs) return false;
    // osVersion regex — skipped; Minecraft only uses it for old Windows quirks.
    return true;
  }
}
