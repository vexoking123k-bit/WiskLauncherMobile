import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/account.dart';

/// Stores OAuth tokens & account list in the platform keystore. We persist
/// the full [Account] (which contains the refresh token) as a single JSON
/// blob keyed by uuid.
class SecureStorageDatasource {
  SecureStorageDatasource({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
            );

  static const _accountsKey = 'wisk.accounts.v1';

  final FlutterSecureStorage _storage;

  Future<List<Account>> loadAccounts() async {
    final raw = await _storage.read(key: _accountsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Account.fromJson).toList();
  }

  Future<void> saveAccounts(List<Account> accounts) async {
    final json = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await _storage.write(key: _accountsKey, value: json);
  }

  Future<void> clearAll() => _storage.delete(key: _accountsKey);
}
