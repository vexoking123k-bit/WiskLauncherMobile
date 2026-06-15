/// Parsed asset index JSON (`assets/indexes/<id>.json`). Each object resolves
/// to `<resourcesBase>/<hash[0..2]>/<hash>` on the official CDN.
class AssetIndex {
  final Map<String, AssetObject> objects;
  final bool mapToResources; // legacy alpha/beta layout
  final bool virtual;        // pre-1.7 virtual asset layout

  const AssetIndex({
    required this.objects,
    this.mapToResources = false,
    this.virtual = false,
  });

  factory AssetIndex.fromJson(Map<String, dynamic> json) {
    final objs = (json['objects'] as Map?) ?? const {};
    return AssetIndex(
      objects: objs.map((k, v) => MapEntry(
            k as String,
            AssetObject.fromJson(v as Map<String, dynamic>),
          )),
      mapToResources: (json['map_to_resources'] as bool?) ?? false,
      virtual: (json['virtual'] as bool?) ?? false,
    );
  }
}

class AssetObject {
  final String hash;
  final int size;

  const AssetObject({required this.hash, required this.size});

  factory AssetObject.fromJson(Map<String, dynamic> json) => AssetObject(
        hash: json['hash'] as String,
        size: (json['size'] as num).toInt(),
      );
}
