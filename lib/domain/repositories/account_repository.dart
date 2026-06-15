import '../entities/account.dart';
import '../../data/datasources/auth_datasource.dart';

abstract class AccountRepository {
  Future<List<Account>> listAccounts();
  Future<DeviceCodeChallenge> beginMicrosoftLogin();
  Future<Account> completeMicrosoftLogin(DeviceCodeChallenge challenge);
  Future<Account> refresh(Account account);
  Future<Account> addOffline(String username);
  Future<void> signOut(String uuid);
}
