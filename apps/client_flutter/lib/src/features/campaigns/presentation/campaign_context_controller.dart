import 'package:flutter/foundation.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/campaign_api_client.dart';
import '../domain/campaign.dart';
import '../domain/campaign_archive_entry.dart';

/// Owns the per-campaign workspace context: server-provided capabilities,
/// membership speaker state, and campaign archive entries.
///
/// Extracted from [CampaignController] so the campaign center page can depend
/// on a small, focused controller that is easy to subclass for widget tests.
/// [CampaignController] composes an instance of this class and forwards the
/// workspace/archive APIs to keep existing callers working.
class CampaignContextController extends ChangeNotifier {
  CampaignContextController({
    required this.apiBaseUrl,
    required this.authController,
    required this.campaignClient,
  }) {
    authController.addListener(_onAuthChanged);
  }

  final String apiBaseUrl;
  final AuthController authController;
  final CampaignClient campaignClient;

  CampaignWorkspaceContext? _workspaceContext;
  bool _workspaceContextLoading = false;
  String? _workspaceContextError;

  List<CampaignArchiveEntry> _archives = [];
  bool _archivesLoading = false;
  String? _archivesError;

  CampaignWorkspaceContext? get workspaceContext => _workspaceContext;
  bool get isWorkspaceContextLoading => _workspaceContextLoading;
  String? get workspaceContextError => _workspaceContextError;

  List<CampaignArchiveEntry> get archives => _archives;
  bool get isArchivesLoading => _archivesLoading;
  String? get archivesError => _archivesError;

  String? get accessToken => authController.accessToken;

  Future<void> loadWorkspaceContext(String campaignId) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return;

    _workspaceContextLoading = true;
    _workspaceContextError = null;
    notifyListeners();

    try {
      _workspaceContext = await campaignClient.getWorkspaceContext(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
      );
    } on CampaignApiException catch (error) {
      _workspaceContextError = error.message;
    } catch (_) {
      _workspaceContextError = 'Failed to load campaign workspace';
    }

    _workspaceContextLoading = false;
    notifyListeners();
  }

  Future<bool> updateSpeaker({
    required String campaignId,
    required String speakerMode,
    String? characterId,
  }) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return false;
    _workspaceContextError = null;
    try {
      final membership = await campaignClient.updateSpeaker(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        speakerMode: speakerMode,
        characterId: characterId,
      );
      final context = _workspaceContext;
      if (context != null) {
        _workspaceContext = context.copyWith(membership: membership);
      }
      notifyListeners();
      return true;
    } on CampaignApiException catch (error) {
      _workspaceContextError = error.message;
    } catch (_) {
      _workspaceContextError = 'Failed to update campaign speaker';
    }
    notifyListeners();
    return false;
  }

  Future<bool> updateMemberBinding({
    required String campaignId,
    required String? characterId,
  }) async {
    final token = await authController.ensureValidAccessToken();
    final context = _workspaceContext;
    if (token == null ||
        context == null ||
        campaignClient is! CampaignBindingClient) {
      return false;
    }
    final bindingClient = campaignClient as CampaignBindingClient;

    _workspaceContextError = null;
    try {
      final membership = await bindingClient.updateMemberBinding(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        userId: context.membership.userId,
        characterId: characterId,
      );
      _workspaceContext = context.copyWith(membership: membership);
      notifyListeners();
      return true;
    } on CampaignApiException catch (error) {
      _workspaceContextError = error.message;
    } catch (_) {
      _workspaceContextError = '绑定角色失败';
    }
    notifyListeners();
    return false;
  }

  Future<void> loadArchives(
    String campaignId, {
    String? kind,
    String? query,
    List<String>? tags,
  }) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return;
    _archivesLoading = true;
    _archivesError = null;
    notifyListeners();
    try {
      _archives = await campaignClient.listArchives(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        kind: kind,
        query: query,
        tags: tags,
      );
    } on CampaignApiException catch (error) {
      _archivesError = _archiveLoadErrorMessage(error);
    } catch (_) {
      _archivesError = 'Failed to load campaign archives';
    }
    _archivesLoading = false;
    notifyListeners();
  }

  Future<CampaignArchiveEntry?> createArchiveEntry({
    required String campaignId,
    required String kind,
    required String title,
    String? summary,
    Map<String, Object?>? payload,
    List<Map<String, Object?>>? bodyBlocks,
    List<String>? tags,
    List<Map<String, Object?>>? links,
    List<Map<String, Object?>>? attachmentRefs,
  }) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return null;
    _archivesError = null;
    try {
      final entry = await campaignClient.createArchiveEntry(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        kind: kind,
        title: title,
        summary: summary,
        payload: payload,
        bodyBlocks: bodyBlocks,
        tags: tags,
        links: links,
        attachmentRefs: attachmentRefs,
      );
      _archives = [entry, ..._archives];
      notifyListeners();
      return entry;
    } on CampaignApiException catch (error) {
      _archivesError = error.message;
    } catch (_) {
      _archivesError = 'Failed to create campaign archive entry';
    }
    notifyListeners();
    return null;
  }

  Future<CampaignArchiveEntry?> updateArchiveEntry({
    required String campaignId,
    required String entryId,
    String? kind,
    String? title,
    String? summary,
    Map<String, Object?>? payload,
    bool? pinned,
    List<Map<String, Object?>>? bodyBlocks,
    List<String>? tags,
    List<Map<String, Object?>>? links,
    List<Map<String, Object?>>? attachmentRefs,
  }) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return null;
    _archivesError = null;
    try {
      final entry = await campaignClient.updateArchiveEntry(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        entryId: entryId,
        kind: kind,
        title: title,
        summary: summary,
        payload: payload,
        pinned: pinned,
        bodyBlocks: bodyBlocks,
        tags: tags,
        links: links,
        attachmentRefs: attachmentRefs,
      );
      _archives = _archives
          .map((existing) => existing.id == entry.id ? entry : existing)
          .toList();
      notifyListeners();
      return entry;
    } on CampaignApiException catch (error) {
      _archivesError = error.message;
    } catch (_) {
      _archivesError = 'Failed to update campaign archive entry';
    }
    notifyListeners();
    return null;
  }

  Future<bool> archiveEntry({
    required String campaignId,
    required String entryId,
  }) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return false;
    _archivesError = null;
    try {
      await campaignClient.archiveEntry(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        entryId: entryId,
      );
      _archives = _archives.where((entry) => entry.id != entryId).toList();
      notifyListeners();
      return true;
    } on CampaignApiException catch (error) {
      _archivesError = error.message;
    } catch (_) {
      _archivesError = 'Failed to archive campaign entry';
    }
    notifyListeners();
    return false;
  }

  /// Resets workspace context and archive state.
  ///
  /// Called by [CampaignController.clearSelection] and on auth logout. Does
  /// notify listeners so composed controllers can forward the change.
  void clearSelection() {
    _workspaceContext = null;
    _workspaceContextError = null;
    _archives = [];
    _archivesError = null;
    notifyListeners();
  }

  void _onAuthChanged() {
    if (!authController.isLoggedIn) {
      clearSelection();
    }
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }
}

String _archiveLoadErrorMessage(CampaignApiException error) {
  return switch (error.statusCode) {
    404 => '当前服务器版本不支持战役档案，请更新服务端',
    403 => '你没有查看此战役档案的权限',
    _ => error.message,
  };
}
