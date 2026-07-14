import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/campaign_api_client.dart';
import '../data/campaign_socket_service.dart';
import '../domain/campaign.dart';

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

  void _onAuthChanged() {
    if (!authController.isLoggedIn) {
      _campaigns = [];
      _selectedCampaign = null;
      _invites = [];
      _messages = [];
      _error = null;
      _detailError = null;
      _messagesError = null;
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
    String? roleOnJoin,
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
        roleOnJoin: roleOnJoin,
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
  }

  Future<bool> sendMessage({
    required String campaignId,
    required String kind,
    required String content,
    String? campaignActorId,
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
