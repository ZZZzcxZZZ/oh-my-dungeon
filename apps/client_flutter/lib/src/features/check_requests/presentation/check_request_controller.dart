import 'package:flutter/foundation.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/check_request_api_client.dart';
import '../domain/check_request.dart';

class CheckRequestController extends ChangeNotifier {
  CheckRequestController({
    required this.apiBaseUrl,
    required this.authController,
    required this.checkRequestClient,
  }) {
    authController.addListener(_onAuthChanged);
  }

  final String apiBaseUrl;
  final AuthController authController;
  final CheckRequestClient checkRequestClient;

  List<CheckRequest> _requests = [];
  bool _loading = false;
  String? _error;

  List<CheckRequest> get requests => _requests;
  bool get isLoading => _loading;
  String? get error => _error;
  String? get accessToken => authController.accessToken;

  void _onAuthChanged() {
    if (!authController.isLoggedIn) {
      _requests = [];
      _error = null;
      notifyListeners();
    }
  }

  Future<void> loadCheckRequests(String sessionId) async {
    final token = accessToken;
    if (token == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _requests = await checkRequestClient.listCheckRequests(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        sessionId: sessionId,
      );
    } on CheckRequestApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = '加载检定请求失败';
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> createCheckRequest({
    required String sessionId,
    required String label,
    String? checkType,
    String? ability,
    String? skill,
    int? dc,
    String? dcVisibility,
    String? targetMode,
  }) async {
    final token = accessToken;
    if (token == null) return false;

    _error = null;
    try {
      final created = await checkRequestClient.createCheckRequest(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        sessionId: sessionId,
        label: label,
        checkType: checkType,
        ability: ability,
        skill: skill,
        dc: dc,
        dcVisibility: dcVisibility,
        targetMode: targetMode,
      );
      _requests = [..._requests, created];
      notifyListeners();
      return true;
    } on CheckRequestApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> respondToCheckRequest({
    required String requestId,
    required String actorName,
    int? modifier,
    String? characterId,
  }) async {
    final token = accessToken;
    if (token == null) return false;

    _error = null;
    try {
      final response = await checkRequestClient.respondToCheckRequest(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        requestId: requestId,
        actorName: actorName,
        modifier: modifier,
        characterId: characterId,
      );
      _requests = [
        for (final request in _requests)
          if (request.id == requestId)
            request.copyWith(responses: [...request.responses, response])
          else
            request,
      ];
      notifyListeners();
      return true;
    } on CheckRequestApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> closeCheckRequest(String requestId) async {
    final token = accessToken;
    if (token == null) return false;

    _error = null;
    try {
      final closed = await checkRequestClient.closeCheckRequest(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        requestId: requestId,
      );
      _requests = [
        for (final request in _requests)
          if (request.id == requestId) closed else request,
      ];
      notifyListeners();
      return true;
    } on CheckRequestApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }
}
