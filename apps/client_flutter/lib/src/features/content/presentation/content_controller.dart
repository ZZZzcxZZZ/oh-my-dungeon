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
  List<ContentItem> _items = [];
  List<ContentItem> _availableItems = [];
  List<String> _importErrors = [];
  bool _loading = false;
  String? _error;

  List<ContentPackage> get packages => _packages;
  List<ContentItem> get items => _items;
  List<ContentItem> get availableItems => _availableItems;
  List<String> get importErrors => _importErrors;
  bool get isLoading => _loading;
  String? get error => _error;
  String? get accessToken => authController.accessToken;

  void _onAuthChanged() {
    if (!authController.isLoggedIn) {
      _packages = [];
      _items = [];
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

  Future<bool> importCampaignJson({
    required String campaignId,
    required String jsonText,
    bool dryRun = false,
  }) async {
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
      final result = await contentClient.importCampaignPackage(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        package: decoded,
        dryRun: dryRun,
      );
      _importErrors = result.errors;
      if (!result.valid) return false;
      if (!dryRun && result.package != null) {
        _packages = [..._packages, result.package!];
      }
      return true;
    } on ContentApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> importSingleItem({
    required String packageName,
    required String type,
    required String name,
    required String description,
    required String sourceLabel,
    Map<String, Object?> structured = const {},
    List<String> tags = const [],
  }) async {
    final token = accessToken;
    if (token == null) return false;

    final package = _singleItemPackage(
      packageName: packageName,
      type: type,
      name: name,
      description: description,
      sourceLabel: sourceLabel,
      structured: structured,
      tags: tags,
    );

    _loading = true;
    _error = null;
    _importErrors = [];
    notifyListeners();

    try {
      final result = await contentClient.importPackage(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        package: package,
      );
      _importErrors = result.errors;
      if (!result.valid) {
        _loading = false;
        notifyListeners();
        return false;
      }
      if (result.package != null) {
        _packages = [..._packages, result.package!];
      }
      _loading = false;
      notifyListeners();
      return true;
    } on ContentApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = '导入资料失败';
    }

    _loading = false;
    notifyListeners();
    return false;
  }

  Future<bool> importCampaignSingleItem({
    required String campaignId,
    required String packageName,
    required String type,
    required String name,
    required String description,
    required String sourceLabel,
    Map<String, Object?> structured = const {},
    List<String> tags = const [],
  }) {
    return importCampaignJson(
      campaignId: campaignId,
      jsonText: jsonEncode(
        _singleItemPackage(
          packageName: packageName,
          type: type,
          name: name,
          description: description,
          sourceLabel: sourceLabel,
          structured: structured,
          tags: tags,
        ),
      ),
    );
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

  Future<void> loadItems({String? type, String? query}) async {
    final token = accessToken;
    if (token == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await contentClient.listItems(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
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

  Future<void> loadAvailableCampaignItems({
    required String campaignId,
    String? type,
    String? query,
    bool favoriteOnly = false,
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
        favoriteOnly: favoriteOnly,
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

  Future<ContentItemDetail?> loadCampaignItemDetail({
    required String campaignId,
    required String itemId,
  }) async {
    final token = accessToken;
    if (token == null) return null;
    try {
      return await contentClient.getCampaignItem(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        itemId: itemId,
      );
    } on ContentApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> setCampaignItemFavorite({
    required String campaignId,
    required String itemId,
    required bool favorite,
  }) async {
    final token = accessToken;
    if (token == null) return false;
    try {
      await contentClient.setCampaignItemFavorite(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        itemId: itemId,
        favorite: favorite,
      );
      return true;
    } on ContentApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<String?> exportPackageJson(String packageId) async {
    final token = accessToken;
    if (token == null) return null;

    _error = null;
    try {
      final exported = await contentClient.exportPackage(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        packageId: packageId,
      );
      return const JsonEncoder.withIndent('  ').convert(exported);
    } on ContentApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }
}

String _slugify(String value) {
  final slug = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'custom-item' : slug;
}

Map<String, Object?> _singleItemPackage({
  required String packageName,
  required String type,
  required String name,
  required String description,
  required String sourceLabel,
  required Map<String, Object?> structured,
  required List<String> tags,
}) {
  return {
    'name': packageName.trim().isEmpty ? '自定义资料' : packageName.trim(),
    'version': '1.0.0',
    'schemaVersion': 1,
    'locale': 'zh-CN',
    'items': [
      {
        'type': type,
        'slug': _slugify(name),
        'name': name.trim(),
        'description': description.trim(),
        'structured': structured,
        'tags': tags,
        'sourceLabel': sourceLabel.trim().isEmpty
            ? 'Homebrew'
            : sourceLabel.trim(),
      },
    ],
  };
}
