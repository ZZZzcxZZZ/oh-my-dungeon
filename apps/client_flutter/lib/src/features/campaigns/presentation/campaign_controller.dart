import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/campaign_api_client.dart';
import '../data/campaign_socket_service.dart';
import '../domain/campaign.dart';
import '../domain/campaign_archive_entry.dart';

class CampaignController extends ChangeNotifier {
  CampaignController({
    required this.apiBaseUrl,
    required this.authController,
    required this.campaignClient,
    CampaignSocketService? campaignSocketService,
  }) : _socketService = campaignSocketService ?? NoopCampaignSocketService() {
    authController.addListener(_onAuthChanged);
  }

  final String apiBaseUrl;
  final AuthController authController;
  final CampaignClient campaignClient;
  final CampaignSocketService _socketService;
  StreamSubscription<CampaignChatMessage>? _messageSubscription;
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
  CampaignWorkspaceContext? _workspaceContext;
  bool _workspaceContextLoading = false;
  String? _workspaceContextError;
  List<CampaignArchiveEntry> _archives = [];
  bool _archivesLoading = false;
  String? _archivesError;

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
  CampaignWorkspaceContext? get workspaceContext => _workspaceContext;
  bool get isWorkspaceContextLoading => _workspaceContextLoading;
  String? get workspaceContextError => _workspaceContextError;
  List<CampaignArchiveEntry> get archives => _archives;
  bool get isArchivesLoading => _archivesLoading;
  String? get archivesError => _archivesError;

  void _onAuthChanged() {
    if (!authController.isLoggedIn) {
      _campaigns = [];
      _selectedCampaign = null;
      _invites = [];
      _messages = [];
      _error = null;
      _detailError = null;
      _messagesError = null;
      _workspaceContext = null;
      _workspaceContextError = null;
      _archives = [];
      _archivesError = null;
      disconnectCampaignChat();
      notifyListeners();
    }
  }

  Future<void> loadCampaigns() async {
    final token = accessToken;
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
    final token = accessToken;
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
    final token = accessToken;
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
    final token = accessToken;
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
    _invites = [];
    try {
      _invites = await campaignClient.listInvites(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
      );
    } on CampaignApiException catch (_) {
      // Non-managers cannot view invites; leave _invites empty.
    }

    _detailLoading = false;
    notifyListeners();
  }

  Future<CampaignInvite?> createInvite({
    required String campaignId,
    int? maxUses,
  }) async {
    final token = accessToken;
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
    final token = accessToken;
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
    // when a self-hosted server is temporarily unreachable.
    try {
      await campaignClient.markCampaignRead(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
      );
    } catch (_) {}
  }

  /// Searches the durable campaign history without replacing the live chat
  /// timeline the player is currently reading.
  Future<List<CampaignChatMessage>> searchMessages(
    String campaignId, {
    required String query,
  }) async {
    final token = accessToken;
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

  Future<void> loadWorkspaceContext(String campaignId) async {
    final token = accessToken;
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
    String? actorId,
  }) async {
    final token = accessToken;
    if (token == null) return false;
    _workspaceContextError = null;
    try {
      final membership = await campaignClient.updateSpeaker(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        speakerMode: speakerMode,
        actorId: actorId,
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

  Future<void> loadArchives(String campaignId, {String? kind}) async {
    final token = accessToken;
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
      );
    } on CampaignApiException catch (error) {
      _archivesError = error.message;
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
  }) async {
    final token = accessToken;
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
  }) async {
    final token = accessToken;
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
    final token = accessToken;
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

  Future<bool> sendMessage({
    required String campaignId,
    required String kind,
    required String content,
    String? campaignActorId,
    String? actionId,
    Map<String, Object?>? eventData,
  }) async {
    final token = accessToken;
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
    final token = accessToken;
    if (token == null) return;

    if (_connectedCampaignId == campaignId && _socketService.isConnected) {
      return;
    }

    await _messageSubscription?.cancel();
    _messageSubscription = _socketService.messageStream.listen((message) {
      if (message.campaignId != _connectedCampaignId) return;
      _appendMessage(message);
      notifyListeners();
    });

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
    await _socketService.disconnect();
  }

  void clearSelection() {
    _selectedCampaign = null;
    _invites = [];
    _detailError = null;
    _messages = [];
    _messagesError = null;
    _workspaceContext = null;
    _workspaceContextError = null;
    _archives = [];
    _archivesError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _socketService.disconnect();
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
