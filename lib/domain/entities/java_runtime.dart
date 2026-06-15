/// A locally-installed Java runtime.
class JavaRuntime {
  final String id;          // e.g. "java-17"
  final int majorVersion;   // 8, 17, 21, ...
  final String executablePath; // absolute path to `java` binary
  final String? vendor;     // "Adoptium", "Azul", ...
  final String? fullVersion; // "17.0.10+7"

  const JavaRuntime({
    required this.id,
    required this.majorVersion,
    required this.executablePath,
    this.vendor,
    this.fullVersion,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'majorVersion': majorVersion,
        'executablePath': executablePath,
        'vendor': vendor,
        'fullVersion': fullVersion,
      };

  factory JavaRuntime.fromJson(Map<String, dynamic> json) => JavaRuntime(
        id: json['id'] as String,
        majorVersion: (json['majorVersion'] as num).toInt(),
        executablePath: json['executablePath'] as String,
        vendor: json['vendor'] as String?,
        fullVersion: json['fullVersion'] as String?,
      );
}
