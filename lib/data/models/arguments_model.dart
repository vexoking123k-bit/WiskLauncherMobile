import '../../core/utils/platform_arch.dart';
import 'library_model.dart';

/// Unified representation of `arguments` (modern, 1.13+) and
/// `minecraftArguments` (legacy, <= 1.12) version-JSON shapes.
class Arguments {
  final List<ArgumentEntry> game;
  final List<ArgumentEntry> jvm;

  /// True when only the legacy `minecraftArguments` field was present. Used by
  /// the launch builder to know whether to add the legacy default JVM args
  /// itself.
  final bool legacy;

  const Arguments({
    required this.game,
    required this.jvm,
    required this.legacy,
  });

  factory Arguments.fromJson(Map<String, dynamic> versionJson) {
    final modern = versionJson['arguments'] as Map<String, dynamic>?;
    if (modern != null) {
      return Arguments(
        game: _parseList(modern['game'] as List?),
        jvm: _parseList(modern['jvm'] as List?),
        legacy: false,
      );
    }
    // Legacy: split string by spaces.
    final legacyArgs = (versionJson['minecraftArguments'] as String?) ?? '';
    return Arguments(
      game: legacyArgs
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .map((s) => ArgumentEntry.simple(s))
          .toList(),
      jvm: const [],
      legacy: true,
    );
  }

  static List<ArgumentEntry> _parseList(List? raw) {
    if (raw == null) return const [];
    return raw.map((e) {
      if (e is String) return ArgumentEntry.simple(e);
      final m = e as Map<String, dynamic>;
      final rules = ((m['rules'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Rule.fromJson)
          .toList();
      final value = m['value'];
      final values = value is List ? value.cast<String>() : <String>[value as String];
      return ArgumentEntry(values: values, rules: rules);
    }).toList();
  }
}

class ArgumentEntry {
  final List<String> values;
  final List<Rule> rules;

  const ArgumentEntry({required this.values, this.rules = const []});

  factory ArgumentEntry.simple(String v) =>
      ArgumentEntry(values: [v], rules: const []);

  bool isApplicable() {
    if (rules.isEmpty) return true;
    var allowed = false;
    for (final r in rules) {
      if (r.matches()) allowed = r.action == 'allow';
    }
    return allowed;
  }
}
