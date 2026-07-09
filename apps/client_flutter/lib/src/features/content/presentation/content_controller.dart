import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/content_api_client.dart';
import '../domain/content.dart';

class ContentController extends ChangeNotifier {
  ContentController({
    required this.apiBaseUrl,
    required this.authController,
    required this.contentClient,
  }) {
    authController.addListener(_onAuthChanged);
  }

  final String apiBaseUrl;
  final AuthController authController;
  final ContentClient contentClient;

  List<ContentPackage> _packages = [];
  List<ContentItem> _availableItems = [];
  List<String> _importErrors = [];
  bool _loading = false;
  String? _error;

  List<ContentPackage> get packages => _packages;
  List<ContentItem> get availableItems => _availableItems;
  List<String> get importErrors => _importErrors;
  bool get isLoading => _loading;
  String? get error => _error;
  String? get accessToken => authController.accessToken;

  void _onAuthChanged() {
    if (!authController.isLoggedIn) {
      _packages = [];
      _availableItems = [];
      _importErrors = [];
      _error = null;
      notifyListeners();
    }
  }

  Future<void> loadPackages() async {
    final token = accessToken;
    if (token == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _packages = await contentClient.listPackages(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
      );
    } on ContentApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = '加载内容包失败';
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> validateImportJson(String jsonText) async {
    return _sendImportJson(jsonText, dryRun: true);
  }

  Future<bool> importJson(String jsonText) async {
    return _sendImportJson(jsonText, dryRun: false);
  }

  Future<bool> _sendImportJson(String jsonText, {required bool dryRun}) async {
    final token = accessToken;
    if (token == null) return false;

    Object decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (_) {
      _importErrors = ['JSON 格式无效'];
      notifyListeners();
      return false;
    }

    _loading = true;
    _error = null;
    _importErrors = [];
    notifyListeners();

    try {
      final result = await contentClient.importPackage(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        package: decoded,
        dryRun: dryRun,
      );
      _importErrors = result.errors;
      if (!result.valid) {
        _loading = false;
        notifyListeners();
        return false;
      }
      if (!dryRun && result.package != null) {
        _packages = [..._packages, result.package!];
      }
      _loading = false;
      notifyListeners();
      return true;
    } on ContentApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = '导入内容包失败';
    }

    _loading = false;
    notifyListeners();
    return false;
  }

  Future<void> loadAvailableCampaignItems({
    required String campaignId,
    String? type,
    String? query,
  }) async {
    final token = accessToken;
    if (token == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _availableItems = await contentClient.listAvailableCampaignItems(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        type: type,
        query: query,
      );
    } on ContentApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = '加载资料库失败';
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> setCampaignPackage({
    required String campaignId,
    required String packageId,
    required bool enabled,
  }) async {
    final token = accessToken;
    if (token == null) return false;

    _error = null;
    try {
      await contentClient.setCampaignPackage(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        packageId: packageId,
        enabled: enabled,
      );
      notifyListeners();
      return true;
    } on ContentApiException catch (e) {
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
