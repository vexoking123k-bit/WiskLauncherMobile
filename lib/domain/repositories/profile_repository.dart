import '../entities/profile.dart';

abstract class ProfileRepository {
  Future<List<Profile>> list();
  Future<Profile?> get(String id);
  Future<void> save(Profile profile);
  Future<void> delete(String id);
}
