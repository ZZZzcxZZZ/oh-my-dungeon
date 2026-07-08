import 'package:flutter/foundation.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/session_api_client.dart';
import '../domain/session.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    required this.apiBaseUrl,
    required this.authController,
    required this.sessionClient,
  }) {
    authController.addListener(_onAuthChanged);
  }

  final String apiBaseUrl;
  final AuthController authController;
  final SessionClient sessionClient;

  String? _selectedCampaignId;
  List<Session> _sessions = [];
  bool _loading = false;
  String? _error;

  Session? _activeSession;
  List<ChatMessage> _messages = [];
  List<DiceRoll> _rolls = [];
  List<JournalEntry> _journal = [];
  bool _detailLoading = false;
  String? _detailError;
  bool _sending = false;

  String? get selectedCampaignId => _selectedCampaignId;
  List<Session> get sessions => _sessions;
  bool get isLoading => _loading;
  String? get error => _error;
  String? get accessToken => authController.accessToken;

  Session? get activeSession => _activeSession;
  List<ChatMessage> get messages => _messages;
  List<DiceRoll> get rolls => _rolls;
  List<JournalEntry> get journal => _journal;
  bool get isDetailLoading => _detailLoading;
  String? get detailError => _detailError;
  bool get isSending => _sending;

  bool get isManager {
    final user = authController.user;
    if (user == null || _activeSession == null) return false;
    final member = _activeSession!.members
        .where((m) => m.userId == user.id)
        .firstOrNull;
    if (member != null) return member.isManager;
    return _activeSession!.campaignId.isNotEmpty &&
        _activeSession!.members.any((m) => m.userId == user.id && m.isManager);
  }

  void _onAuthChanged() {
    if (!authController.isLoggedIn) {
      _sessions = [];
      _activeSession = null;
      _messages = [];
      _rolls = [];
      _journal = [];
      _selectedCampaignId = null;
      _error = null;
      _detailError = null;
      notifyListeners();
    }
  }

  void selectCampaign(String? campaignId) {
    if (_selectedCampaignId == campaignId) return;
    _selectedCampaignId = campaignId;
    _sessions = [];
    _error = null;
    notifyListeners();
    if (campaignId != null) {
      loadSessions(campaignId);
    }
  }

  Future<void> loadSessions(String campaignId) async {
    final token = accessToken;
    if (token == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _sessions = await sessionClient.listSessions(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
      );
    } on SessionApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = '加载场次列表失败';
    }

    _loading = false;
    notifyListeners();
  }

  Future<bool> createSession({required String name}) async {
    final token = accessToken;
    final campaignId = _selectedCampaignId;
    if (token == null || campaignId == null) return false;

    _error = null;
    try {
      final session = await sessionClient.createSession(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        campaignId: campaignId,
        name: name,
      );
      _sessions = [..._sessions, session];
      notifyListeners();
      return true;
    } on SessionApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> openSession(String sessionId) async {
    final token = accessToken;
    if (token == null) return;

    _detailLoading = true;
    _detailError = null;
    _activeSession = null;
    _messages = [];
    _rolls = [];
    _journal = [];
    notifyListeners();

    try {
      final session = await sessionClient.getSession(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        sessionId: sessionId,
      );
      _activeSession = session;
      _messages = session.recentMessages;
    } on SessionApiException catch (e) {
      _detailError = e.message;
    } catch (_) {
      _detailError = '加载场次详情失败';
    }

    _detailLoading = false;
    notifyListeners();
  }

  void closeSession() {
    _activeSession = null;
    _messages = [];
    _rolls = [];
    _journal = [];
    _detailError = null;
    notifyListeners();
  }

  Future<bool> startSession() async {
    final token = accessToken;
    final session = _activeSession;
    if (token == null || session == null) return false;

    _detailError = null;
    try {
      _activeSession = await sessionClient.startSession(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        sessionId: session.id,
      );
      notifyListeners();
      return true;
    } on SessionApiException catch (e) {
      _detailError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> endSession() async {
    final token = accessToken;
    final session = _activeSession;
    if (token == null || session == null) return false;

    _detailError = null;
    try {
      _activeSession = await sessionClient.endSession(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        sessionId: session.id,
      );
      notifyListeners();
      return true;
    } on SessionApiException catch (e) {
      _detailError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendMessage({required String content, String? visibility}) async {
    final token = accessToken;
    final session = _activeSession;
    if (token == null || session == null) return false;
    if (content.trim().isEmpty) return false;

    _sending = true;
    _detailError = null;
    notifyListeners();

    try {
      final message = await sessionClient.sendMessage(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        sessionId: session.id,
        content: content.trim(),
        visibility: visibility,
      );
      _messages = [..._messages, message];
      notifyListeners();
      return true;
    } on SessionApiException catch (e) {
      _detailError = e.message;
      notifyListeners();
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<bool> createRoll({
    required String notation,
    required String actorName,
    String? visibility,
  }) async {
    final token = accessToken;
    final session = _activeSession;
    if (token == null || session == null) return false;
    if (notation.trim().isEmpty) return false;

    _sending = true;
    _detailError = null;
    notifyListeners();

    try {
      final roll = await sessionClient.createRoll(
        apiBaseUrl: apiBaseUrl,
        accessToken: token,
        sessionId: session.id,
        notation: notation.trim(),
        actorName: actorName,
        visibility: visibility,
      );
      _rolls = [..._rolls, roll];
      notifyListeners();
      return true;
    } on SessionApiException catch (e) {
      _detailError = e.message;
      notifyListeners();
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// Called by the UI when a realtime `message:new` event arrives.
  void onRemoteMessage(ChatMessage message) {
    if (_messages.any((m) => m.id == message.id)) return;
    _messages = [..._messages, message];
    notifyListeners();
  }

  /// Called by the UI when a realtime `roll:new` event arrives.
  void onRemoteRoll(DiceRoll roll) {
    if (_rolls.any((r) => r.id == roll.id)) return;
    _rolls = [..._rolls, roll];
    notifyListeners();
  }

  /// Called by the UI when a realtime session update arrives.
  void onRemoteSessionUpdate(Session session) {
    if (_activeSession?.id != session.id) return;
    _activeSession = session;
    notifyListeners();
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);
    super.dispose();
  }
}
