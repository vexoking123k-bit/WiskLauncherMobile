import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../../core/utils/paths.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// JSON-file persistence keeps profile state human-debuggable and avoids
/// pulling in a SQLite dependency for ~10 records.
class ProfileRepositoryImpl implements ProfileRepository {
  File get _file =>
      File(p.join(LauncherPaths.instance.configs.path, 'profiles.json'));

  Future<List<Profile>> _readAll() async {
    final f = _file;
    if (!await f.exists()) return [];
    final raw = await f.readAsString();
    if (raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Profile.fromJson).toList();
  }

  Future<void> _writeAll(List<Profile> profiles) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
        jsonEncode(profiles.map((p) => p.toJson()).toList()));
  }

  @override
  Future<List<Profile>> list() => _readAll();

  @override
  Future<Profile?> get(String id) async {
    final all = await _readAll();
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<void> save(Profile profile) async {
    final all = await _readAll();
    final idx = all.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      all[idx] = profile;
    } else {
      all.add(profile);
    }
    await _writeAll(all);
    // Ensure the profile directory exists.
    await LauncherPaths.instance.profileDir(profile.id).create(recursive: true);
  }

  @override
  Future<void> delete(String id) async {
    final all = await _readAll();
    all.removeWhere((p) => p.id == id);
    await _writeAll(all);
    // We do NOT delete the on-disk profile dir automatically — the user may
    // have saves they want to keep.
  }
}
