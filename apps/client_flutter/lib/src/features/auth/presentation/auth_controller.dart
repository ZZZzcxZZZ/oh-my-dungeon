import 'dart:async';
import 'dart:convert';

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
  bool _initialized = false;
  bool _autoLoginEnabled = true;
  String? _error;

  AuthUser? get user => _user;
  bool get isLoading => _loading;
  bool get initialized => _initialized;
  bool get isLoggedIn => _user != null && _tokens != null;
  bool get autoLoginEnabled => _autoLoginEnabled;
  String? get error => _error;
  String? get accessToken => _tokens?.accessToken;

  /// Access token 主动预刷新阈值（秒）。若距过期小于此值，下次
  /// [ensureValidAccessToken] 会先调 `/auth/refresh` 再返回新 token。
  /// 设 60s 是为了在正常网络下留出足够窗口完成刷新 + 重试。
  static const int _tokenRefreshSkewSeconds = 60;

  /// 业务 controller 在调 API 前应调用此方法获取 access token。
  ///
  /// 服务端 access token TTL 为 15 分钟，过去客户端只在启动时刷新一次，
  /// 导致 15 分钟后所有受 JwtAuthGuard 保护的端点全部 401
  /// (`Invalid access token`)，错误信息原样塞进 UI。
  ///
  /// 本方法基于 JWT `exp` claim 主动预刷新：
  ///   - 无 token / refresh 失败：返回 null（业务层应中止请求）
  ///   - 距过期 > 60s：直接返回当前 token
  ///   - 距过期 ≤ 60s：先调 `/auth/refresh`，成功则返回新 token，失败则
  ///     清空会话并返回 null
  ///
  /// 并发调用时通过 [_refreshing] 串行化，避免多个并发请求触发重复刷新。
  Future<String?> ensureValidAccessToken() async {
    final tokens = _tokens;
    if (tokens == null) return null;

    // 解析 exp；解析失败时（非标准 JWT）保守返回当前 token，避免破坏
    // 测试桩或本地开发 token。
    final exp = _decodeAccessTokenExp(tokens.accessToken);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (exp == null || exp - now > _tokenRefreshSkewSeconds) {
      return tokens.accessToken;
    }

    // 已经在刷新中：等待结果复用
    final inflight = _refreshing;
    if (inflight != null) {
      try {
        await inflight.future;
      } catch (_) {}
      return _tokens?.accessToken;
    }

    final completer = Completer<void>();
    _refreshing = completer;
    try {
      final newAccessToken = await authClient.refresh(
        apiBaseUrl: apiBaseUrl,
        refreshToken: tokens.refreshToken,
      );
      final refreshedTokens = StoredAuthTokens(
        accessToken: newAccessToken,
        refreshToken: tokens.refreshToken,
        user: _user ?? tokens.user,
      );
      _tokens = refreshedTokens;
      if (_autoLoginEnabled) {
        await tokenStore.saveTokens(serverProfileId, refreshedTokens);
      }
      completer.complete();
      notifyListeners();
      return newAccessToken;
    } on AuthApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await tokenStore.clearTokens(serverProfileId);
        _user = null;
        _tokens = null;
        _error = null;
      } else {
        _error = '暂时无法连接服务器，本地数据仍可使用。';
      }
      completer.complete();
      notifyListeners();
      return null;
    } catch (_) {
      // 网络中断不等于退出登录。保留用户和 token，使账号工作区仍可离线
      // 使用；后续网络请求会再次尝试刷新。
      _error = '暂时无法连接服务器，本地数据仍可使用。';
      completer.complete();
      notifyListeners();
      return null;
    } finally {
      _refreshing = null;
    }
  }

  Completer<void>? _refreshing;

  /// 从 JWT access token 的 payload 中解析 `exp` claim（Unix 秒）。
  /// 解析失败返回 null。
  static int? _decodeAccessTokenExp(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // JWT base64url，需补齐 padding。
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payloadMap = jsonDecode(decoded) as Map<String, Object?>;
      final exp = payloadMap['exp'];
      if (exp is int) return exp;
      if (exp is num) return exp.toInt();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() async {
    if (_loading || _initialized) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _autoLoginEnabled = await tokenStore.getAutoLoginEnabled(serverProfileId);
      if (!_autoLoginEnabled) {
        await tokenStore.clearTokens(serverProfileId);
        return;
      }

      final tokens = await tokenStore.getTokens(serverProfileId);
      if (tokens == null) return;

      await _restoreSession(tokens);
    } catch (_) {
      _error = '无法读取本地登录状态，请重新登录。';
    } finally {
      _loading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> _restoreSession(StoredAuthTokens tokens) async {
    _user = tokens.user;
    _tokens = tokens;
    try {
      final user = await authClient.me(
        apiBaseUrl: apiBaseUrl,
        accessToken: tokens.accessToken,
      );
      _user = user;
      _tokens = StoredAuthTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        user: user,
      );
      await tokenStore.saveTokens(serverProfileId, _tokens!);
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
      final user = await authClient.me(
        apiBaseUrl: apiBaseUrl,
        accessToken: accessToken,
      );
      final refreshedTokens = StoredAuthTokens(
        accessToken: accessToken,
        refreshToken: tokens.refreshToken,
        user: user,
      );
      _tokens = refreshedTokens;
      _user = user;
      await tokenStore.saveTokens(serverProfileId, refreshedTokens);
    } on AuthApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await tokenStore.clearTokens(serverProfileId);
        _user = null;
        _tokens = null;
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
        user: session.user,
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
