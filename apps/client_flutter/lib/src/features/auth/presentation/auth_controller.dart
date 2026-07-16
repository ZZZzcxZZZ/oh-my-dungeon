import 'package:flutter/foundation.dart';

import '../data/auth_api_client.dart';
import '../data/auth_token_store.dart';
import '../domain/auth_session.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required this.tokenStore,
    required this.authClient,
    required this.serverProfileId,
    required this.apiBaseUrl,
  });

  final AuthTokenStore tokenStore;
  final AuthClient authClient;
  final String serverProfileId;
  final String apiBaseUrl;

  AuthUser? _user;
  StoredAuthTokens? _tokens;
  bool _loading = false;
  bool _autoLoginEnabled = true;
  String? _error;

  AuthUser? get user => _user;
  bool get isLoading => _loading;
  bool get isLoggedIn => _user != null && _tokens != null;
  bool get autoLoginEnabled => _autoLoginEnabled;
  String? get error => _error;
  String? get accessToken => _tokens?.accessToken;

  Future<void> initialize() async {
    _loading = true;
    _error = null;
    notifyListeners();

    _autoLoginEnabled = await tokenStore.getAutoLoginEnabled(serverProfileId);
    if (!_autoLoginEnabled) {
      await tokenStore.clearTokens(serverProfileId);
      _loading = false;
      notifyListeners();
      return;
    }

    final tokens = await tokenStore.getTokens(serverProfileId);
    if (tokens == null) {
      _loading = false;
      notifyListeners();
      return;
    }

    await _restoreSession(tokens);
    _loading = false;
    notifyListeners();
  }

  Future<void> _restoreSession(StoredAuthTokens tokens) async {
    try {
      _user = await authClient.me(
        apiBaseUrl: apiBaseUrl,
        accessToken: tokens.accessToken,
      );
      _tokens = tokens;
      return;
    } on AuthApiException catch (error) {
      if (error.statusCode != 401) {
        _error = error.message;
        return;
      }
    } catch (_) {
      _error = '暂时无法连接服务器，自动登录将在下次启动时重试。';
      return;
    }

    try {
      final accessToken = await authClient.refresh(
        apiBaseUrl: apiBaseUrl,
        refreshToken: tokens.refreshToken,
      );
      final refreshedTokens = StoredAuthTokens(
        accessToken: accessToken,
        refreshToken: tokens.refreshToken,
      );
      final user = await authClient.me(
        apiBaseUrl: apiBaseUrl,
        accessToken: accessToken,
      );
      _tokens = refreshedTokens;
      _user = user;
      await tokenStore.saveTokens(serverProfileId, refreshedTokens);
    } on AuthApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await tokenStore.clearTokens(serverProfileId);
        return;
      }
      _error = error.message;
    } catch (_) {
      _error = '暂时无法连接服务器，自动登录将在下次启动时重试。';
    }
  }

  Future<void> setAutoLoginEnabled(bool enabled) async {
    if (_autoLoginEnabled == enabled) return;
    _autoLoginEnabled = enabled;
    await tokenStore.setAutoLoginEnabled(serverProfileId, enabled);
    if (enabled && _tokens != null) {
      await tokenStore.saveTokens(serverProfileId, _tokens!);
    } else if (!enabled) {
      await tokenStore.clearTokens(serverProfileId);
    }
    notifyListeners();
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    _error = null;
    try {
      final session = await authClient.login(
        apiBaseUrl: apiBaseUrl,
        identifier: identifier,
        password: password,
      );
      _user = session.user;
      _tokens = StoredAuthTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      if (_autoLoginEnabled) {
        await tokenStore.saveTokens(serverProfileId, _tokens!);
      } else {
        await tokenStore.clearTokens(serverProfileId);
      }
      notifyListeners();
    } on AuthApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    _error = null;
    try {
      await authClient.register(
        apiBaseUrl: apiBaseUrl,
        username: username,
        email: email,
        password: password,
      );
      await login(identifier: username, password: password);
    } on AuthApiException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    if (_tokens != null) {
      try {
        await authClient.logout(
          apiBaseUrl: apiBaseUrl,
          refreshToken: _tokens!.refreshToken,
        );
      } catch (_) {}
    }
    await tokenStore.clearTokens(serverProfileId);
    _user = null;
    _tokens = null;
    _error = null;
    notifyListeners();
  }
}
