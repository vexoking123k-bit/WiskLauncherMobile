import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/auth_datasource.dart';
import '../data/datasources/secure_storage_datasource.dart';
import '../data/datasources/version_manifest_datasource.dart';
import '../data/repositories/account_repository_impl.dart';
import '../data/repositories/profile_repository_impl.dart';
import '../domain/entities/account.dart';
import '../domain/entities/minecraft_version.dart';
import '../domain/entities/profile.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/services/download_manager.dart';
import '../domain/services/game_launcher.dart';
import '../domain/services/java_runtime_manager.dart';
import '../domain/services/mod_loader_installer.dart';
import '../domain/services/touch_controls.dart';

// ---- Datasources ---------------------------------------------------------
final authDatasourceProvider =
    Provider<AuthDatasource>((ref) => AuthDatasource());

final secureStorageProvider =
    Provider<SecureStorageDatasource>((ref) => SecureStorageDatasource());

final versionManifestDatasourceProvider =
    Provider<VersionManifestDatasource>((ref) => VersionManifestDatasource());

// ---- Repositories --------------------------------------------------------
final accountRepoProvider = Provider<AccountRepository>((ref) {
  return AccountRepositoryImpl(
    auth: ref.watch(authDatasourceProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

final profileRepoProvider =
    Provider<ProfileRepository>((ref) => ProfileRepositoryImpl());

// ---- Services ------------------------------------------------------------
final javaRuntimeManagerProvider =
    Provider<JavaRuntimeManager>((ref) => JavaRuntimeManager());

final downloadManagerProvider =
    Provider<DownloadManager>((ref) => DownloadManager());

final touchControlsProvider =
    Provider<TouchControlsService>((ref) => TouchControlsService());

final fabricInstallerProvider =
    Provider<FabricInstaller>((ref) => FabricInstaller());
final quiltInstallerProvider =
    Provider<QuiltInstaller>((ref) => QuiltInstaller());
final forgeInstallerProvider =
    Provider<ForgeInstaller>((ref) => ForgeInstaller());
final neoForgeInstallerProvider =
    Provider<NeoForgeInstaller>((ref) => NeoForgeInstaller());
final optifineInstallerProvider =
    Provider<OptiFineInstaller>((ref) => OptiFineInstaller());

/// All loaders, in the order shown on the Loaders page.
final allLoadersProvider = Provider<List<ModLoaderInstaller>>((ref) => [
      ref.watch(fabricInstallerProvider),
      ref.watch(quiltInstallerProvider),
      ref.watch(forgeInstallerProvider),
      ref.watch(neoForgeInstallerProvider),
      ref.watch(optifineInstallerProvider),
    ]);

final modFolderServiceProvider =
    Provider<ModFolderService>((ref) => ModFolderService());

final gameLauncherProvider = Provider<GameLauncher>((ref) => GameLauncher(
      javaRuntimes: ref.watch(javaRuntimeManagerProvider),
    ));

// ---- App state -----------------------------------------------------------
final accountsProvider = FutureProvider<List<Account>>(
    (ref) => ref.watch(accountRepoProvider).listAccounts());

final activeAccountProvider = StateProvider<Account?>((ref) => null);

final profilesProvider =
    FutureProvider<List<Profile>>((ref) => ref.watch(profileRepoProvider).list());

final activeProfileProvider = StateProvider<Profile?>((ref) => null);

final versionsProvider = FutureProvider<List<MinecraftVersion>>(
    (ref) => ref.watch(versionManifestDatasourceProvider).fetchManifest());

/// `true` while a game process is running. Drives the "Game is running…"
/// state on the Home page Play button and the hero card running indicator.
final gameRunningProvider = StateProvider<bool>((ref) => false);
