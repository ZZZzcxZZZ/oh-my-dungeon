import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StoredAuthTokens {
  const StoredAuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  factory StoredAuthTokens.fromJson(Map<String, Object?> json) {
    return StoredAuthTokens(
      accessToken: json['accessToken']! as String,
      refreshToken: json['refreshToken']! as String,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoredAuthTokens &&
            accessToken == other.accessToken &&
            refreshToken == other.refreshToken;
  }

  @override
  int get hashCode => Object.hash(accessToken, refreshToken);
}

abstract class AuthTokenStore {
  Future<StoredAuthTokens?> getTokens(String serverProfileId);
  Future<void> saveTokens(String serverProfileId, StoredAuthTokens tokens);
  Future<void> clearTokens(String serverProfileId);
}

class InMemoryAuthTokenStore implements AuthTokenStore {
  final Map<String, StoredAuthTokens> _tokens = {};

  @override
  Future<StoredAuthTokens?> getTokens(String serverProfileId) async {
    return _tokens[serverProfileId];
  }

  @override
  Future<void> saveTokens(String serverProfileId, StoredAuthTokens tokens) async {
    _tokens[serverProfileId] = tokens;
  }

  @override
  Future<void> clearTokens(String serverProfileId) async {
    _tokens.remove(serverProfileId);
  }
}

class SharedPreferencesAuthTokenStore implements AuthTokenStore {
  SharedPreferencesAuthTokenStore(this._preferences);

  static const _tokensKey = 'auth.tokens.v1';

  final SharedPreferences _preferences;

  @override
  Future<StoredAuthTokens?> getTokens(String serverProfileId) async {
    final map = await _readTokenMap();
    final encoded = map[serverProfileId];
    if (encoded == null) {
      return null;
    }
    return StoredAuthTokens.fromJson(encoded);
  }

  @override
  Future<void> saveTokens(String serverProfileId, StoredAuthTokens tokens) async {
    final map = await _readTokenMap();
    map[serverProfileId] = tokens.toJson();
    await _writeTokenMap(map);
  }

  @override
  Future<void> clearTokens(String serverProfileId) async {
    final map = await _readTokenMap();
    if (map.remove(serverProfileId) == null) {
      return;
    }
    await _writeTokenMap(map);
  }

  Future<Map<String, Map<String, Object?>>> _readTokenMap() async {
    final raw = _preferences.getString(_tokensKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    return decoded.map(
      (key, value) => MapEntry(key, value! as Map<String, Object?>),
    );
  }

  Future<void> _writeTokenMap(Map<String, Map<String, Object?>> map) async {
    if (map.isEmpty) {
      await _preferences.remove(_tokensKey);
      return;
    }
    await _preferences.setString(_tokensKey, jsonEncode(map));
  }
}
