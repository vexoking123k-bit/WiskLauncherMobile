import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../entities/account.dart';

/// Creates "offline" accounts. These are intended for single-player worlds
/// and for servers explicitly configured with `online-mode=false`. They are
/// NOT a bypass for online Microsoft auth — public Mojang servers (Hypixel,
/// Realms, etc.) will reject the connection during the encryption handshake
/// because there is no signed Yggdrasil session.
///
/// UUID generation matches vanilla Minecraft's algorithm for offline players:
/// `UUID.nameUUIDFromBytes("OfflinePlayer:<name>".getBytes(UTF_8))`, which is
/// a version-3 (MD5) UUID. Using the same algorithm means a profile created
/// here matches the same world-save player data as a vanilla offline launch.
class OfflineAccountService {
  /// Builds an offline [Account]. `accessToken` is a placeholder ("0"); the
  /// launch builder still substitutes it into `--accessToken`, and offline
  /// servers / single-player ignore the value.
  Account create(String username) {
    final clean = username.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Username cannot be empty');
    }
    if (clean.length > 16) {
      throw ArgumentError('Minecraft usernames are at most 16 characters');
    }
    final uuid = _offlineUuid(clean);
    return Account(
      uuid: uuid,
      username: clean,
      accessToken: '0',
      refreshToken: '',
      accessTokenExpiresAt: DateTime.now().add(const Duration(days: 365 * 10)),
      skinUrl: null,
    );
  }

  /// Vanilla algorithm: MD5("OfflinePlayer:<name>") with UUID v3 bits set.
  String _offlineUuid(String name) {
    final bytes = utf8.encode('OfflinePlayer:$name');
    final hash = md5.convert(bytes).bytes.toList();
    // Set version (3) and variant (RFC 4122) bits.
    hash[6] = (hash[6] & 0x0f) | 0x30;
    hash[8] = (hash[8] & 0x3f) | 0x80;
    return hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
