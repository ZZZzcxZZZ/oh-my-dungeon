import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/campaign_api_client.dart';
import '../data/campaign_socket_service.dart';
import '../domain/campaign.dart';
import '../domain/campaign_archive_entry.dart';
import 'campaign_context_controller.dart';

class CampaignController extends ChangeNotifier {
  CampaignController({
    required this.apiBaseUrl,
    required this.authController,
    required this.campaignClient,
    CampaignSocketService? campaignSocketService,
    Future<void> Function()? onCampaignChanged,
  })  : _socketService = campaignSocketService ?? NoopCampaignSocketService(),
        _onCampaignChanged = onCampaignChanged,
        contextController = CampaignContextController(
          apiBaseUrl: apiBaseUrl,
          authController: authController,
          campaignClient: campaignClient,
        ) {
    authController.addListener(_onAuthChanged);
    // Forward context controller notifications so existing listeners on
    // CampaignController keep seeing workspace/archive state changes.
    contextController.addListener(_onContextChanged);
  }

  final String apiBaseUrl;
  final AuthController authController;
  final CampaignClient campaignClient;
  final CampaignSocketService _socketService;
  final Future<void> Function()? _onCampaignChanged;
  final CampaignContextController contextController;
  StreamSubscription<CampaignChatMessage>? _messageSubscription;
  StreamSubscription<void>? _changeSubscription;
  String? _connectedCampaignId;

  List<Campaign> _campaigns = [];
  bool _loading = false;
  String? _error;

  Campaign? _selectedCampaign;
  List<CampaignInvite> _invites = [];
  bool _detailLoading = false;
  String? _detailError;
  List<CampaignChatMessage> _messages = [];
  bool _messagesLoading = false;
  String? _messagesError;

  List<Campaign> get campaigns => _campaigns;
  bool get isLoading => _loading;
  String? get error => _error;
  String? get accessToken => authController.accessToken;

  Campaign? get selectedCampaign => _selectedCampaign;
  List<CampaignInvite> get invites => _invites;
  bool get isDetailLoading => _detailLoading;
  String? get detailError => _detailError;
  List<CampaignChatMessage> get messages => _messages;
  bool get isMessagesLoading => _messagesLoading;
  String? get messagesError => _messagesError;

  // Workspace/archive state lives in [contextController]; these getters
  // forward to keep the existing CampaignController API surface stable.
  CampaignWorkspaceContext? get workspaceContext =>
      contextController.workspaceContext;
  bool get isWorkspaceContextLoading =>
      contextController.isWorkspaceContextLoading;
  String? get workspaceContextError => contextController.workspaceContextError;
  List<CampaignArchiveEntry> get archives => contextController.archives;
  bool get isArchivesLoading => contextController.isArchivesLoading;
  String? get archivesError => contextController.archivesError;

  void _onContextChanged() {
    notifyListeners();
  }

  void _onAuthChanged() {
    if (!authController.isLoggedIn) {
      _campaigns = [];
      _selectedCampaign = null;
      _invites = [];
      _messages = [];
      _error = null;
      _detailError = null;
      _messagesError = null;
      // Context controller listens to authController itself and will reset
      // its own state; we only need to reset chat-specific state here.
      disconnectCampaignChat();
      notifyListeners();
    }
  }

  Future<void> loadCampaigns() async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _campaigns = await campaignClient.listCampaigns(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
      );
    } on CampaignApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load campaigns';
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> createCampaign({
    required String name,
    String? description,
    String? system,
  }) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return false;

    _error = null;
    try {
      final campaign = await campaignClient.createCampaign(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        name: name,
        description: description,
        system: system,
      );
      _campaigns = [..._campaigns, campaign];
      notifyListeners();
      return true;
    } on CampaignApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> joinCampaign({required String code}) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return false;

    _error = null;
    try {
      await campaignClient.joinCampaign(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        code: code,
      );
      await loadCampaigns();
      return true;
    } on CampaignApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadCampaignDetail(String campaignId) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return;

    _detailLoading = true;
    _detailError = null;
    notifyListeners();

    try {
      _selectedCampaign = await campaignClient.getCampaign(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
      );
    } on CampaignApiException catch (e) {
      _detailError = e.message;
      _detailLoading = false;
      notifyListeners();
      return;
    } catch (_) {
      _detailError = 'Failed to load campaign details';
      _detailLoading = false;
      notifyListeners();
      return;
    }

    // Invites may be inaccessible for non-managers (403) — that's expected.
    // 其他错误（401 token 问题、500 等）应冒泡到 detailError，而不是
    // 静默吞掉让 DM 以为"自己是普通玩家"。
    _invites = [];
    try {
      _invites = await campaignClient.listInvites(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
      );
    } on CampaignApiException catch (e) {
      // 403 = 非 manager，符合预期，保持 _invites 为空。
      // 其他状态码（如 401）记录到 detailError 让用户感知。
      if (e.statusCode != 403) {
        _detailError = e.message;
      }
    }

    _detailLoading = false;
    notifyListeners();
  }

  Future<CampaignInvite?> createInvite({
    required String campaignId,
    int? maxUses,
  }) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return null;

    _detailError = null;
    try {
      final invite = await campaignClient.createInvite(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        maxUses: maxUses,
      );
      _invites = [..._invites, invite];
      notifyListeners();
      return invite;
    } on CampaignApiException catch (e) {
      _detailError = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadMessages(String campaignId) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return;

    _messagesLoading = true;
    _messagesError = null;
    notifyListeners();

    try {
      _messages = await campaignClient.listMessages(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
      );
    } on CampaignApiException catch (e) {
      _messagesError = e.message;
    } catch (_) {
      _messagesError = 'Failed to load campaign messages';
    }

    _messagesLoading = false;
    notifyListeners();

    // Marking read is intentionally best-effort; reading chat must still work
    // when a self-hosted server is temporarily unreachable. 走
    // ensureValidAccessToken 与其他方法保持一致;失败/中止都由 catch 吞掉,
    // 不影响消息加载本身。Flutter web 上请求进行中切换页面会被浏览器
    // abort, 控制台会打印 net::ERR_ABORTED — 这是预期噪音。
    try {
      final readToken = await authController.ensureValidAccessToken();
      if (readToken != null) {
        await campaignClient.markCampaignRead(
          apiBaseUrl: apiBaseUrl,
          accessToken: readToken,
          campaignId: campaignId,
        );
      }
    } catch (_) {}
  }

  /// Searches the durable campaign history without replacing the live chat
  /// timeline the player is currently reading.
  Future<List<CampaignChatMessage>> searchMessages(
    String campaignId, {
    required String query,
  }) async {
    final token = await authController.ensureValidAccessToken();
    final normalizedQuery = query.trim();
    if (token == null || normalizedQuery.isEmpty) return const [];

    try {
      return await campaignClient.listMessages(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        query: normalizedQuery,
      );
    } on CampaignApiException catch (error) {
      _messagesError = error.message;
      notifyListeners();
      return const [];
    } catch (_) {
      _messagesError = 'Failed to search campaign messages';
      notifyListeners();
      return const [];
    }
  }

  // Workspace context + archives + speaker methods delegate to
  // [contextController]. Notifications from contextController are forwarded
  // via [_onContextChanged], so callers that listen to CampaignController
  // continue to observe state changes.

  Future<void> loadWorkspaceContext(String campaignId) =>
      contextController.loadWorkspaceContext(campaignId);

  Future<bool> updateSpeaker({
    required String campaignId,
    required String speakerMode,
    String? actorId,
  }) =>
      contextController.updateSpeaker(
        campaignId: campaignId,
        speakerMode: speakerMode,
        actorId: actorId,
      );

  Future<void> loadArchives(
    String campaignId, {
    String? kind,
    String? query,
    List<String>? tags,
  }) =>
      contextController.loadArchives(campaignId, kind: kind, query: query, tags: tags);

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
  }) =>
      contextController.createArchiveEntry(
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
  }) =>
      contextController.updateArchiveEntry(
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

  Future<bool> archiveEntry({
    required String campaignId,
    required String entryId,
  }) =>
      contextController.archiveEntry(
        campaignId: campaignId,
        entryId: entryId,
      );

  Future<bool> sendMessage({
    required String campaignId,
    required String kind,
    required String content,
    String? campaignActorId,
    String? actionId,
    Map<String, Object?>? eventData,
    Map<String, Object?>? speakerSnapshot,
  }) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return false;

    _messagesError = null;
    try {
      final message = await campaignClient.sendMessage(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        kind: kind,
        content: content,
        campaignActorId: campaignActorId,
        actionId: actionId,
        eventData: eventData,
        speakerSnapshot: speakerSnapshot,
      );
      _appendMessage(message);
      notifyListeners();
      return true;
    } on CampaignApiException catch (e) {
      _messagesError = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _messagesError = 'Failed to send campaign message';
      notifyListeners();
      return false;
    }
  }

  Future<void> connectCampaignChat(String campaignId) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return;

    if (_connectedCampaignId == campaignId && _socketService.isConnected) {
      return;
    }

    await _messageSubscription?.cancel();
    await _changeSubscription?.cancel();
    _messageSubscription = _socketService.messageStream.listen((message) {
      if (message.campaignId != _connectedCampaignId) return;
      _appendMessage(message);
      notifyListeners();
    });
    // Spec §双向同步 切片 A: 收到 campaign:changed 信号后触发增量拉取，
    // 由调用方注入 onCampaignChanged 回调（通常接 actorController.pullUntilCurrent）。
    final onChanged = _onCampaignChanged;
    if (onChanged != null) {
      _changeSubscription = _socketService.changeStream.listen((_) {
        onChanged();
      });
    }

    _connectedCampaignId = campaignId;
    try {
      await _socketService.connect(
        serverOrigin: _serverOriginFromApiBaseUrl(apiBaseUrl),
        accessToken: token,
        campaignId: campaignId,
      );
    } catch (_) {
      // Realtime is best-effort; HTTP message load/send still works.
    }
  }

  Future<void> disconnectCampaignChat() async {
    _connectedCampaignId = null;
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    await _changeSubscription?.cancel();
    _changeSubscription = null;
    await _socketService.disconnect();
  }

  void clearSelection() {
    _selectedCampaign = null;
    _invites = [];
    _detailError = null;
    _messages = [];
    _messagesError = null;
    // Context controller clears workspace/archive state and notifies its
    // own listeners; the forwarding listener calls notifyListeners() here.
    contextController.clearSelection();
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _socketService.disconnect();
    contextController.removeListener(_onContextChanged);
    contextController.dispose();
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _appendMessage(CampaignChatMessage message) {
    if (_messages.any((existing) => existing.id == message.id)) return;
    _messages = [..._messages, message];
  }
}

String _serverOriginFromApiBaseUrl(String apiBaseUrl) {
  final uri = Uri.parse(apiBaseUrl);
  return uri.origin;
}
