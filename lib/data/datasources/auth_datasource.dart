import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/constants/auth_constants.dart';
import '../../core/constants/endpoints.dart';
import '../../core/errors/launcher_exception.dart';

class DeviceCodeChallenge {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final Duration interval;
  final Duration expiresIn;

  const DeviceCodeChallenge({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.interval,
    required this.expiresIn,
  });
}

class MsTokenSet {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  const MsTokenSet({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });
}

class McProfile {
  final String uuid;
  final String username;
  final String? skinUrl;

  const McProfile({
    required this.uuid,
    required this.username,
    this.skinUrl,
  });
}

class McTokenSet {
  final String accessToken;
  final DateTime expiresAt;

  const McTokenSet({required this.accessToken, required this.expiresAt});
}

/// Low-level HTTP calls for the Microsoft → Xbox Live → XSTS → Minecraft
/// Services chain. The high-level orchestration lives in the auth repository.
class AuthDatasource {
  AuthDatasource({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  Future<DeviceCodeChallenge> startDeviceCode() async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        Endpoints.msOAuthDeviceCode,
        data: {
          'client_id': AuthConstants.clientId,
          'scope': AuthConstants.scopes,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final d = r.data!;
      return DeviceCodeChallenge(
        deviceCode: d['device_code'] as String,
        userCode: d['user_code'] as String,
        verificationUri: d['verification_uri'] as String,
        interval: Duration(seconds: (d['interval'] as num).toInt()),
        expiresIn: Duration(seconds: (d['expires_in'] as num).toInt()),
      );
    } on DioException catch (e) {
      throw AuthException('Failed to start device code: ${e.message}', cause: e);
    }
  }

  /// Polls until the user completes the device-code flow. Throws on hard
  /// errors; returns the token set on success.
  Future<MsTokenSet> pollDeviceCode(DeviceCodeChallenge c) async {
    final deadline = DateTime.now().add(c.expiresIn);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(c.interval);
      try {
        final r = await _dio.post<Map<String, dynamic>>(
          Endpoints.msOAuthToken,
          data: {
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
            'client_id': AuthConstants.clientId,
            'device_code': c.deviceCode,
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        return _parseMsToken(r.data!);
      } on DioException catch (e) {
        final body = e.response?.data;
        final error =
            (body is Map ? body['error'] as String? : null) ?? 'unknown';
        if (error == 'authorization_pending') continue;
        if (error == 'slow_down') {
          await Future.delayed(c.interval);
          continue;
        }
        if (error == 'expired_token' || error == 'authorization_declined') {
          throw AuthException('Device code flow ended: $error');
        }
        // Any other error => bubble up.
        throw AuthException('Token poll failed: $error', cause: e);
      }
    }
    throw const AuthException('Device code expired');
  }

  Future<MsTokenSet> refresh(String refreshToken) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        Endpoints.msOAuthToken,
        data: {
          'grant_type': 'refresh_token',
          'client_id': AuthConstants.clientId,
          'refresh_token': refreshToken,
          'scope': AuthConstants.scopes,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return _parseMsToken(r.data!);
    } on DioException catch (e) {
      throw AuthException('Refresh failed: ${e.message}', cause: e);
    }
  }

  MsTokenSet _parseMsToken(Map<String, dynamic> d) {
    return MsTokenSet(
      accessToken: d['access_token'] as String,
      refreshToken: d['refresh_token'] as String,
      expiresAt: DateTime.now()
          .add(Duration(seconds: (d['expires_in'] as num).toInt())),
    );
  }

  /// Step 2: Microsoft -> Xbox Live token.
  Future<({String token, String uhs})> authenticateXbl(String msAccessToken) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        Endpoints.xblAuthenticate,
        data: {
          'Properties': {
            'AuthMethod': 'RPS',
            'SiteName': 'user.auth.xboxlive.com',
            'RpsTicket': 'd=$msAccessToken',
          },
          'RelyingParty': 'http://auth.xboxlive.com',
          'TokenType': 'JWT',
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final d = r.data!;
      final uhs = ((d['DisplayClaims']['xui'] as List).first
          as Map<String, dynamic>)['uhs'] as String;
      return (token: d['Token'] as String, uhs: uhs);
    } on DioException catch (e) {
      throw AuthException('XBL auth failed: ${e.message}', cause: e);
    }
  }

  /// Step 3: XBL token -> XSTS token.
  Future<String> authorizeXsts(String xblToken) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        Endpoints.xstsAuthorize,
        data: {
          'Properties': {
            'SandboxId': 'RETAIL',
            'UserTokens': [xblToken],
          },
          'RelyingParty': AuthConstants.xstsRelyingParty,
          'TokenType': 'JWT',
        },
      );
      return r.data!['Token'] as String;
    } on DioException catch (e) {
      // XSTS returns specific XErr codes for ownership/age issues.
      final body = e.response?.data;
      final xerr = body is Map ? body['XErr'] : null;
      throw AuthException('XSTS failed (XErr=$xerr): ${e.message}', cause: e);
    }
  }

  /// Step 4: XSTS token -> Minecraft Services token.
  Future<McTokenSet> loginWithXbox(String uhs, String xstsToken) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        Endpoints.mcLoginWithXbox,
        data: {'identityToken': 'XBL3.0 x=$uhs;$xstsToken'},
      );
      final d = r.data!;
      return McTokenSet(
        accessToken: d['access_token'] as String,
        expiresAt: DateTime.now()
            .add(Duration(seconds: (d['expires_in'] as num).toInt())),
      );
    } on DioException catch (e) {
      throw AuthException('Minecraft login failed: ${e.message}', cause: e);
    }
  }

  Future<McProfile> fetchProfile(String mcAccessToken) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        Endpoints.mcProfile,
        options: Options(headers: {'Authorization': 'Bearer $mcAccessToken'}),
      );
      final d = r.data!;
      String? skin;
      final skins = d['skins'] as List?;
      if (skins != null && skins.isNotEmpty) {
        for (final s in skins.cast<Map<String, dynamic>>()) {
          if (s['state'] == 'ACTIVE') {
            skin = s['url'] as String?;
            break;
          }
        }
      }
      return McProfile(
        uuid: d['id'] as String,
        username: d['name'] as String,
        skinUrl: skin,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const AuthException(
            'No Minecraft profile on this account — the account does not own Minecraft: Java Edition.');
      }
      throw AuthException('Profile fetch failed: ${e.message}', cause: e);
    }
  }
}
