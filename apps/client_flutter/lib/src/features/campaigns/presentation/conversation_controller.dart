import 'package:flutter/foundation.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/campaign_api_client.dart';
import '../domain/campaign_conversation.dart';

/// Plan 2026-07-23 task 5.3: manages the conversation list for a campaign
/// and tracks the currently active conversation the chat page is showing.
///
/// The controller is campaign-scoped: [loadConversations] swaps the active
/// campaign and replaces the list. [setActiveConversation] selects which
/// conversation the chat page renders; the chat page listens and scopes its
/// message load + send calls to the active conversation's id.
///
/// Visibility is enforced server-side; this controller only holds the
/// conversations the server returned for the current user.
class ConversationController extends ChangeNotifier {
  ConversationController({
    required this.apiBaseUrl,
    required this.authController,
    required this.campaignClient,
  }) {
    authController.addListener(_onAuthChanged);
  }

  final String apiBaseUrl;
  final AuthController authController;
  final CampaignClient campaignClient;

  String? _activeCampaignId;
  List<CampaignConversation> _conversations = [];
  String? _activeConversationId;
  bool _loading = false;
  String? _error;

  String? get activeCampaignId => _activeCampaignId;
  List<CampaignConversation> get conversations => _conversations;

  /// The conversation the chat page is currently rendering. null means the
  /// main conversation (legacy behaviour) — callers should resolve the main
  /// conversation id via [mainConversation] before scoping requests.
  String? get activeConversationId => _activeConversationId;
  bool get isLoading => _loading;
  String? get error => _error;

  /// The main conversation for the active campaign, or null if not loaded.
  CampaignConversation? get mainConversation {
    for (final c in _conversations) {
      if (c.isMain) return c;
    }
    return null;
  }

  /// Convenience: direct (1:1) conversations, sorted by updatedAt desc.
  List<CampaignConversation> get directConversations =>
      _conversations.where((c) => c.kind == 'direct').toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// Convenience: group conversations, sorted by updatedAt desc.
  List<CampaignConversation> get groupConversations =>
      _conversations.where((c) => c.kind == 'group').toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// The conversation currently active for the chat page, resolved from
  /// [_activeConversationId] or falling back to [mainConversation].
  CampaignConversation? get activeConversation {
    final id = _activeConversationId;
    if (id != null) {
      for (final c in _conversations) {
        if (c.id == id) return c;
      }
    }
    return mainConversation;
  }

  void _onAuthChanged() {
    if (!authController.isLoggedIn) {
      _activeCampaignId = null;
      _conversations = [];
      _activeConversationId = null;
      _error = null;
      notifyListeners();
    }
  }

  /// Loads conversations for [campaignId]. Replaces any previously loaded
  /// campaign's conversations. If the active conversation is not present in
  /// the new list (e.g. the user left the campaign), it is reset to main.
  Future<void> loadConversations(String campaignId) async {
    await _fetchConversations(campaignId, exposeLoading: true);
  }

  /// Refreshes only the conversation directory without replacing the page
  /// with a loading state. The current conversation remains selected whenever
  /// it is still returned by the server.
  Future<void> refreshConversations(String campaignId) async {
    if (_activeCampaignId != campaignId) return;
    await _fetchConversations(campaignId, exposeLoading: false);
  }

  Future<void> _fetchConversations(
    String campaignId, {
    required bool exposeLoading,
  }) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return;

    _activeCampaignId = campaignId;
    if (exposeLoading) _loading = true;
    _error = null;
    if (exposeLoading) notifyListeners();

    try {
      _conversations = await campaignClient.listConversations(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
      );
      // Preserve active selection only if still present; otherwise fall back
      // to main (which is always present for an active campaign member).
      final activeId = _activeConversationId;
      if (activeId != null && !_conversations.any((c) => c.id == activeId)) {
        _activeConversationId = null;
      }
    } on CampaignApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load conversations';
    }

    if (exposeLoading) _loading = false;
    notifyListeners();
  }

  /// Selects the conversation the chat page should render. Pass null (or the
  /// main conversation's id) to switch back to the main room.
  void setActiveConversation(String? conversationId) {
    if (_activeConversationId == conversationId) return;
    _activeConversationId = conversationId;
    notifyListeners();
  }

  /// Creates or returns the existing 1:1 conversation with [otherUserId].
  /// The newly created/returned conversation becomes the active one.
  Future<CampaignConversation?> createDirectConversation({
    required String campaignId,
    required String otherUserId,
  }) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return null;

    _error = null;
    try {
      final conversation = await campaignClient.createDirectConversation(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        otherUserId: otherUserId,
      );
      _conversations = _upsert(_conversations, conversation);
      _activeConversationId = conversation.id;
      notifyListeners();
      return conversation;
    } on CampaignApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (_) {
      _error = 'Failed to create direct conversation';
      notifyListeners();
      return null;
    }
  }

  /// Creates a new named group conversation. DM-only on the server side.
  Future<CampaignConversation?> createGroupConversation({
    required String campaignId,
    required String title,
    required List<String> participantIds,
  }) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return null;

    _error = null;
    try {
      final conversation = await campaignClient.createGroupConversation(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        title: title,
        participantIds: participantIds,
      );
      _conversations = _upsert(_conversations, conversation);
      _activeConversationId = conversation.id;
      notifyListeners();
      return conversation;
    } on CampaignApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (_) {
      _error = 'Failed to create group conversation';
      notifyListeners();
      return null;
    }
  }

  /// Renames or archives a conversation. Returns the updated conversation or
  /// null on failure.
  Future<CampaignConversation?> updateConversation({
    required String campaignId,
    required String conversationId,
    String? title,
    bool? archived,
  }) async {
    final token = await authController.ensureValidAccessToken();
    if (token == null) return null;

    _error = null;
    try {
      final updated = await campaignClient.updateConversation(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        conversationId: conversationId,
        title: title,
        archived: archived,
      );
      _conversations = _upsert(_conversations, updated);
      // If the active conversation was archived, fall back to main.
      if (updated.isArchived && _activeConversationId == updated.id) {
        _activeConversationId = null;
      }
      notifyListeners();
      return updated;
    } on CampaignApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (_) {
      _error = 'Failed to update conversation';
      notifyListeners();
      return null;
    }
  }

  /// Clears all state — called when the user navigates away from a campaign.
  void clearSelection() {
    _activeCampaignId = null;
    _conversations = [];
    _activeConversationId = null;
    _error = null;
    notifyListeners();
  }

  List<CampaignConversation> _upsert(
    List<CampaignConversation> list,
    CampaignConversation item,
  ) {
    final next = [...list];
    final index = next.indexWhere((c) => c.id == item.id);
    if (index >= 0) {
      next[index] = item;
    } else {
      next.add(item);
    }
    return next;
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }
}
