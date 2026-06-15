import '../../core/utils/app_logger.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/services/offline_account_service.dart';
import '../datasources/auth_datasource.dart';
import '../datasources/secure_storage_datasource.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl({
    required AuthDatasource auth,
    required SecureStorageDatasource storage,
    OfflineAccountService? offline,
  })  : _auth = auth,
        _storage = storage,
        _offline = offline ?? OfflineAccountService();

  final AuthDatasource _auth;
  final SecureStorageDatasource _storage;
  final OfflineAccountService _offline;

  @override
  Future<List<Account>> listAccounts() => _storage.loadAccounts();

  @override
  Future<Account> addOffline(String username) async {
    final account = _offline.create(username);
    await _persist(account);
    return account;
  }

  @override
  Future<DeviceCodeChallenge> beginMicrosoftLogin() => _auth.startDeviceCode();

  @override
  Future<Account> completeMicrosoftLogin(DeviceCodeChallenge challenge) async {
    final ms = await _auth.pollDeviceCode(challenge);
    final account = await _msToAccount(ms);
    await _persist(account);
    return account;
  }

  @override
  Future<Account> refresh(Account account) async {
    final ms = await _auth.refresh(account.refreshToken);
    final updated = await _msToAccount(ms, existing: account);
    await _persist(updated);
    return updated;
  }

  @override
  Future<void> signOut(String uuid) async {
    final all = await _storage.loadAccounts();
    all.removeWhere((a) => a.uuid == uuid);
    await _storage.saveAccounts(all);
  }

  Future<Account> _msToAccount(MsTokenSet ms, {Account? existing}) async {
    AppLogger.instance.info('auth', '1/4 XBL user.auth.xboxlive.com');
    final xbl = await _auth.authenticateXbl(ms.accessToken);
    AppLogger.instance.info('auth', '2/4 XSTS xsts.auth.xboxlive.com');
    final xsts = await _auth.authorizeXsts(xbl.token);
    AppLogger.instance.info('auth', '3/4 MC api.minecraftservices.com/authentication/login_with_xbox');
    final mc = await _auth.loginWithXbox(xbl.uhs, xsts);
    AppLogger.instance.info('auth', '4/4 profile api.minecraftservices.com/minecraft/profile');
    final profile = await _auth.fetchProfile(mc.accessToken);
    AppLogger.instance.info('auth', 'signed in as ${profile.username} (${profile.uuid.substring(0, 8)}…)');
    return Account(
      uuid: profile.uuid,
      username: profile.username,
      accessToken: mc.accessToken,
      refreshToken: ms.refreshToken,
      accessTokenExpiresAt: mc.expiresAt,
      skinUrl: profile.skinUrl ?? existing?.skinUrl,
    );
  }

  Future<void> _persist(Account account) async {
    final all = await _storage.loadAccounts();
    final idx = all.indexWhere((a) => a.uuid == account.uuid);
    if (idx >= 0) {
      all[idx] = account;
    } else {
      all.add(account);
    }
    await _storage.saveAccounts(all);
  }
}
