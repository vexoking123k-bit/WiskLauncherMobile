/// A launcher profile: a saved bundle of (version + Java + JVM args + game
/// dir + mods folder). Roughly the same shape as `launcher_profiles.json` in
/// the official launcher, simplified.
class Profile {
  final String id;            // uuid
  final String name;          // user-facing label
  final String versionId;     // e.g. "1.21.4" or "fabric-loader-0.16.5-1.21.4"
  final String? javaRuntimeId; // null => auto-pick by version
  final List<String> jvmArgs;
  final int maxRamMb;
  final int? width;
  final int? height;
  final String? gameDirOverride;
  final DateTime created;
  final DateTime? lastPlayed;

  const Profile({
    required this.id,
    required this.name,
    required this.versionId,
    required this.created,
    this.javaRuntimeId,
    this.jvmArgs = const [],
    this.maxRamMb = 1024,
    this.width,
    this.height,
    this.gameDirOverride,
    this.lastPlayed,
  });

  Profile copyWith({
    String? name,
    String? versionId,
    String? javaRuntimeId,
    List<String>? jvmArgs,
    int? maxRamMb,
    int? width,
    int? height,
    String? gameDirOverride,
    DateTime? lastPlayed,
  }) =>
      Profile(
        id: id,
        name: name ?? this.name,
        versionId: versionId ?? this.versionId,
        javaRuntimeId: javaRuntimeId ?? this.javaRuntimeId,
        jvmArgs: jvmArgs ?? this.jvmArgs,
        maxRamMb: maxRamMb ?? this.maxRamMb,
        width: width ?? this.width,
        height: height ?? this.height,
        gameDirOverride: gameDirOverride ?? this.gameDirOverride,
        created: created,
        lastPlayed: lastPlayed ?? this.lastPlayed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'versionId': versionId,
        'javaRuntimeId': javaRuntimeId,
        'jvmArgs': jvmArgs,
        'maxRamMb': maxRamMb,
        'width': width,
        'height': height,
        'gameDirOverride': gameDirOverride,
        'created': created.toIso8601String(),
        'lastPlayed': lastPlayed?.toIso8601String(),
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String,
        versionId: json['versionId'] as String,
        javaRuntimeId: json['javaRuntimeId'] as String?,
        jvmArgs: (json['jvmArgs'] as List?)?.cast<String>() ?? const [],
        maxRamMb: (json['maxRamMb'] as num?)?.toInt() ?? 1024,
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        gameDirOverride: json['gameDirOverride'] as String?,
        created: DateTime.parse(json['created'] as String),
        lastPlayed: json['lastPlayed'] == null
            ? null
            : DateTime.parse(json['lastPlayed'] as String),
      );
}
