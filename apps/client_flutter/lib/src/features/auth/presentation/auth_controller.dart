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
  String? _error;

  AuthUser? get user => _user;
  bool get isLoading => _loading;
  bool get isLoggedIn => _user != null && _tokens != null;
  String? get error => _error;

  Future<void> initialize() async {
    _loading = true;
    _error = null;
    notifyListeners();

    final tokens = await tokenStore.getTokens(serverProfileId);
    if (tokens == null) {
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      _user = await authClient.me(
        apiBaseUrl: apiBaseUrl,
        accessToken: tokens.accessToken,
      );
      _tokens = tokens;
    } catch (_) {
      await tokenStore.clearTokens(serverProfileId);
    }

    _loading = false;
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
      await tokenStore.saveTokens(serverProfileId, _tokens!);
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
