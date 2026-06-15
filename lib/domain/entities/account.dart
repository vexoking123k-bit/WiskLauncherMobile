/// An authenticated Microsoft / Minecraft Services account.
///
/// `accessToken` is the Minecraft Services bearer token (not the Microsoft
/// access token). It expires after 24h and is refreshed via [refreshToken]
/// using the Microsoft OAuth refresh grant. Tokens are stored in the secure
/// platform keystore — never logged.
class Account {
  final String uuid;          // Minecraft UUID (no dashes)
  final String username;      // current MC username
  final String accessToken;   // Minecraft Services token
  final String refreshToken;  // Microsoft refresh token
  final DateTime accessTokenExpiresAt;
  final String? skinUrl;

  const Account({
    required this.uuid,
    required this.username,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    this.skinUrl,
  });

  bool get isExpired =>
      DateTime.now().isAfter(accessTokenExpiresAt.subtract(const Duration(minutes: 2)));

  Account copyWith({
    String? username,
    String? accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiresAt,
    String? skinUrl,
  }) =>
      Account(
        uuid: uuid,
        username: username ?? this.username,
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        accessTokenExpiresAt:
            accessTokenExpiresAt ?? this.accessTokenExpiresAt,
        skinUrl: skinUrl ?? this.skinUrl,
      );

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'username': username,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': accessTokenExpiresAt.toIso8601String(),
        'skinUrl': skinUrl,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        uuid: json['uuid'] as String,
        username: json['username'] as String,
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        accessTokenExpiresAt: DateTime.parse(json['expiresAt'] as String),
        skinUrl: json['skinUrl'] as String?,
      );
}
